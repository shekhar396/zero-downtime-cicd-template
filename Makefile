.PHONY: help test validate-config lint-shell init-service show-state health create-release list-releases start-color stop-color status-color generate-nginx validate-nginx generate-apache validate-apache switch-traffic switch-traffic-dry-run rollback rollback-dry-run deploy deploy-dry-run

help:
	@echo "zero-downtime-cicd-template v1.0.0 commands"
	@echo ""
	@echo "Validation:"
	@echo "  make validate-config"
	@echo "  make lint-shell"
	@echo "  make test"
	@echo ""
	@echo "State:"
	@echo "  make init-service SERVICE=billing-api"
	@echo "  make show-state SERVICE=billing-api"
	@echo ""
	@echo "Release artifacts:"
	@echo "  make create-release SERVICE=billing-api ARTIFACT=examples/mock-artifact"
	@echo "  make list-releases SERVICE=billing-api"
	@echo ""
	@echo "Runtime colors:"
	@echo "  make start-color SERVICE=billing-api COLOR=green RELEASE=<release_id>"
	@echo "  make status-color SERVICE=billing-api COLOR=green"
	@echo "  make stop-color SERVICE=billing-api COLOR=green"
	@echo ""
	@echo "Health and NGINX:"
	@echo "  make health URL=http://localhost:18081/health"
	@echo "  make generate-nginx"
	@echo "  make validate-nginx"
	@echo "  make generate-apache"
	@echo "  make validate-apache"
	@echo "  make switch-traffic-dry-run SERVICE=billing-api COLOR=green"
	@echo ""
	@echo "Deploy and rollback:"
	@echo "  make deploy-dry-run SERVICE=billing-api ARTIFACT=examples/mock-artifact"
	@echo "  make deploy SERVICE=billing-api ARTIFACT=examples/mock-artifact"
	@echo "  make rollback-dry-run SERVICE=billing-api"
	@echo "  make rollback SERVICE=billing-api"
	@echo ""
	@echo "Docs:"
	@echo "  docs/QUICK_START.md"
	@echo "  docs/DEMO_WALKTHROUGH.md"
	@echo "  docs/RELEASE_CHECKLIST.md"
	@echo "  docs/TROUBLESHOOTING.md"

validate-config:
	./scripts/validate-config.sh

test:
	./tests/init-service-test.sh

lint-shell:
	find scripts examples tests -type f -name "*.sh" -print0 | xargs -0 bash -n

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


start-color:
	@if [ -z "$(SERVICE)" ] || [ -z "$(COLOR)" ] || [ -z "$(RELEASE)" ]; then \
		echo "Usage: make start-color SERVICE=<service_name> COLOR=<blue|green> RELEASE=<release_id>"; \
		exit 1; \
	fi
	./scripts/start-color.sh "$(SERVICE)" "$(COLOR)" "$(RELEASE)"

stop-color:
	@if [ -z "$(SERVICE)" ] || [ -z "$(COLOR)" ]; then \
		echo "Usage: make stop-color SERVICE=<service_name> COLOR=<blue|green>"; \
		exit 1; \
	fi
	./scripts/stop-color.sh "$(SERVICE)" "$(COLOR)"

status-color:
	@if [ -z "$(SERVICE)" ] || [ -z "$(COLOR)" ]; then \
		echo "Usage: make status-color SERVICE=<service_name> COLOR=<blue|green>"; \
		exit 1; \
	fi
	./scripts/status-color.sh "$(SERVICE)" "$(COLOR)"


generate-nginx:
	./scripts/generate-nginx.sh

validate-nginx:
	./scripts/validate-nginx.sh ./build/nginx

generate-apache:
	./scripts/generate-apache.sh

validate-apache:
	./scripts/validate-apache.sh ./build/apache


switch-traffic:
	@if [ -z "$(SERVICE)" ] || [ -z "$(COLOR)" ]; then \
		echo "Usage: make switch-traffic SERVICE=<service_name> COLOR=<blue|green>"; \
		exit 1; \
	fi
	./scripts/switch-traffic.sh "$(SERVICE)" "$(COLOR)"

switch-traffic-dry-run:
	@if [ -z "$(SERVICE)" ] || [ -z "$(COLOR)" ]; then \
		echo "Usage: make switch-traffic-dry-run SERVICE=<service_name> COLOR=<blue|green>"; \
		exit 1; \
	fi
	./scripts/switch-traffic.sh "$(SERVICE)" "$(COLOR)" --dry-run


rollback:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Usage: make rollback SERVICE=<service_name> [RELEASE=<release_id>]"; \
		exit 1; \
	fi
	@if [ -n "$(RELEASE)" ]; then \
		./scripts/rollback.sh "$(SERVICE)" --release "$(RELEASE)"; \
	else \
		./scripts/rollback.sh "$(SERVICE)"; \
	fi

rollback-dry-run:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Usage: make rollback-dry-run SERVICE=<service_name> [RELEASE=<release_id>]"; \
		exit 1; \
	fi
	@if [ -n "$(RELEASE)" ]; then \
		./scripts/rollback.sh "$(SERVICE)" --release "$(RELEASE)" --dry-run; \
	else \
		./scripts/rollback.sh "$(SERVICE)" --dry-run; \
	fi


deploy:
	@if [ -z "$(SERVICE)" ] || [ -z "$(ARTIFACT)" ]; then \
		echo "Usage: make deploy SERVICE=<service_name> ARTIFACT=<artifact_source>"; \
		exit 1; \
	fi
	./scripts/deploy.sh "$(SERVICE)" "$(ARTIFACT)"

deploy-dry-run:
	@if [ -z "$(SERVICE)" ] || [ -z "$(ARTIFACT)" ]; then \
		echo "Usage: make deploy-dry-run SERVICE=<service_name> ARTIFACT=<artifact_source>"; \
		exit 1; \
	fi
	./scripts/deploy.sh "$(SERVICE)" "$(ARTIFACT)" --dry-run
