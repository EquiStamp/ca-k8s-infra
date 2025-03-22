.PHONY: entrypoint install train deploy start_port_forward stop_port_forward create_aws_secret

ENVIRONMENT ?= dev-

entrypoint: deploy train

create_aws_secret:
	@echo "Saving AWS credentials..."
	# This is needed for the secrets to be avaiable for minio
	@kubectl create secret generic aws-creds --from-literal=AWS_ACCESS_KEY_ID=$${AWS_ACCESS_KEY_ID} --from-literal=AWS_SECRET_ACCESS_KEY=$${AWS_SECRET_ACCESS_KEY}

make refresh:
	@echo "Refreshing resources..."
	@helm uninstall training-infra 
	@helm upgrade --install training-infra ./training-infra --set environment=${ENVIRONMENT}

deploy: create_aws_secret
	@echo "Deploying resources..."
	@helm upgrade --install training-infra  ./training-infra --set environment=${ENVIRONMENT}
	@echo "Waiting for jobs to complete..."
	@kubectl get jobs -o name | xargs -I {} bash -c 'kubectl wait --for=condition=complete {} --timeout=300s || kubectl wait --for=condition=failed {} --timeout=300s'

start_port_forward:
	@echo "Starting port forwarding..."
	@kubectl port-forward service/raycluster-${ENVIRONMENT}-head-svc 8265:8265 10001:10001 & echo $$! >> .port_forward.pid

stop_port_forward:
	@echo "Stopping port forwarding..."
	@if [ -f .port_forward.pid ]; then \
		kill `cat .port_forward.pid`; rm .port_forward.pid; \
	else \
		echo "No port forwarding process found"; \
	fi

train: start_port_forward
	@trap 'make stop_port_forward' EXIT 2 15; \
	echo "Training model..." && \
	RAY_AIR_NEW_OUTPUT=0 uv run --active python training/train.py
