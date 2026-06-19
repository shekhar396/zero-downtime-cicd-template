# Demo Walkthrough

This walkthrough demonstrates the v1.0.0 flow using `billing-api` and `examples/mock-artifact`.

The local sample deploy path is:

```text
/tmp/zero-downtime-cicd/services/billing-api
```

Production VM configs should use a durable path such as:

```text
/opt/apps/billing-api
```

## 1. Validate The Repository

```bash
make validate-config
make lint-shell
```

## 2. Initialize Service State

```bash
make init-service SERVICE=billing-api
make show-state SERVICE=billing-api
```

Expected layout under the deploy path:

```text
releases/
shared/
state/
  active_color
  history.log
current -> releases/<release_id>
```

`current` appears after a release is created.

## 3. Create A Release

```bash
make create-release SERVICE=billing-api ARTIFACT=examples/mock-artifact
make list-releases SERVICE=billing-api
```

Copy the newest `release_id` for the next step.

## 4. Start The Inactive Color

Check the inactive color first:

```bash
make show-state SERVICE=billing-api
```

Start the color with Docker on a Linux VM:

```bash
make start-color SERVICE=billing-api COLOR=green RELEASE=<release_id>
make status-color SERVICE=billing-api COLOR=green
```

If Docker is unavailable, this step should fail clearly and leave `active_color` unchanged.

## 5. Run A Health Check

For the default `billing-api` green port:

```bash
make health URL=http://localhost:18081/health
```

The health check succeeds only on HTTP `2xx`.

## 6. Dry-Run A Traffic Switch

```bash
make switch-traffic-dry-run SERVICE=billing-api COLOR=green
```

Dry-run shows the generated NGINX config path, intended install path, and reload command without copying config, reloading NGINX, or changing `active_color`.

## 7. Dry-Run Rollback

```bash
make rollback-dry-run SERVICE=billing-api
```

Rollback dry-run shows the selected retained release, target color, candidate port, and intended switch.

## 8. Dry-Run Full Deploy

```bash
make deploy-dry-run SERVICE=billing-api ARTIFACT=examples/mock-artifact
```

This is the safest end-to-end command for local review because it does not create a release, start containers, reload NGINX, or update `active_color`.

## Live Verification Boundary

A live deployment requires Docker and NGINX on the target Linux VM. Verify live start, health, NGINX validation, switch, and rollback in staging before production use.
