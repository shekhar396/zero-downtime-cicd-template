.PHONY: validate-config init-service show-state health create-release list-releases

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

health:
	@if [ -z "$(URL)" ]; then \
		echo "Usage: make health URL=<health_url>"; \
		exit 1; \
	fi
	./scripts/healthcheck.sh "$(URL)"

create-release:
	@if [ -z "$(SERVICE)" ] || [ -z "$(ARTIFACT)" ]; then \
		echo "Usage: make create-release SERVICE=<service_name> ARTIFACT=<artifact_source>"; \
		exit 1; \
	fi
	./scripts/create-release.sh "$(SERVICE)" "$(ARTIFACT)"

list-releases:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Usage: make list-releases SERVICE=<service_name>"; \
		exit 1; \
	fi
	./scripts/list-releases.sh "$(SERVICE)"
