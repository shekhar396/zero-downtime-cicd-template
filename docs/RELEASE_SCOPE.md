# Release Scope

This document is the authoritative scope boundary for the public roadmap.

## v1.0.0 Target

`v1.0.0` is the stable VM-based zero-downtime CI/CD template.

It should help teams deploy containerized services to generic Linux VMs using Jenkins, Docker-compatible images, NGINX, health checks, release state, release history, and rollback.

## v1.0.0 Must Include

- generic Linux VM deployment support
- application-agnostic service registration
- YAML configuration for services and environments
- Jenkins pipeline integration through a repository `Jenkinsfile`
- Jenkins declarative pipeline examples
- Docker image build or pull workflow
- container runtime process management for blue/green service instances
- immutable image tagging guidance
- multi-service blue/green deployment support
- NGINX config generation and validation before traffic switching
- main one-service deployment orchestrator
- controlled single-service NGINX traffic switching from generated config
- dry-run traffic switch validation
- HTTP health-check gates before promotion
- post-switch verification
- rollback to a retained successful release for one service
- manual retained release rollback
- release artifact directory management with metadata
- release directory structure on target VMs
- `current` symlink management for release artifacts
- file-based state management with history records
- safe release retention cleanup
- development, staging, and production configuration guidance
- operator documentation for deploy, rollback, troubleshoot, and recover workflows
- clear limitations and safety notes

## Required v1.0.0 Repository Surface

The stable VM template should include these top-level areas:

- `Jenkinsfile` for CI/CD orchestration
- `config/services.yml` for service registration
- `config/environments/*.yml` for environment-specific VM settings
- `nginx/templates/*.tpl` for NGINX template generation
- `scripts/` for deployment, health check, traffic switch, rollback, state, and validation commands
- `docs/` for architecture, release scope, operations, configuration, health checks, contribution, and roadmap documentation
- `examples/` for mock artifacts, local validation helpers, and Jenkins examples

## Required v1.0.0 Scripts

The v1 script inventory is:

- `scripts/validate-config.sh`
- `scripts/init-service.sh`
- `scripts/show-state.sh`
- `scripts/healthcheck.sh`
- `scripts/validate-release.sh`
- `scripts/create-release.sh`
- `scripts/list-releases.sh`
- `scripts/start-color.sh`
- `scripts/stop-color.sh`
- `scripts/status-color.sh`
- `scripts/generate-nginx.sh`
- `scripts/validate-nginx.sh`
- `scripts/switch-traffic.sh`
- `scripts/rollback.sh`
- `scripts/deploy.sh`
- `scripts/lib/service-discovery.sh`
- `scripts/lib/state.sh`
- `scripts/lib/health.sh`
- `scripts/lib/release.sh`
- `scripts/lib/runtime.sh`
- `scripts/lib/nginx.sh`

These scripts provide the current v1 foundation and should continue to preserve safe defaults, dry-run behavior, and clear operator output.

## v1.0.0 Must Not Include

- Kubernetes manifests
- Helm charts
- Kubernetes operators or controllers
- service mesh configuration
- cloud-provider-specific infrastructure provisioning
- production secrets embedded in Jenkinsfiles
- autoscaling infrastructure
- multi-region deployment automation
- database migration orchestration
- secret-management platform implementation
- full monitoring or tracing stack installation
- application-specific deployment logic embedded in the core scripts
- runtime support beyond `runtime: container` in the v1 foundation
- generated NGINX config writes to `/etc/nginx` by default

## Stability Criteria

Before `v1.0.0`, maintainers should be able to verify:

- a new operator can understand the architecture from documentation
- a sample service can be deployed to a Linux VM through the documented flow
- three services can be registered and deployed through the same model
- failed candidate health checks keep traffic on the active version
- successful candidate validation switches NGINX traffic
- generated NGINX config is validated before reload
- rollback restores the previous healthy release
- release history identifies who deployed what, when, and with which result
- release state can be inspected during an incident
- docs match actual behavior

## Non-Claims

The project should not claim:

- universal zero downtime for every application
- production readiness before `v1.0.0`
- automatic safety for incompatible database changes
- compatibility with every Linux distribution
- cloud-provider neutrality beyond the documented VM assumptions
- Kubernetes support in v1

## v2.0.0 Target

`v2.0.0` is the future Kubernetes-native version.

The target direction includes:

- Kubernetes workload deployment
- Helm-based packaging
- rolling and blue/green deployment strategy
- Kubernetes readiness and liveness semantics
- cloud-native deployment workflow

Kubernetes belongs in roadmap and future-scope documentation until `v1.0.0` is stable.
