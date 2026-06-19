# Zero-Downtime CI/CD Template

A practical, open-source CI/CD template for deploying containerized applications to Linux virtual machines with blue/green releases, NGINX traffic switching, health checks, rollback, and Jenkins pipeline orchestration.

## Current Status

This repository is in documentation and release-scope planning stage. The public target for `v1.0.0` is a stable VM-based zero-downtime deployment template. Scripts and pipeline implementation are intentionally not present yet.

Kubernetes is not part of the current implementation. Kubernetes, Helm, and cloud-native deployment workflows are planned for a future `v2.0.0` direction only.

## Who This Is For

This project is intended for:

- DevOps and platform engineers standardizing safer VM deployments
- teams moving away from manual SSH-based production releases
- small and mid-sized engineering teams running services on Linux VMs
- organizations that need release discipline before adopting Kubernetes
- recruiters and reviewers evaluating practical CI/CD, release, and operations design

## What v1.0.0 Will Support

The `v1.0.0` scope is a stable Linux VM deployment template with:

- generic Linux VM deployment model
- Jenkins pipeline integration
- Docker-based application packaging and runtime assumptions
- multi-service blue/green deployment support
- NGINX upstream traffic switching
- HTTP health-check gates before promotion
- rollback to the last known healthy release
- release directory structure and release state tracking
- environment-specific configuration guidance
- operator documentation for setup, deployment, rollback, and troubleshooting

See [docs/RELEASE_SCOPE.md](docs/RELEASE_SCOPE.md) for the authoritative release boundary.

## What v1.0.0 Will Not Support

The `v1.0.0` VM template will not include:

- Kubernetes manifests, Helm charts, operators, or controllers
- service mesh integration
- cloud-provider-specific infrastructure provisioning
- autoscaling orchestration
- multi-region or multi-cluster deployment
- database migration automation
- a hosted CI/CD product
- a full observability platform
- claims that every workload can achieve zero downtime without application-level readiness work

## Architecture Overview

The v1 architecture uses Jenkins as the release orchestrator, Docker as the packaging/runtime layer, NGINX as the traffic boundary, and blue/green deployment slots on one or more Linux VMs. A candidate release is deployed to the inactive slot, validated through health checks, and promoted only after passing the configured gate.

```mermaid
flowchart LR
    A[Source Repository] --> B[Jenkins Pipeline]
    B --> C[Build or Pull Tagged Image]
    C --> D[Deploy Inactive Blue/Green Slot]
    D --> E[Run Health Checks]
    E -->|Pass| F[Switch NGINX Upstream]
    E -->|Fail| G[Keep Current Active Slot]
    F --> H[Record Release State]
    H --> I[Rollback Available]
```

For a deeper design view, read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Repository Structure

```text
.
├── docs/
│   ├── AI_AGENT_USAGE.md
│   ├── ARCHITECTURE.md
│   ├── CONTRIBUTING.md
│   ├── MVP.md
│   ├── OPERATIONS.md
│   ├── PRE_RELEASE_PLAN.md
│   ├── REAL_WORLD_PROBLEMS.md
│   ├── RELEASE_PLAN.md
│   ├── RELEASE_SCOPE.md
│   └── ROADMAP.md
├── .editorconfig
├── .env.example
├── .gitignore
├── CHANGELOG.md
├── LICENSE
└── README.md
```

## Quick Start Plan

Implementation has not started yet. The intended path for contributors and reviewers is:

1. Read [docs/RELEASE_SCOPE.md](docs/RELEASE_SCOPE.md) to understand what belongs in `v1.0.0`.
2. Review [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the VM-based deployment model.
3. Use [docs/OPERATIONS.md](docs/OPERATIONS.md) as the operational checklist for future scripts and pipeline stages.
4. Follow [docs/ROADMAP.md](docs/ROADMAP.md) when proposing features so Kubernetes work stays in future `v2.0.0` scope.
5. Keep documentation aligned with implementation as scripts, Jenkinsfiles, and examples are added.

## Release Roadmap

- `v0.x` - planning, scaffolding, and validated increments toward the VM template
- `v1.0.0` - stable Linux VM zero-downtime CI/CD template
- `v1.x` - hardening, examples, compatibility improvements, and operational polish
- `v2.0.0` - Kubernetes-native roadmap target using Kubernetes, Helm, and cloud-native deployment workflows

See [docs/ROADMAP.md](docs/ROADMAP.md) for the full public roadmap.

## Contribution Note

Contributions should preserve the safety-first purpose of the repository. Deployment logic, scripts, Jenkins stages, NGINX switching, rollback behavior, and documentation must be reviewed for operational risk before merge.

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md).

## Disclaimer

This repository is not production-ready yet. It defines the roadmap and release scope for a future stable VM-based zero-downtime CI/CD template. Any deployment logic added later must be tested in controlled environments before production use.
