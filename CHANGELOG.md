# Changelog

All notable changes to this project will be documented in this file.

This project follows semantic versioning for public releases.

## Unreleased

No unreleased changes yet.

## v1.0.0 - 2026-06-19

### Added

- Linux VM zero-downtime CI/CD template foundation.
- Application-agnostic service registry with the official `zero-downtime-demo-go` example.
- Configuration validation for required fields, duplicate names, duplicate ports, health paths, and absolute deploy paths.
- Service state initialization and inspection with active color, release history, lock status, and `current` symlink visibility.
- Release artifact creation, metadata, listing, history entries, and retention cleanup.
- HTTP health-check utility with retry and timeout support.
- systemd runtime color management for blue and green service instances.
- Apache and NGINX config generation and validation with safe local output defaults.
- Controlled traffic switching with health and NGINX validation gates.
- Rollback support for previous retained or manually selected releases.
- Main deployment orchestrator with dry-run mode and failure-safe active color behavior.
- Jenkins integration guidance for the official Go demo workflow.
- Focused public documentation for onboarding, configuration, operations, troubleshooting, architecture, and contribution.
- Makefile command surface including `make help`, `make validate-config`, and `make lint-shell`.

### Changed

- README now presents the project as a public v1.0.0 Linux VM template foundation.
- Documentation now describes v1 as a Linux VM template using systemd with Apache or NGINX.
- The official public example is `zero-downtime-demo-go`.
- Apache live traffic switches now default to the site path and non-interactive commands used by onboarding, so daily deploy and rollback commands update the installed proxy configuration.
- Rollback now selects the retained release through `current`, restores the previous target on failure, and exposes the selected release ID to systemd applications.
- Kubernetes, Helm, and cloud-native workflows remain documented only as future v2.0.0 roadmap scope.

### Known limitations

- Live systemd and proxy behavior must be verified on target Linux VMs before production use.
- The template does not automate database migrations, secrets platforms, service mesh, autoscaling, or cloud infrastructure.
- Zero downtime still depends on application readiness, backward compatibility, and safe dependency behavior.
- Jenkins integration should be reviewed in the target Jenkins controller before use.
