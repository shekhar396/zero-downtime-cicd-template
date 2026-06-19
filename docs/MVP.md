# MVP Definition

This document now describes the earliest implementation milestone on the path to `v1.0.0`. It is not the final public release scope. The authoritative stable release boundary is [RELEASE_SCOPE.md](RELEASE_SCOPE.md).

## Objective

The first MVP should prove the core VM-based deployment loop for one service before the template expands to the full `v1.0.0` multi-service scope.

The MVP should remain practical, inspectable, and conservative. It should validate the basic blue/green release pattern on a Linux VM using Jenkins, Docker, NGINX, health checks, release state, and rollback.

## MVP Goals

- Build or pull a tagged Docker image from a Jenkins pipeline.
- Deploy the new application version to the inactive blue/green slot.
- Validate the candidate release through an HTTP health check.
- Switch NGINX traffic only after validation succeeds.
- Preserve the previously active release for rollback.
- Record enough release state to identify active and previous versions.
- Separate development, staging, and production configuration expectations.
- Document operator responsibilities before recommending production use.

## Planned Deployment Model

The MVP is scoped to a single service on a Linux VM running Docker containers behind NGINX. One color receives live traffic while the other color is used for candidate deployment and validation.

```text
Client traffic
    |
  NGINX
    |
active color: blue or green
    |
Docker container for current application release
```

## MVP Boundaries

The MVP should include:

- Jenkins stages for checkout, build or pull, deploy, health check, traffic switch, and rollback.
- Docker image tagging conventions that avoid mutable release ambiguity.
- Blue/green container naming and lifecycle conventions.
- NGINX upstream switching strategy.
- Health-check validation before traffic promotion.
- Rollback mechanism when candidate validation fails or post-switch verification fails.
- Environment-specific configuration examples.
- Documentation for release operators and contributors.

## Path From MVP to v1.0.0

The MVP proves the single-service release loop. `v1.0.0` must extend that foundation with multi-service support, stronger release state, clearer operational docs, and validated rollback behavior for the documented VM scope.

## Success Criteria

The MVP is successful when a maintainer can:

- understand the deployment architecture without reading implementation code first
- configure a sample containerized application for the template
- run a controlled staging deployment with no intentional traffic interruption
- observe a failed health check preventing promotion
- trigger or verify rollback to the previous active color
- identify what still belongs before `v1.0.0`

## Excluded From MVP

The MVP does not include:

- multi-service release coordination
- Kubernetes, Helm, Nomad, or Swarm orchestration
- multi-node or multi-region deployment
- canary percentage routing
- full observability stack installation
- database migration automation
- secret-management platform integration
- autoscaling
- service mesh support
- production-ready guarantee
