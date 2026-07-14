# Zero-Downtime CI/CD Template

A practical Linux VM CI/CD template for blue/green deployments with systemd or Docker, NGINX or Apache traffic switching, health checks, rollback, release history, and Jenkins pipeline examples.

## Project Overview

This repository provides an application-agnostic release template for teams that deploy services to Linux virtual machines and want safer production changes without adopting a full platform stack first. It standardizes service configuration, release directories, active/inactive color state, health validation, generated NGINX or Apache config, controlled traffic switching, rollback, and Jenkins orchestration.

The v1.0.0 release is VM-focused. Kubernetes is not implemented in v1; Kubernetes, Helm, and cloud-native workflows remain the v2.0.0 roadmap direction.

## Problem It Solves

Manual VM releases often mix build steps, SSH commands, NGINX or Apache edits, health checks, and rollback decisions into one fragile operator flow. This template separates those concerns into clear scripts and docs so teams can:

- deploy to an inactive blue/green color before switching traffic
- validate candidate health before promotion
- generate and validate NGINX or Apache config before reload
- preserve release history and inspect state during incidents
- roll back to a retained release through a repeatable workflow
- run the same flow locally, manually, or from Jenkins

## Who Should Use It

This project is for DevOps engineers, platform engineers, SRE-minded backend teams, and small to mid-sized organizations running containerized services on Linux VMs. It is also useful as a portfolio-grade example of practical CI/CD architecture, release safety, and operational documentation.

## Prerequisites

For local dry-runs and validation:

- Bash
- Git
- Make

For live runtime and traffic switching on a Linux VM:

- systemd for no-Docker VM deployments, or Docker for container/demo deployments
- NGINX or Apache HTTPD
- sudo access for privileged VM operations such as deploy directory creation, systemd unit installation, Apache site installation, module enablement, and proxy reloads

When `proxy_runtime: apache` is used, onboarding verifies Apache, enables the required `proxy`, `proxy_http`, and `headers` modules when needed, installs the generated site, creates a managed `Listen <public_port>` config for non-80 ports, runs `apache2ctl configtest`, and reloads Apache.

Optional:

- Jenkins for pipeline orchestration using the root `Jenkinsfile` or examples in `examples/jenkins/`

## v1.0.0 Features

- Linux VM deployment template
- application-agnostic `config/services.yml` service registry
- multi-service configuration for `billing-api`, `photo-api`, and `drive-api`
- first-class systemd runtime support through `runtime: systemd`
- optional Docker/container runtime support through `runtime: container`
- blue/green color model with active and inactive ports
- release directory management under each service deploy path
- `current` symlink and release metadata tracking
- release retention cleanup with safe guards
- HTTP health-check utility with retries and timeout
- runtime start, stop, and status commands per color
- NGINX config generation and validation
- controlled NGINX or Apache traffic switching with dry-run mode
- rollback to previous or selected retained release
- main deployment orchestrator with dry-run mode
- automated application onboarding workflow for first local VM validation
- Jenkins declarative pipeline examples
- operator docs, troubleshooting docs, demo guide, and release checklist

## What v1.0.0 Does Not Support

- Kubernetes manifests, Helm charts, operators, or controllers
- service mesh integration
- cloud-provider-specific infrastructure provisioning
- autoscaling orchestration
- multi-region deployment automation
- database migration automation
- secret-management platform implementation
- full observability stack installation
- runtime types beyond `systemd` and `container`
- a guarantee that every workload can achieve zero downtime without application-level readiness and compatibility work

## New Service Onboarding

Before onboarding your first application, follow the complete step-by-step guide:

[Read the Service Onboarding Guide](docs/ONBOARDING.md)

The guide covers:

- registering services in `config/services.yml`
- preparing deployment directories and permissions
- initializing one or multiple services
- generating and installing blue/green systemd units
- preparing shared environment files
- performing the first deployment
- verifying health, logs, state, and proxy traffic
- troubleshooting common onboarding problems

The shorter quick start below is useful after you understand the full workflow.

## Quick Start

For a first live validation on a Linux VM, run onboarding as a normal user. It validates the host and template config, prepares the deploy path, creates `shared/.env` from `config/app.env.example` when missing, builds the application as the current user, prepares systemd units for `runtime: systemd`, configures Apache when `proxy_runtime: apache`, delegates deployment to the existing deploy flow, and verifies `/live`, `/health`, `/ready`, and `/version` through the configured public port.

```bash
./scripts/onboard.sh \
  --source ~/workspace/zero-downtime-demo-go \
  --environment production
```

Use `--artifact <path>` when the build output cannot be inferred. Use `--build-command <command>` to replace the default `make test` and `make build` sequence for non-Makefile runtimes. The script uses sudo only for privileged VM operations and refuses to run build commands as root. If installed systemd units or managed Apache files differ from generated files, onboarding aborts; rerun with `--force` only after reviewing the generated files and accepting timestamped backups.

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

Validate the repository foundation:

```bash
make help
make validate-config
make lint-shell
```

Initialize and inspect the sample service state:

```bash
make init-service SERVICE=billing-api
make show-state SERVICE=billing-api
```

`init-service.sh` can also select a registered service interactively, initialize
the complete registry, and safely prepare systemd units:

```bash
./scripts/init-service.sh                         # interactive selection
./scripts/init-service.sh --all
./scripts/init-service.sh billing-api --generate-systemd
./scripts/init-service.sh billing-api --install-systemd
./scripts/init-service.sh --all --install-systemd --yes  # Jenkins/non-interactive
```

`--install-systemd` implies generation, links the generated blue/green units
under `/etc/systemd/system`, reloads systemd, and enables both units. It never
starts or restarts them. Existing or partial blue/green installations are not
overwritten or repaired; the service is stopped (or skipped in `--all` mode)
for manual review.

Create and list a release from the mock artifact:

```bash
make create-release SERVICE=billing-api ARTIFACT=examples/mock-artifact
make list-releases SERVICE=billing-api
```

Dry-run deployment and rollback flows:

```bash
make deploy-dry-run SERVICE=billing-api ARTIFACT=examples/mock-artifact
make rollback-dry-run SERVICE=billing-api
```

See the [Service Onboarding Guide](docs/ONBOARDING.md), [Quick Start](docs/QUICK_START.md), and [Demo Walkthrough](docs/DEMO_WALKTHROUGH.md) for guided workflows.

## Main Commands

```bash
make validate-config
make lint-shell
make init-service SERVICE=billing-api
make show-state SERVICE=billing-api
make create-release SERVICE=billing-api ARTIFACT=examples/mock-artifact
make list-releases SERVICE=billing-api
make start-color SERVICE=billing-api COLOR=green RELEASE=<release_id>
make status-color SERVICE=billing-api COLOR=green
make health URL=http://localhost:18081/health
make switch-traffic-dry-run SERVICE=billing-api COLOR=green
./scripts/generate-apache.sh
./scripts/validate-apache.sh ./build/apache
./scripts/switch-traffic.sh pico-photos-api green --dry-run
make deploy-dry-run SERVICE=billing-api ARTIFACT=examples/mock-artifact
make rollback-dry-run SERVICE=billing-api
```

Live commands such as `make start-color`, `make switch-traffic`, `make deploy`, and `make rollback` require the target VM runtime prerequisites. For no-Docker VMs, use `runtime: systemd` and blue/green systemd units such as `billing-api-blue` and `billing-api-green`. Validate them in staging before production.

## Architecture Summary

Each service has a configured deploy path. Local examples use:

```text
/tmp/zero-downtime-cicd/services/<service-name>
```

Production VM configurations should use a durable path such as:

```text
/opt/apps/<service-name>
```

The per-service layout is:

```text
<deploy_path>/
├── releases/
├── shared/
├── state/
│   ├── active_color
│   ├── deploy.lock
│   └── history.log
└── current -> releases/<release_id>
```

Systemd runtime services should use separate blue/green units, for example:

```text
billing-api-blue
billing-api-green
```

Generate blue/green systemd units with `./scripts/init-service.sh <service> --generate-systemd`, or install new units with `--install-systemd`. Installation refuses to overwrite any unit already known to systemd and rolls back links and enablement created by a failed attempt. Onboarding uses the same generator, compares installed units, backs up differing units only with `--force`, reloads systemd, and enables units without restarting them. The generated units expose `ZERO_DOWNTIME_PORT`, `PORT`, `ZERO_DOWNTIME_COLOR`, `ZERO_DOWNTIME_DEPLOY_PATH`, and `ZERO_DOWNTIME_RELEASE_DIR`. The `current` path remains the release symlink managed by `create-release.sh`, not a directory created during onboarding.

Deployment creates a release, starts the inactive color, health-checks that color, generates and validates the configured proxy config, reloads NGINX or Apache, then updates `active_color` only after the reload succeeds. The old color remains running until explicitly stopped.

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the deeper design.

## Jenkins Usage

The root `Jenkinsfile` provides a declarative pipeline with these parameters:

- `SERVICE_NAME`
- `ARTIFACT_PATH`
- `DEPLOY_ENV`
- `DRY_RUN`
- `AUTO_APPROVE`

The pipeline validates config, runs shell syntax checks, verifies the artifact path, runs deploy dry-run, requires manual approval for production unless explicitly bypassed, performs live deploy only when `DRY_RUN=false`, and prints rollback instructions on failure.

For Apache production installs from Jenkins, use non-interactive sudo command overrides:

```bash
APACHE_CONFIG_DIR=/etc/apache2/sites-available \
APACHE_INSTALL_CMD="sudo -n cp" \
APACHE_ENABLE_CMD="sudo -n a2ensite pico-photos-api.conf" \
APACHE_RELOAD_CMD="sudo -n systemctl reload apache2" \
./scripts/switch-traffic.sh pico-photos-api green
```

Recommended branch flow:

```text
develop -> main -> tag v1.0.0
```

## Rollback Usage

Dry-run the default rollback target:

```bash
./scripts/rollback.sh billing-api --dry-run
make rollback-dry-run SERVICE=billing-api
```

Rollback to a selected retained release:

```bash
./scripts/rollback.sh billing-api --release <release_id> --dry-run
./scripts/rollback.sh billing-api --release <release_id>
```

Rollback starts the selected release on the inactive color, health-checks it, and switches traffic only if validation succeeds. It does not stop the old color automatically.

## Roadmap

- `v1.0.0` - stable Linux VM zero-downtime CI/CD template
- `v1.x` - hardening, compatibility improvements, and additional examples
- `v2.0.0` - future Kubernetes-native direction using Kubernetes, Helm, and cloud-native deployment workflows

See [docs/ROADMAP.md](docs/ROADMAP.md) for the public roadmap.

## Disclaimer

This repository is a template foundation, not a guarantee of zero downtime for every workload. Live systemd or Docker runtime behavior and NGINX or Apache behavior must be verified on target Linux VMs before production use.
