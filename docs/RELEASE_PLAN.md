# Release Plan

This document describes practical release increments leading to the stable `v1.0.0` Linux VM template. For the authoritative scope boundary, see [RELEASE_SCOPE.md](RELEASE_SCOPE.md). Dates are intentionally omitted until implementation capacity and validation environments are available.

## v0.1.0 - Single-Service VM MVP

**Objective:** Prove the first working single-service blue/green deployment flow behind NGINX on a Linux VM.

**Planned features:**

- Jenkins pipeline skeleton and documented stages.
- Docker image build or pull workflow.
- Immutable tagging conventions.
- Blue/green deployment scripts for one service.
- NGINX traffic switch mechanism.
- Health-check validation gate.
- Basic rollback flow.
- Environment configuration examples.

**Release criteria:**

- Staging deployment can switch from blue to green without intentional downtime.
- Failed health checks prevent promotion.
- Rollback behavior is documented and tested in a controlled environment.
- README, MVP documentation, and implementation agree.

## v0.2.0 - Release State and Safety

**Objective:** Make deployment outcomes inspectable and rollback behavior predictable.

**Planned features:**

- Release state file or directory layout.
- Previous healthy version tracking.
- Safer failure handling for missing configuration.
- Post-switch verification.
- Failure-mode documentation.

**Release criteria:**

- Operators can identify active color, previous color, version, and last result.
- Failed candidate and failed post-switch scenarios are documented.
- Rollback behavior is testable from recorded state.

## v0.3.0 - Governance and Operator Docs

**Objective:** Add release controls that improve ownership, reviewability, and operational discipline.

**Planned features:**

- Release approval guidance.
- Required deployment metadata.
- PR and tag expectations for releases.
- Release checklist.
- Ownership documentation.
- Initial troubleshooting runbook.

**Release criteria:**

- Release process identifies operator, approver, version, environment, and rollback plan.
- Operator documentation is clear enough for someone who did not author the scripts.
- No production-readiness claim is made beyond validated scope.

## v0.4.0 - Multi-Service Model

**Objective:** Extend the template model to support related services while preserving safety gates.

**Planned features:**

- Multi-service configuration structure.
- Service dependency ordering guidance.
- Coordinated health checks.
- Per-service release state model.
- Documentation for partial failure and rollback constraints.

**Release criteria:**

- At least two services can be represented without duplicating the entire template.
- Dependency risks and rollback constraints are documented.
- Single-service use remains understandable.

## v0.5.0 - Hardening and Validation

**Objective:** Prepare the VM template for stable release review.

**Planned features:**

- Hardened scripts and pipeline definitions.
- Fresh setup validation from documentation.
- Security and secret-handling review.
- Deployment logging guidance.
- Representative staging tests.

**Release criteria:**

- Setup, deploy, rollback, and troubleshoot docs are accurate.
- Known limitations are documented.
- Maintainers can identify remaining blockers for `v1.0.0`.

## v1.0.0 - Stable Linux VM Template

**Objective:** Publish a stable VM-based zero-downtime CI/CD template with clear support boundaries.

**Required capabilities:**

- Generic Linux VM deployment.
- Jenkins pipeline integration.
- Multi-service blue/green support.
- NGINX traffic switching.
- Health-check gates and post-switch verification.
- Rollback to the last known healthy release.
- Release directory structure and state tracking.
- Complete operational documentation.

**Release criteria:**

- Deployment and rollback paths are tested in representative environments.
- Documentation accurately reflects behavior and limitations.
- Known risks are visible in README and release scope docs.
- Maintainers agree the template is stable for the stated VM scope.

## Future v2.0.0 Direction

`v2.0.0` is reserved for a Kubernetes-native version using Kubernetes, Helm, rolling and blue/green strategy, and cloud-native deployment workflow. Kubernetes implementation files do not belong in the v1 release plan.
