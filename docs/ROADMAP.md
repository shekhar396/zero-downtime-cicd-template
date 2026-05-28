# Roadmap

The roadmap is organized by capability maturity rather than calendar date.

## Phase 1: Foundation

- Define repository purpose and honest current status.
- Document MVP boundaries and non-goals.
- Establish contribution and AI-agent usage policies.
- Create release and pre-release plans.
- Add basic repository hygiene files.

## Phase 2: MVP Implementation

- Add Jenkins pipeline skeleton.
- Add Docker build and tagging conventions.
- Add blue/green deployment scripts.
- Add NGINX switch template.
- Add health-check validation.
- Add environment configuration examples.

## Phase 3: Rollback and Safety

- Implement rollback command flow.
- Add release state tracking.
- Add failure-mode documentation.
- Add validation for missing or unsafe configuration.
- Test candidate failure and post-switch failure scenarios.

## Phase 4: Observability

- Document deployment event logging.
- Add deployment metrics guidance.
- Capture deployment duration, result, version, and rollback state.
- Add examples for integrating with existing monitoring systems.

## Phase 5: Governance

- Add release checklist.
- Define approval expectations.
- Document ownership model.
- Add changelog and release-note requirements.
- Clarify stable release criteria.

## Phase 6: v1.0 Hardening

- Validate fresh setup from documentation.
- Review security and secret-handling assumptions.
- Harden scripts for predictable failure behavior.
- Complete representative staging tests.
- Resolve known blockers for the documented production-ready scope.

