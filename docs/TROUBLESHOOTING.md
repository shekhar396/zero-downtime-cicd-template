# Troubleshooting

This guide covers common issues for the v1.0.0 Linux VM template.

## Config Validation Fails

Run:

```bash
make validate-config
```

Check for missing required fields, duplicate service names, duplicate ports, blue and green ports using the same value, health paths that do not begin with `/`, and deploy paths that are not absolute.

## Service State Is Missing

Run initialization again. It is safe and preserves existing state:

```bash
make init-service SERVICE=billing-api
make show-state SERVICE=billing-api
```

Expected local state path:

```text
/tmp/zero-downtime-cicd/services/billing-api/state
```

Production recommendation:

```text
/opt/apps/billing-api/state
```

## Runtime Start Fails

For no-Docker Linux VMs, use `runtime: systemd` and confirm the blue/green units exist:

```bash
systemctl status billing-api-blue
systemctl status billing-api-green
make status-color SERVICE=billing-api COLOR=green
```

For Docker-backed demo deployments, confirm Docker is installed:

```bash
docker --version
make status-color SERVICE=billing-api COLOR=green
```

The v1 runtime supports `runtime: systemd` and `runtime: container`. Unsupported runtime values fail intentionally.

## Health Checks Fail

Check the target port and health path from `config/services.yml`:

```bash
./scripts/healthcheck.sh http://localhost:18081/health --retries 10 --timeout 3
```

A successful health check requires an HTTP `2xx` response. Connection failures, timeouts, and non-`2xx` responses fail the gate.

## NGINX Validation Is Limited

If `nginx` is not installed, `validate-nginx.sh` performs static checks and warns that full syntax validation was skipped. Full validation requires NGINX on the target VM.

Generated config is written to `build/nginx` by default. The safe install path for switch tests is:

```text
./build/nginx-installed
```

Production install path recommendation:

```text
/etc/nginx/conf.d/zero-downtime/<service>.conf
```

## Traffic Switch Fails

A live switch fails safely if the target color is not running, health checks fail, NGINX validation fails, or reload fails. `active_color` is updated only after a successful reload.

Inspect state:

```bash
make show-state SERVICE=billing-api
```

## Rollback Fails

Rollback requires a retained release. List releases and inspect history:

```bash
make list-releases SERVICE=billing-api
make show-state SERVICE=billing-api
```

Manual rollback requires the selected release directory to exist under `releases/`.

## Jenkins Pipeline Fails

Check that the Jenkins agent has Bash, Git, Make, and access to the repository workspace. Live deploy stages also require systemd or Docker runtime access plus NGINX access on the target VM. Keep production secrets in Jenkins credentials, not Jenkinsfiles.

## Production Validation Note

This repository provides a template foundation. Do not claim production readiness for a workload until Docker startup, health checks, NGINX validation/reload, rollback, and application compatibility have been tested on the target Linux VMs.
