# Zero Downtime CI/CD Template

A blue/green deployment framework for Linux VMs using systemd, Apache or NGINX, health checks, release history, rollback, and application onboarding.

## Why this project exists

Many teams still deploy applications directly to Linux VMs, where manual service restarts and proxy edits make releases risky. This project provides a repeatable blue/green deployment flow without requiring Kubernetes.

## Features

- Blue/green deployment
- systemd runtime
- Apache and NGINX proxy support
- Health checks before traffic switching
- Release history and retention
- Rollback to a retained release
- First-time application onboarding
- Jenkins-compatible deployment commands
- Idempotent managed configuration handling

## How it works

```text
Application source
      ↓
Build artifact
      ↓
Inactive color starts
      ↓
Health check
      ↓
Proxy traffic switches
      ↓
Old color stops
```

The proxy listens on the public port and routes requests to either the blue or green application port. A release is promoted only after the inactive color passes its health check.

## Quick start

Run this on a Linux VM that meets the [requirements](#requirements). Onboarding installs systemd and proxy configuration, so use a normal user with passwordless non-interactive `sudo` access.

```bash
git clone https://github.com/shekhar396/zero-downtime-cicd-template.git
git clone https://github.com/shekhar396/zero-downtime-demo-go.git
cd zero-downtime-cicd-template

./scripts/onboard.sh \
  --source ../zero-downtime-demo-go \
  --environment production
```

The demo's Makefile is detected automatically. Onboarding runs its tests and build, then deploys `bin/zero-downtime-demo-go`.

Verify the public endpoint:

```bash
curl http://127.0.0.1:8080/live
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/version
```

For the complete deployment and rollback walkthrough, see [Quick Start](docs/QUICK_START.md).

## Requirements

- Linux with systemd
- Bash, Git, `curl`, and `sudo`
- Passwordless non-interactive sudo for managed system files and services
- Apache or NGINX
- Application build tools; Go is required for the official demo
- An application with a configurable port and HTTP health endpoint
- Three available TCP ports: one public, one blue, and one green

## Important concepts

| Setting | Meaning |
| --- | --- |
| `public_port` | Port where Apache or NGINX accepts client traffic |
| `blue_port` | Port used by the blue application instance |
| `green_port` | Port used by the green application instance |
| `deploy_path` | Root directory for shared data, releases, state, and the `current` symlink |
| `env_file` | Shared runtime environment file preserved across releases |
| `health_path` | HTTP path used to validate a candidate color before promotion |

The generated systemd units inject color-specific `PORT` and `ACTIVE_COLOR` values. Do not add those variables to the shared environment file.

## Daily deployment

Use `onboard.sh` for first-time setup and to reconcile managed systemd or proxy configuration. Normal CI/CD deployments build an artifact and call `deploy.sh`:

```bash
cd ../zero-downtime-demo-go
make test
make build
cd ../zero-downtime-cicd-template

./scripts/deploy.sh \
  zero-downtime-demo-go \
  ../zero-downtime-demo-go/bin/zero-downtime-demo-go
```

The deploy command creates a release, starts the inactive color, validates `/health`, and switches proxy traffic. It leaves the old color running; stop it after verification:

```bash
./scripts/show-state.sh zero-downtime-demo-go
./scripts/stop-color.sh zero-downtime-demo-go blue
```

Use the color shown as inactive by `show-state.sh`; it may be green instead of blue.

## Documentation

| Document | Purpose |
| --- | --- |
| [Quick Start](docs/QUICK_START.md) | First deployment in 10–15 minutes |
| [Configuration](docs/CONFIGURATION.md) | Configure services |
| [Operations](docs/OPERATIONS.md) | Deploy, inspect, and rollback |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common failures |
| [Architecture](docs/ARCHITECTURE.md) | Internal design |
| [Jenkins](docs/JENKINS.md) | CI/CD integration |
| [Contributing](docs/CONTRIBUTING.md) | Development workflow |
| [Roadmap](docs/ROADMAP.md) | Planned future work |

## Current scope

v1 focuses on Linux VM deployments. Docker, Kubernetes, Helm, and service mesh support are future roadmap items.

Zero downtime also depends on application readiness, backward-compatible changes, and safe handling of external dependencies such as databases.

## License

Licensed under the [MIT License](LICENSE).
