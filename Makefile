.PHONY: entrypoint install install_dependencies deploy train wait_for_ray start_port_forward stop_port_forward refresh

ENVIRONMENT ?= dev-

entrypoint: deploy train

install_dependencies:
	@echo "Installing External Secrets Operator..."
	@helm repo add external-secrets https://charts.external-secrets.io || true
	@helm repo update
	@helm install external-secrets external-secrets/external-secrets \
	  --namespace external-secrets \
	  --create-namespace \
	  --wait || true
	@echo "Waiting for CRDs to be established..."
	@kubectl wait --for=condition=established --timeout=60s crd/externalsecrets.external-secrets.io || true
	@kubectl wait --for=condition=established --timeout=60s crd/secretstores.external-secrets.io || true

refresh:
	@echo "Refreshing resources..."
	@helm uninstall training-infra
	@helm upgrade --install training-infra ./training-infra --set environment=${ENVIRONMENT}

deploy: install_dependencies
	@echo "Deploying resources..."
	@helm upgrade --install training-infra ./training-infra --set environment=${ENVIRONMENT}
	@echo "Waiting for jobs to complete..."
	@kubectl get jobs -o name | xargs -I {} bash -c 'kubectl wait --for=condition=complete {} --timeout=300s || kubectl wait --for=condition=failed {} --timeout=300s'

wait_for_ray:
	@echo "Waiting for Ray cluster head node to be ready..."
	@POD_NAME=$$(kubectl get endpoints raycluster-${ENVIRONMENT}-head-svc -o jsonpath='{.subsets[0].addresses[0].targetRef.name}') && kubectl wait --for=condition=ready pod/$$POD_NAME --timeout=60s

start_port_forward: wait_for_ray
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
