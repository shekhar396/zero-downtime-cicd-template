# Configuration

This document summarizes the planned `v1.0.0` configuration model. The complete architecture, examples, and state design live in [ARCHITECTURE.md](ARCHITECTURE.md).

## v1 Configuration Direction

The stable VM template should use YAML configuration split into two responsibilities:

- `config/services.yml` registers application services in an application-agnostic way.
- `config/environments/<environment>.yml` defines VM, NGINX, Docker, state, and release settings for each environment.

Older single-service `.env` examples are useful as early scaffolding only. They should not be treated as the final `v1.0.0` configuration format.

## Service Configuration

Each service entry should define:

- stable service name
- image repository
- NGINX host and path route
- blue and green ports
- health-check path, expected status, timeout, retry count, and interval
- deployment order and graceful stop behavior
- optional runtime environment file reference

Service-specific deployment scripts should not be required for normal operation. A service should be onboarded by registration and configuration.

## Environment Configuration

Each environment should define:

- release root
- state root
- log root
- deployment user
- Docker network and registry assumptions
- NGINX generated config path
- NGINX validation and reload commands
- release history retention
- default deployment timeout

## Runtime Values and Secrets

Runtime environment files may be referenced from service configuration, but secrets must not be committed to this repository. Operators should provide secrets through their approved secret-management process.

## State Is Not Configuration

The active color should not be stored as a hand-edited configuration value in v1. Active color, previous color, active image, previous image, release status, and history belong in generated state files under the target VM state directory.
