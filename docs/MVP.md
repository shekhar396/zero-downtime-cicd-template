# MVP Definition

## Objective

The MVP will provide a practical single-server zero-downtime deployment template for containerized applications. It will focus on a conservative deployment flow that can be inspected, tested, and adapted before being used in real production environments.

## MVP Goals

- Build and tag Docker images from a Jenkins pipeline.
- Deploy the new application version to the inactive blue/green slot.
- Validate the candidate release through an HTTP health check.
- Switch NGINX traffic only after validation succeeds.
- Preserve the previously active release for rollback.
- Separate development, staging, and production configuration expectations.
- Provide deployment scripts with clear ownership boundaries.
- Document release and pre-release requirements before implementation is promoted.

## Planned Deployment Model

The MVP is scoped to one host running Docker containers behind NGINX. One color receives live traffic while the other color is used for candidate deployment and validation.

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

- Jenkins pipeline stages for checkout, build, tag, deploy, health check, traffic switch, and rollback.
- Docker image tagging conventions that avoid mutable release ambiguity.
- Blue/green container naming and lifecycle conventions.
- NGINX upstream switching strategy.
- Health-check validation before traffic promotion.
- Rollback mechanism when candidate validation fails or post-switch verification fails.
- Environment-specific configuration examples for development, staging, and production.
- Documentation for release operators and contributors.

## Success Criteria

The MVP is successful when a maintainer can:

- understand the deployment architecture without reading implementation code first
- configure a sample containerized application for the template
- run a controlled staging deployment with no intentional traffic interruption
- observe a failed health check preventing promotion
- trigger or verify rollback to the previous active color
- identify what is safe for production use and what still requires validation
- review release notes and pre-release criteria before a stable tag is created

## Excluded From MVP

The MVP does not include:

- Kubernetes, Helm, Nomad, or Swarm orchestration
- multi-node or multi-region deployment
- canary percentage routing
- full observability stack installation
- database migration automation
- secret-management platform integration
- autoscaling
- service mesh support
- production-ready guarantee

