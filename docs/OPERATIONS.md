# Operations

This document describes the operational expectations for the planned `v1.0.0` VM-based template. It is a runbook outline for future implementation, not a command reference yet.

## Operator Responsibilities

Operators are responsible for:

- provisioning and securing Linux VMs
- installing and maintaining Docker and NGINX
- configuring Jenkins credentials and deployment access
- defining service configuration and health-check paths
- validating releases in staging before production
- reviewing rollback risk before deployment
- keeping secrets out of the repository

## Pre-Deployment Checklist

Before a release, confirm:

- target environment is correct
- image tag is immutable and approved
- service configuration is present
- health-check endpoint is known
- NGINX configuration path is correct
- current active color and version are known
- rollback target exists
- release owner and approver are identified
- application changes are backward compatible where required

## Deployment Flow

The planned deployment flow is:

1. Jenkins receives a release trigger.
2. Jenkins validates inputs and target environment.
3. Jenkins builds or pulls the tagged image.
4. The inactive blue/green slot is prepared.
5. Candidate containers start on the inactive slot.
6. Health checks run against the candidate.
7. NGINX switches traffic only after validation succeeds.
8. Post-switch verification confirms the active service is healthy.
9. Release state records version, color, status, and timestamp.

## Rollback Flow

Rollback should restore the last known healthy release before deeper debugging.

Expected rollback steps:

1. Read release state.
2. Identify the previous healthy color and version.
3. Switch NGINX traffic back to that color.
4. Run health checks against the restored service.
5. Record the rollback event.
6. Preserve logs and deployment metadata for review.

## Health-Check Expectations

Each service should define:

- health-check path
- expected HTTP status code
- timeout
- retry count
- startup grace period
- post-switch verification behavior

A failed candidate health check must prevent promotion.

## Multi-Service Operations

For multi-service deployments, operators should document:

- service ownership
- deployment order
- dependency assumptions
- health-check requirements per service
- rollback behavior per service
- compatibility constraints between versions

When services share databases or APIs, rollback may require application-level compatibility planning. The deployment template should make this risk visible but cannot solve incompatible application changes by itself.

## Incident Handling

During a deployment incident:

- stop further promotion
- restore traffic to the last known healthy color when possible
- preserve Jenkins logs, NGINX logs, container logs, and release state
- identify whether failure occurred before or after traffic switch
- document the user impact and corrective action
- update runbooks if the failure mode was not covered

## Secrets and Access

Secrets must be supplied through the operator's approved secret-management process. The repository should only contain placeholders and documentation.

Deployment access should follow least privilege. Jenkins should have only the permissions required to deploy, validate, switch traffic, and roll back.

## Production Readiness Notes

The template can reduce deployment risk, but operators still need:

- application readiness endpoints
- backward-compatible releases
- tested rollback assumptions
- monitoring outside the deployment pipeline
- reviewed production access controls
- environment-specific validation
