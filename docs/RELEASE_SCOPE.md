# Release Scope

This document is the authoritative scope boundary for the public roadmap.

## v1.0.0 Target

`v1.0.0` is the stable VM-based zero-downtime CI/CD template.

It should help teams deploy containerized services to generic Linux VMs using Jenkins, Docker, NGINX, health checks, release state, and rollback.

## v1.0.0 Must Include

- generic Linux VM deployment support
- Jenkins pipeline integration
- Docker image build or pull workflow
- immutable image tagging guidance
- multi-service blue/green deployment support
- NGINX traffic switching
- HTTP health-check gates before promotion
- post-switch verification
- rollback to the last known healthy release
- release directory structure
- release state tracking
- development, staging, and production configuration guidance
- operator documentation for deploy, rollback, troubleshoot, and recover workflows
- clear limitations and safety notes

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

## Stability Criteria

Before `v1.0.0`, maintainers should be able to verify:

- a new operator can understand the architecture from documentation
- a sample service can be deployed to a Linux VM through the documented flow
- failed candidate health checks keep traffic on the active version
- successful candidate validation switches NGINX traffic
- rollback restores the previous healthy release
- multi-service configuration is understandable and tested in a representative scenario
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
