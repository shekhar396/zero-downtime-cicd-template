# Changelog

All notable changes to this project will be documented in this file.

This project follows semantic versioning for public releases.

## Unreleased

No unreleased changes yet.

## v1.0.0 - 2026-06-19

### Added

- Linux VM zero-downtime CI/CD template foundation.
- Application-agnostic service registry with sample `billing-api`, `photo-api`, and `drive-api` services.
- Configuration validation for required fields, duplicate names, duplicate ports, health paths, and absolute deploy paths.
- Service state initialization and inspection with active color, release history, lock status, and `current` symlink visibility.
- Release artifact creation, metadata, listing, history entries, and retention cleanup.
- HTTP health-check utility with retry and timeout support.
- Docker/container runtime color management for blue and green service instances.
- NGINX config generation and validation with safe local output defaults.
- Controlled traffic switching with health and NGINX validation gates.
- Rollback support for previous retained or manually selected releases.
- Main deployment orchestrator with dry-run mode and failure-safe active color behavior.
- Jenkins declarative pipeline examples for single-service and multi-service workflows.
- Public release docs: quick start, troubleshooting, release checklist, and demo walkthrough.
- Makefile command surface including `make help`, `make validate-config`, and `make lint-shell`.

### Changed

- README now presents the project as a public v1.0.0 Linux VM template foundation.
- Documentation now consistently describes v1 as Docker/container runtime on Linux VMs.
- Production deploy path guidance uses `/opt/apps/<service-name>`.
- Local validation deploy path guidance uses `/tmp/zero-downtime-cicd/services/<service-name>`.
- Kubernetes, Helm, and cloud-native workflows remain documented only as future v2.0.0 roadmap scope.

### Known limitations

- Live Docker and NGINX behavior must be verified on target Linux VMs before production use.
- v1 supports only `runtime: container`.
- The template does not automate database migrations, secrets platforms, service mesh, autoscaling, or cloud infrastructure.
- Zero downtime still depends on application readiness, backward compatibility, and safe dependency behavior.
- Jenkinsfiles are examples and should be reviewed in the target Jenkins controller before use.
