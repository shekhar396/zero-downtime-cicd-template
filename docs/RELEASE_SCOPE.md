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
- Docker image build or pull workflow
- immutable image tagging guidance
- multi-service blue/green deployment support
- NGINX traffic switching from generated config
- HTTP health-check gates before promotion
- post-switch verification
- rollback to the last known healthy release
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
- `config/nginx/*.tpl` for NGINX template generation
- `scripts/` for deployment, health check, traffic switch, rollback, state, and validation commands
- `docs/` for architecture, release scope, operations, configuration, health checks, contribution, and roadmap documentation
- `examples/` for single-service and multi-service configurations
- `tests/` for shell/config/state/NGINX generation validation

## Required v1.0.0 Scripts

The v1 script inventory is:

- `scripts/init-host.sh`
- `scripts/validate-config.sh`
- `scripts/deploy.sh`
- `scripts/health-check.sh`
- `scripts/generate-nginx.sh`
- `scripts/switch-traffic.sh`
- `scripts/create-release.sh`
- `scripts/list-releases.sh`
- `scripts/rollback.sh`
- `scripts/smoke-test.sh`
- `scripts/common/config.sh`
- `scripts/common/colors.sh`
- `scripts/common/docker.sh`
- `scripts/common/logging.sh`
- `scripts/common/nginx.sh`
- `scripts/common/state.sh`

These scripts are required for the v1 design but should be implemented only after the repository structure and architecture are accepted.

## v1.0.0 Must Not Include

- Kubernetes manifests
- Helm charts
- Kubernetes operators or controllers
- service mesh configuration
- cloud-provider-specific infrastructure provisioning
- autoscaling infrastructure
- multi-region deployment automation
- database migration orchestration
- secret-management platform implementation
- full monitoring or tracing stack installation
- application-specific deployment logic embedded in the core scripts
- release artifact management that starts processes, switches traffic, or performs rollback

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
