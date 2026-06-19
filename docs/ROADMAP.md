# Roadmap

This roadmap is organized by release maturity rather than calendar date. The project direction is explicit: `v1.0.0` is a stable Linux VM template; `v2.0.0` is the future Kubernetes-native generation.

## Current Phase: Documentation and Scope

The repository is currently defining the public release boundary, architecture, and operating model before scripts are implemented.

Current priorities:

- keep the README accurate and open-source ready
- define what belongs in `v1.0.0`
- document VM-based architecture and operations
- avoid presenting future Kubernetes work as current functionality
- keep older planning docs subordinate to the release scope

## v0.x: Implementation Milestones Toward v1

`v0.x` releases should be used for incremental implementation and validation. They should not claim full production readiness.

Expected milestones:

- Jenkins pipeline skeleton
- Docker image build or pull workflow
- immutable image tagging convention
- single-service blue/green deployment flow
- NGINX traffic switch template
- health-check gate
- rollback path
- release state directory
- multi-service configuration model
- coordinated multi-service health checks
- operator documentation and troubleshooting guidance

## v1.0.0: Stable Linux VM Template

`v1.0.0` is the first stable release target. It should provide a practical VM-based zero-downtime CI/CD template that can be reviewed, adapted, and operated by DevOps teams.

Required capabilities:

- generic Linux VM deployment
- Jenkins pipeline integration
- Docker-based release packaging assumptions
- multi-service blue/green deployment support
- NGINX traffic switching
- health-check validation before promotion
- rollback to the last known healthy release
- release directory structure and state tracking
- clear environment configuration guidance
- complete operational documentation

Stable release criteria:

- a fresh setup can be completed from documentation
- deployment and rollback paths are tested in representative environments
- failed health checks prevent promotion
- NGINX switch behavior is documented and validated
- multi-service ordering and rollback constraints are explained
- known limitations are visible in README and release scope docs

## v1.x: VM Template Hardening

After `v1.0.0`, `v1.x` releases may improve the VM template without changing its core operating model.

Potential improvements:

- richer service examples
- smoke-test stages
- stronger validation and dry-run behavior
- deployment event logging guidance
- compatibility notes for common Linux distributions
- reusable troubleshooting playbooks
- security and secret-handling hardening

## v2.0.0: Kubernetes-Native Roadmap Target

`v2.0.0` is a future roadmap target, not current implementation scope.

The intended direction is a Kubernetes-native version using:

- Kubernetes workload primitives
- Helm packaging
- rolling and blue/green deployment strategies
- cloud-native deployment workflow
- Kubernetes-native health and readiness semantics

The `v2.0.0` work should be introduced only after the VM-based `v1.0.0` template is stable and documented. Kubernetes files, Helm charts, and cluster automation should not be added as part of the `v1.0.0` implementation.
