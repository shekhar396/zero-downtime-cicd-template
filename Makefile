.PHONY: validate-config init-service show-state

validate-config:
	./scripts/validate-config.sh

init-service:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Usage: make init-service SERVICE=<service_name>"; \
		exit 1; \
	fi
	./scripts/init-service.sh "$(SERVICE)"

show-state:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Usage: make show-state SERVICE=<service_name>"; \
		exit 1; \
	fi
	./scripts/show-state.sh "$(SERVICE)"
