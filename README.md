# Zero-Downtime CI/CD Template

A practical Linux VM CI/CD template for blue/green deployments with Docker, NGINX traffic switching, health checks, rollback, release history, and Jenkins pipeline examples.

## Project Overview

This repository provides an application-agnostic release template for teams that deploy services to Linux virtual machines and want safer production changes without adopting a full platform stack first. It standardizes service configuration, release directories, active/inactive color state, health validation, generated NGINX config, controlled traffic switching, rollback, and Jenkins orchestration.

The v1.0.0 release is VM-focused. Kubernetes is not implemented in v1; Kubernetes, Helm, and cloud-native workflows remain the v2.0.0 roadmap direction.

## Problem It Solves

Manual VM releases often mix build steps, SSH commands, NGINX edits, health checks, and rollback decisions into one fragile operator flow. This template separates those concerns into clear scripts and docs so teams can:

- deploy to an inactive blue/green color before switching traffic
- validate candidate health before promotion
- generate and validate NGINX config before reload
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

- Docker
- NGINX
- access to write the configured service deploy paths
- permission to reload NGINX when performing a live switch

Optional:

- Jenkins for pipeline orchestration using the root `Jenkinsfile` or examples in `examples/jenkins/`

## v1.0.0 Features

- Linux VM deployment template
- application-agnostic `config/services.yml` service registry
- multi-service configuration for `billing-api`, `photo-api`, and `drive-api`
- Docker container runtime support through `runtime: container`
- blue/green color model with active and inactive ports
- release directory management under each service deploy path
- `current` symlink and release metadata tracking
- release retention cleanup with safe guards
- HTTP health-check utility with retries and timeout
- runtime start, stop, and status commands per color
- NGINX config generation and validation
- controlled NGINX traffic switching with dry-run mode
- rollback to previous or selected retained release
- main deployment orchestrator with dry-run mode
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
- runtime types beyond Docker/container mode
- a guarantee that every workload can achieve zero downtime without application-level readiness and compatibility work

## Quick Start

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

See [docs/QUICK_START.md](docs/QUICK_START.md) and [docs/DEMO_WALKTHROUGH.md](docs/DEMO_WALKTHROUGH.md) for the complete walkthrough.

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
make deploy-dry-run SERVICE=billing-api ARTIFACT=examples/mock-artifact
make rollback-dry-run SERVICE=billing-api
```

Live commands such as `make start-color`, `make switch-traffic`, `make deploy`, and `make rollback` require the target VM runtime prerequisites. Validate them in staging before production.

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

Deployment creates a release, starts the inactive color, health-checks that color, generates and validates NGINX config, reloads NGINX, then updates `active_color` only after the reload succeeds. The old color remains running until explicitly stopped.

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the deeper design.

## Jenkins Usage

The root `Jenkinsfile` provides a declarative pipeline with these parameters:

- `SERVICE_NAME`
- `ARTIFACT_PATH`
- `DEPLOY_ENV`
- `DRY_RUN`
- `AUTO_APPROVE`

The pipeline validates config, runs shell syntax checks, verifies the artifact path, runs deploy dry-run, requires manual approval for production unless explicitly bypassed, performs live deploy only when `DRY_RUN=false`, and prints rollback instructions on failure.

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

This repository is a template foundation, not a guarantee of zero downtime for every workload. Live Docker and NGINX behavior must be verified on target Linux VMs before production use.
