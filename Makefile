.PHONY: entrypoint install train deploy start_port_forward stop_port_forward

ENVIRONMENT ?= dev-

entrypoint: deploy train

make refresh:
	@echo "Refreshing resources..."
	@helm uninstall training-infra
	@helm upgrade --install training-infra ./training-infra --set environment=${ENVIRONMENT}

deploy:
	@echo "Deploying resources..."
	@helm upgrade --install training-infra ./training-infra --set environment=${ENVIRONMENT}
	@echo "Waiting for jobs to complete..."
	@bash ./scripts/wait_for_jobs.sh

wait_for_ray:
	@echo "Waiting for Ray cluster head node to be ready..."
	@echo "Checking endpoint: raycluster-${ENVIRONMENT}-head-svc"
	@for i in $$(seq 1 30); do \
		POD_NAME=$$(kubectl get endpoints raycluster-${ENVIRONMENT}-head-svc -o jsonpath='{.subsets[0].addresses[0].targetRef.name}' 2>/dev/null || echo ""); \
		if [ -n "$$POD_NAME" ]; then \
			echo "Found pod: $$POD_NAME"; \
			kubectl wait --for=condition=ready pod/$$POD_NAME --timeout=120s && break; \
		else \
			echo "Endpoint not ready, waiting... ($$i/30)"; \
			sleep 10; \
		fi; \
	done

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
