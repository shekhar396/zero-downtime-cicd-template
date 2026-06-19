# Pre-Release Plan

Pre-release versions are used to validate behavior without implying production readiness. Each phase should reduce uncertainty before the stable `v1.0.0` VM template is published.

## v1.0.0-alpha

**Purpose:** Prove the basic shape of the pipeline, scripts, configuration layout, release state, and documentation.

**What should be tested:**

- Docker image build or pull assumptions.
- Blue/green container startup on a non-production Linux VM.
- Draft NGINX switch approach.
- Basic health-check behavior.
- Initial release state recording.

**Promotion criteria:**

- The repository has a coherent implementation skeleton.
- Known gaps are documented.
- Maintainers can run experiments without unclear setup assumptions.

## v1.0.0-beta

**Purpose:** Validate the complete VM deployment flow in a controlled staging environment.

**What should be tested:**

- Jenkins pipeline execution from build through deployment.
- Candidate health-check failure handling.
- Successful NGINX traffic switch.
- Rollback to the previous active color.
- Environment configuration separation.
- Multi-service configuration shape.

**Promotion criteria:**

- End-to-end staging deployment succeeds repeatedly.
- Failure scenarios are documented with expected outcomes.
- Operator documentation is usable by someone who did not author the scripts.

## v1.0.0-rc1

**Purpose:** Confirm release-candidate quality for the documented Linux VM scope.

**What should be tested:**

- Clean installation from repository documentation.
- Fresh staging deployment using published instructions.
- Rollback after failed validation.
- Rollback after post-switch failure.
- Multi-service health-check and release-state behavior.
- Changelog and release notes accuracy.

**Promotion criteria:**

- No known blocker remains for the stated `v1.0.0` VM scope.
- Documentation and scripts agree.
- Maintainers approve the stable release scope.

## v1.0.0

**Purpose:** Publish the first stable release for the documented Linux VM scope.

**What should be tested:**

- Full VM deployment flow.
- Health gate.
- Traffic switch.
- Rollback path.
- Multi-service configuration.
- Environment-specific configuration examples.
- Release artifact and tag integrity.

**Promotion criteria:**

- All `v1.0.0-rc1` blockers are resolved.
- Release criteria in [RELEASE_SCOPE.md](RELEASE_SCOPE.md) are met.
- The release notes clearly state limitations.

## Claims Not Allowed Before v1.0.0

Before `v1.0.0`, the project must not claim:

- production readiness
- guaranteed zero downtime for every workload
- Kubernetes support
- complete rollback coverage for every application change
- validated compatibility with all application stacks
- enterprise compliance or audit readiness
- hands-free production operation
