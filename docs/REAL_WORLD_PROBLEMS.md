# Real-World Problems

This repository is designed around production failure modes that appear when deployment workflows grow faster than release discipline.

## Deployment Causes 502 Errors

**Problem:** A deployment stops the running container before the replacement is ready. NGINX temporarily routes traffic to an unavailable upstream and users see 502 responses.

**Business impact:** Customers experience downtime during routine releases, support volume increases, and confidence in engineering reliability declines.

**Engineering impact:** Engineers rush to restart services manually, deployment windows become stressful, and teams avoid releasing frequently.

**Planned solution:** Use a blue/green model where the candidate container starts on the inactive color, passes health checks, and only then receives traffic through NGINX.

## Manual Deployment Breaks Production

**Problem:** Production changes are executed over SSH using hand-run commands that vary by operator, time pressure, and local shell history.

**Business impact:** Release outcomes become unpredictable and recovery depends on who is available.

**Engineering impact:** Manual steps create configuration mistakes, skipped checks, and weak auditability.

**Planned solution:** Move deployment actions into reviewed scripts and Jenkins stages with explicit inputs, logging, and repeatable release behavior.

## Broken Build Is Deployed Without Validation

**Problem:** A container image builds successfully but the application fails at startup or its health endpoint is broken.

**Business impact:** A technically successful build becomes a failed customer-facing release.

**Engineering impact:** Build success is confused with deployment readiness, and detection happens after users are affected.

**Planned solution:** Treat health-check validation as a deployment gate. The candidate release must prove it can serve the expected health endpoint before traffic is switched.

## No Rollback Available

**Problem:** A release fails after deployment, but the previous version was removed or the rollback steps are undocumented.

**Business impact:** Outage duration increases and stakeholders lose confidence in release operations.

**Engineering impact:** Engineers debug under pressure instead of restoring service first.

**Planned solution:** Keep the last active color available, record release state, and document rollback commands as part of the release workflow.

## Environment Drift Between Staging and Production

**Problem:** Staging and production use different assumptions for ports, environment variables, image tags, or NGINX behavior.

**Business impact:** Staging validation gives false confidence and production releases still fail.

**Engineering impact:** Teams spend time diagnosing environment-specific surprises instead of improving the delivery system.

**Planned solution:** Define environment separation through explicit configuration files, naming conventions, and documentation that keeps deployment mechanics consistent across environments.

## Missing Deployment Audit Trail

**Problem:** The team cannot easily answer who deployed what version, when it was deployed, and whether validation passed.

**Business impact:** Incident review, compliance, and customer communication become harder.

**Engineering impact:** Root-cause analysis relies on memory and fragmented logs.

**Planned solution:** Plan Jenkins release records, immutable image tags, release state files, and changelog discipline as first-class repository concerns.

## Release Pressure Before Holidays or Business Hours

**Problem:** Releases are rushed before holidays, peak business periods, or stakeholder deadlines without clear readiness criteria.

**Business impact:** Risk is concentrated at the worst possible time, increasing the chance of visible incidents.

**Engineering impact:** Teams make subjective go/no-go decisions without shared standards.

**Planned solution:** Define pre-release phases, release criteria, and non-claims so teams can distinguish experimental, candidate, and stable template maturity.

