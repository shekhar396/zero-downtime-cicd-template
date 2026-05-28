# Pre-Release Plan

Pre-release versions are used to validate behavior without implying production readiness. Each phase should narrow uncertainty before a stable `v0.1.0` tag is created.

## v0.1.0-alpha

**Purpose:** Prove the basic shape of the pipeline, scripts, configuration layout, and documentation.

**What should be tested:**

- Docker image build and tagging assumptions.
- Blue/green container startup on a non-production host.
- Draft NGINX switch approach.
- Basic health-check command behavior.

**Promotion criteria:**

- The repository has a coherent implementation skeleton.
- Known gaps are documented.
- Maintainers can run experiments without unclear setup assumptions.

## v0.1.0-beta

**Purpose:** Validate the complete MVP flow in a controlled staging environment.

**What should be tested:**

- Jenkins pipeline execution from build through deployment.
- Candidate health-check failure handling.
- Successful NGINX traffic switch.
- Rollback to the previous active color.
- Environment configuration separation.

**Promotion criteria:**

- End-to-end staging deployment succeeds repeatedly.
- Failure scenarios are documented with expected outcomes.
- Operator documentation is usable by someone who did not author the scripts.

## v0.1.0-rc1

**Purpose:** Confirm release-candidate quality for the single-server MVP scope.

**What should be tested:**

- Clean installation from repository documentation.
- Fresh staging deployment using published instructions.
- Rollback after failed validation.
- Rollback after post-switch failure.
- Changelog and release notes accuracy.

**Promotion criteria:**

- No known blocker remains for the stated MVP scope.
- Documentation and scripts agree.
- Maintainers approve the stable release scope.

## v0.1.0

**Purpose:** Publish the first stable MVP release for the documented single-server scope.

**What should be tested:**

- Full MVP deployment flow.
- Health gate.
- Traffic switch.
- Rollback path.
- Environment-specific configuration examples.
- Release artifact and tag integrity.

**Promotion criteria:**

- All `v0.1.0-rc1` blockers are resolved.
- Release criteria in `docs/RELEASE_PLAN.md` are met.
- The release notes clearly state limitations.

## Claims Not Allowed Before Stable Release

Before `v0.1.0`, the project must not claim:

- production readiness
- guaranteed zero downtime
- complete rollback coverage for every workload
- validated compatibility with all application stacks
- enterprise compliance or audit readiness
- hands-free production operation

