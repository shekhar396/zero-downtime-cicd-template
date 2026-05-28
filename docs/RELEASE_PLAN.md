# Release Plan

This roadmap describes intended releases. Dates are intentionally omitted until implementation capacity and validation environments are available.

## v0.1.0 - Single-Server Zero-Downtime MVP

**Objective:** Provide the first working template for single-server blue/green deployment behind NGINX.

**Planned features:**

- Jenkins pipeline skeleton and documented stages.
- Docker image build and immutable tagging conventions.
- Blue/green deployment scripts.
- NGINX traffic switch mechanism.
- Health-check validation gate.
- Basic rollback flow.
- Environment configuration examples.

**Release criteria:**

- Staging deployment can switch from blue to green without intentional downtime.
- Failed health checks prevent promotion.
- Rollback behavior is documented and tested in a controlled environment.
- README and MVP documentation match the implemented behavior.

## v0.2.0 - Deployment Governance

**Objective:** Add release controls that improve ownership, reviewability, and audit discipline.

**Planned features:**

- Release approval guidance.
- Required deployment metadata.
- PR and tag expectations for releases.
- Release checklist.
- Ownership documentation.

**Release criteria:**

- Release process identifies operator, approver, version, environment, and rollback plan.
- Governance docs are clear enough for maintainers to enforce consistently.
- No production-readiness claim is made beyond validated scope.

## v0.3.0 - Observability and Deployment Metrics

**Objective:** Improve visibility into deployment outcomes and operational health.

**Planned features:**

- Deployment event logging guidance.
- Metrics for deployment duration, success, rollback, and failure reason.
- Health-check and post-switch verification reporting.
- Observability integration examples.

**Release criteria:**

- Template documents minimum useful deployment metrics.
- Example metrics can be collected in a controlled environment.
- Failure states are visible enough to support incident review.

## v0.4.0 - Canary and Smoke Testing

**Objective:** Add safer validation patterns before or immediately after traffic promotion.

**Planned features:**

- Smoke-test stage design.
- Optional canary-style validation notes.
- Post-switch verification checks.
- Failure handling guidance for partial validation.

**Release criteria:**

- Smoke checks are documented and testable.
- Canary limitations are clearly stated for single-server environments.
- Failed smoke tests produce a defined rollback or hold decision.

## v0.5.0 - Multi-Service Deployment Support

**Objective:** Extend the template model to support related services while preserving safety gates.

**Planned features:**

- Multi-service configuration structure.
- Service dependency ordering guidance.
- Coordinated health checks.
- Release-state model for multiple services.

**Release criteria:**

- At least two services can be represented without duplicating the entire template.
- Dependency risks and rollback constraints are documented.
- Single-service use remains understandable.

## v1.0.0 - Stable Production-Ready Template

**Objective:** Publish a stable template with tested deployment behavior and clear support boundaries.

**Planned features:**

- Hardened scripts and pipeline definitions.
- Complete operator documentation.
- Tested rollback and failure scenarios.
- Versioned examples.
- Security and secret-handling review.

**Release criteria:**

- Deployment and rollback paths are tested in representative environments.
- Documentation accurately reflects behavior and limitations.
- Known risks are documented.
- Maintainers agree the template is stable for its stated scope.

