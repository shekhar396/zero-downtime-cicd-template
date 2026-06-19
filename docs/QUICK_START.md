# Quick Start

This guide gets the v1.0.0 Linux VM template ready for local validation. It uses the sample `billing-api` service and the mock artifact included in the repository.

## Prerequisites

Required for repository validation:

- Bash
- Git
- Make

Required for live service runtime and traffic switching on a Linux VM:

- Docker
- NGINX
- permission to write the configured service deploy path
- permission to reload NGINX for live traffic switching

Jenkins is optional and is only required when using the included pipeline examples.

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

Live runtime validation requires Docker. Example:

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
