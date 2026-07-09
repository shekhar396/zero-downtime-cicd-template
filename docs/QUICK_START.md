# Quick Start

This guide gets the v1.0.0 Linux VM template ready for local validation. The recommended first live validation path is the automated onboarding workflow; the lower-level commands remain available for focused testing.

## Prerequisites

Required for repository validation:

- Bash
- Git
- Make

Required for live service runtime, onboarding, and traffic switching on a Linux VM:

- systemd for no-Docker deployments, or Docker for container/demo deployments
- NGINX or Apache HTTPD, matching `proxy_runtime` in `config/services.yml`
- permission to write the configured service deploy path
- passwordless or non-interactive `sudo` for privileged VM operations during live onboarding

When `proxy_runtime: apache` is used, onboarding verifies Apache, enables `proxy`, `proxy_http`, and `headers` when needed, installs and enables the generated site, creates a managed listen config for non-80 `public_port` values, runs `apache2ctl configtest`, and reloads Apache.

Jenkins is optional and is only required when using the included pipeline examples.

## Application Onboarding

Run the single onboarding entry point as a normal user from this repository and point it at the application source directory:

```bash
./scripts/onboard.sh \
  --source ~/workspace/zero-downtime-demo-go \
  --environment production
```

The script orchestrates existing template components: it calls `validate-config.sh`, `init-service.sh`, generated systemd unit support, Apache generation/validation when configured, and `deploy.sh`. It does not duplicate deployment, release, health, proxy generation, or service discovery logic. It requests sudo only for privileged VM operations and refuses to run build commands as root.

By default, onboarding runs `make test` and `make build` in the source directory when a Makefile exists. For future runtimes, provide one or more custom build commands and the artifact path:

```bash
./scripts/onboard.sh \
  --source ~/workspace/zero-downtime-demo-node \
  --service zero-downtime-demo-node \
  --build-command "npm ci" \
  --build-command "npm test" \
  --build-command "npm run build" \
  --artifact dist
```

If `shared/.env` is missing under the configured deploy path, onboarding creates it from `config/app.env.example` and leaves existing files untouched. The `current` path is managed as the release symlink by `create-release.sh`; onboarding does not create it as a directory.

For existing systemd units and managed Apache files, onboarding compares installed files with generated files. Matching files are left alone. Differing files abort the run unless `--force` is supplied, in which case timestamped backups are written before replacement. Onboarding enables systemd units but does not restart them outside the deploy flow.

| Situation | Expected behavior |
| --- | --- |
| First run | Creates deploy dirs, env file, systemd units, Apache config, and deploys the app |
| Rerun with no config changes | Reuses matching resources and deploys a new release |
| Existing systemd/Apache files differ | Aborts unless `--force` is supplied |
| `--force` | Backs up existing managed files before replacing them |
| `.env` exists | Preserved, never overwritten |

Apache may print `AH00558: Could not reliably determine the server's fully qualified domain name`. This warning is harmless for onboarding. To suppress it on Ubuntu/Debian Apache installs:

```bash
echo "ServerName localhost" | sudo tee /etc/apache2/conf-available/servername.conf
sudo a2enconf servername
sudo systemctl reload apache2
```

## Validate The Repository

```bash
make help
make validate-config
make lint-shell
```

`make validate-config` validates `config/services.yml`. `make lint-shell` runs `bash -n` across shell scripts under `scripts/` and `examples/`.

## Initialize A Service

```bash
make init-service SERVICE=billing-api
make show-state SERVICE=billing-api
```

The sample local deploy path is:

```text
/tmp/zero-downtime-cicd/services/billing-api
```

For production VMs, use a durable service path such as:

```text
/opt/apps/billing-api
```

## Create A Release

```bash
make create-release SERVICE=billing-api ARTIFACT=examples/mock-artifact
make list-releases SERVICE=billing-api
```

Copy a release ID from the output when testing runtime commands.

## Dry-Run Deployment

```bash
make deploy-dry-run SERVICE=billing-api ARTIFACT=examples/mock-artifact
```

Dry-run mode shows the planned release, target color, target port, health URL, and NGINX switch without creating a release, starting containers, reloading NGINX, or updating `active_color`.

## Live Runtime Validation

For no-Docker VMs, use `runtime: systemd` with blue/green units such as `billing-api-blue` and `billing-api-green`. For Docker-backed demo validation, use `runtime: container`. Example container/demo commands:

```bash
make start-color SERVICE=billing-api COLOR=green RELEASE=<release_id>
make status-color SERVICE=billing-api COLOR=green
make health URL=http://localhost:18081/health
```

## Traffic Switch Dry Run

```bash
make switch-traffic-dry-run SERVICE=billing-api COLOR=green
```

Dry-run validates the target and generated config plan without copying config to the install path, reloading NGINX, or updating `active_color`.

## Rollback Dry Run

```bash
make rollback-dry-run SERVICE=billing-api
```

Rollback dry-run shows the selected retained release, target color, candidate port, and intended switch.
