# Operations

This document describes the operational expectations for the planned `v1.0.0` VM-based template. It is a runbook outline for future implementation, not a command reference yet.

## Operator Responsibilities

Operators are responsible for:

- provisioning and securing Linux VMs
- installing and maintaining Docker and NGINX
- configuring Jenkins credentials and deployment access
- defining service configuration and health-check paths
- validating releases in staging before production
- reviewing rollback risk before deployment
- keeping secrets out of the repository

## Service State Initialization

Before future deployment phases can operate on a service, initialize its release/state layout from the service registry:

```bash
./scripts/init-service.sh billing-api
make init-service SERVICE=billing-api
```

Initialization validates `config/services.yml`, confirms the service exists, creates the service directories, initializes `state/active_color` to `blue` only if it is missing, and creates `state/history.log` only if it is missing.

Running initialization more than once is safe. Existing state is preserved.

Inspect service state with:

```bash
./scripts/show-state.sh billing-api
make show-state SERVICE=billing-api
```

The inspection command prints service name, deploy path, active color, inactive color, current symlink target, latest history entry, and lock status.

The Phase 2 state foundation does not deploy code, switch NGINX traffic, perform rollback, or call Jenkins.

## Release Artifact Management

Phase 4 adds local release artifact directory management.

Create a release artifact record:

```bash
./scripts/create-release.sh billing-api examples/mock-artifact
make create-release SERVICE=billing-api ARTIFACT=examples/mock-artifact
```

List retained releases:

```bash
./scripts/list-releases.sh billing-api
make list-releases SERVICE=billing-api
```

A release ID uses this format:

```text
YYYYMMDDTHHMMSSZ-<short_git_hash>
```

If Git metadata is unavailable, the suffix is `nogit`.

The `current` symlink is updated to the newly created release directory. This is artifact bookkeeping only; it does not start the service, change blue/green active color, switch traffic, reload NGINX, call Jenkins, or run rollback.

Production VM configurations should use a durable application path such as `/opt/apps/<service-name>` for `deploy_path`. The repository examples use `/tmp/zero-downtime-cicd/services/<service-name>` for local validation without root privileges.

Retention defaults to `5` releases per service. Operators may set `retention_count` in `config/services.yml`. Values greater than `10` warn because release artifacts can consume disk quickly. Cleanup never deletes the release pointed to by `current` or the latest successful release found in `state/history.log`.

## Runtime Color Management

Phase 5 can start, stop, and inspect one blue/green service color container.

Start a color from an existing release artifact:

```bash
./scripts/start-color.sh billing-api green <release_id>
make start-color SERVICE=billing-api COLOR=green RELEASE=<release_id>
```

Inspect a color:

```bash
./scripts/status-color.sh billing-api green
make status-color SERVICE=billing-api COLOR=green
```

Stop only that color:

```bash
./scripts/stop-color.sh billing-api green
make stop-color SERVICE=billing-api COLOR=green
```

Container names are deterministic:

```text
<service_name>-<color>
```

The runtime foundation supports only `runtime: container` and requires Docker on the Linux VM. The demo mode expects `artifact/app.txt` in the release directory and starts a small HTTP service that returns `200` on `/health`.

Starting a color does not update `state/active_color`, stop the other color, switch NGINX traffic, run rollback, or call Jenkins. Operators should treat this phase as process startup validation only.

## NGINX Config Generation

Phase 6 generates reviewable NGINX config files into `build/nginx`:

```bash
./scripts/generate-nginx.sh
./scripts/generate-nginx.sh --service billing-api
./scripts/generate-nginx.sh --output ./build/nginx
make generate-nginx
```

Validate generated files:

```bash
./scripts/validate-nginx.sh ./build/nginx
make validate-nginx
```

If `nginx` is installed, validation runs `nginx -t` against a temporary config. If it is not installed, static checks run and the command warns that full syntax validation was skipped.

Generated files use the service `active_color` to choose the upstream port. Changing `state/active_color` changes the generated upstream port. Phase 6 does not write to `/etc/nginx`, reload NGINX, switch traffic, update active color, implement rollback, or call Jenkins.

Future production install path recommendation:

```text
/etc/nginx/conf.d/zero-downtime/<service>.conf
```

## Controlled Traffic Switching

Phase 7 switches one service to a target color after health and NGINX validation gates pass.

Dry-run first:

```bash
./scripts/switch-traffic.sh billing-api green --dry-run
make switch-traffic-dry-run SERVICE=billing-api COLOR=green
```

Live switch:

```bash
./scripts/switch-traffic.sh billing-api green
make switch-traffic SERVICE=billing-api COLOR=green
```

Default install path is local and safe:

```text
./build/nginx-installed
```

Override the install path only when intentionally preparing an operational host:

```bash
NGINX_INSTALL_DIR=/etc/nginx/conf.d/zero-downtime ./scripts/switch-traffic.sh billing-api green
```

Default reload command:

```bash
nginx -s reload
```

Override example:

```bash
NGINX_RELOAD_CMD="sudo systemctl reload nginx" ./scripts/switch-traffic.sh billing-api green
```

`active_color` is updated only after NGINX validation and reload succeed. If target container validation, health checks, config validation, or reload fails, the previous active color remains unchanged. The old color is not stopped automatically.

## Pre-Deployment Checklist

Before a release, confirm:

- target environment is correct
- image tag is immutable and approved
- service configuration is present
- health-check endpoint is known
- NGINX configuration path is correct
- current active color and version are known
- rollback target exists
- release owner and approver are identified
- application changes are backward compatible where required

## Deployment Flow

The planned deployment flow is:

1. Jenkins receives a release trigger.
2. Jenkins validates inputs and target environment.
3. Jenkins builds or pulls the tagged image.
4. The inactive blue/green slot is prepared.
5. Candidate containers start on the inactive slot.
6. Health checks run against the candidate.
7. NGINX switches traffic only after validation succeeds.
8. Post-switch verification confirms the active service is healthy.
9. Release state records version, color, status, and timestamp.

## Rollback Operation

Dry-run the default rollback target:

```bash
./scripts/rollback.sh billing-api --dry-run
make rollback-dry-run SERVICE=billing-api
```

Dry-run a manual retained release:

```bash
./scripts/rollback.sh billing-api --release <release_id> --dry-run
make rollback-dry-run SERVICE=billing-api RELEASE=<release_id>
```

Run rollback:

```bash
./scripts/rollback.sh billing-api
make rollback SERVICE=billing-api
```

Default rollback chooses the previous retained successful release from `state/history.log`. Manual rollback requires the release directory to exist under `releases/`.

Failure behavior:

- missing release fails before runtime changes
- failed start fails before traffic switch
- failed health check fails before traffic switch
- failed switch keeps `active_color` unchanged
- old color remains running until explicitly stopped

## Rollback Flow

Rollback should restore the last known healthy release before deeper debugging.

Expected rollback steps:

1. Read release state.
2. Identify the previous healthy color and version.
3. Switch NGINX traffic back to that color.
4. Run health checks against the restored service.
5. Record the rollback event.
6. Preserve logs and deployment metadata for review.

## Release Health Validation

Phase 3 adds health validation commands for operators and future deployment scripts.

Run a direct URL check:

```bash
./scripts/healthcheck.sh http://localhost:8080/health
make health URL=http://localhost:8080/health
```

Validate a registered service candidate port:

```bash
./scripts/validate-release.sh billing-api 18080
```

Before running `validate-release.sh`, initialize service state:

```bash
./scripts/init-service.sh billing-api
```

A successful health check requires an HTTP `2xx` response. Non-`2xx` responses, connection failures, and timeouts are failures. Phase 3 validation does not deploy code, switch traffic, promote a release, reload NGINX, or run rollback.

## Health-Check Expectations

Each service should define:

- health-check path
- expected HTTP status code
- timeout
- retry count
- startup grace period
- post-switch verification behavior

A failed candidate health check must prevent promotion.

## Multi-Service Operations

For multi-service deployments, operators should document:

- service ownership
- deployment order
- dependency assumptions
- health-check requirements per service
- rollback behavior per service
- compatibility constraints between versions

When services share databases or APIs, rollback may require application-level compatibility planning. The deployment template should make this risk visible but cannot solve incompatible application changes by itself.

## Incident Handling

During a deployment incident:

- stop further promotion
- restore traffic to the last known healthy color when possible
- preserve Jenkins logs, NGINX logs, container logs, and release state
- identify whether failure occurred before or after traffic switch
- document the user impact and corrective action
- update runbooks if the failure mode was not covered

## Secrets and Access

Secrets must be supplied through the operator's approved secret-management process. The repository should only contain placeholders and documentation.

Deployment access should follow least privilege. Jenkins should have only the permissions required to deploy, validate, switch traffic, and roll back.

## Production Readiness Notes

The template can reduce deployment risk, but operators still need:

- application readiness endpoints
- backward-compatible releases
- tested rollback assumptions
- monitoring outside the deployment pipeline
- reviewed production access controls
- environment-specific validation
