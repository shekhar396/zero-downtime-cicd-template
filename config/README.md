# Blue/Green Configuration

This directory contains example configuration for the blue/green deployment flow planned for this template.

The configuration describes the two application environments, the currently active environment, and the health endpoint that future deployment scripts will use before promoting a release.

## Blue Environment

The blue environment is one of two long-lived deployment targets. In the example configuration, it uses the `demo-blue` container name and host port `8001`.

When `ACTIVE_ENV=blue`, blue is the environment expected to receive traffic and green is treated as idle.

## Green Environment

The green environment is the second deployment target. In the example configuration, it uses the `demo-green` container name and host port `8002`.

When `ACTIVE_ENV=green`, green is the environment expected to receive traffic and blue is treated as idle.

## Active And Idle Environments

The active environment is the color currently serving traffic. The idle environment is the opposite color and is the place where a future deployment engine can start and validate a candidate release.

Keeping these roles explicit allows deployment logic to decide where to deploy next without guessing from container names or ports.

## Container Names

`BLUE_CONTAINER` and `GREEN_CONTAINER` define the Docker container names assigned to each color.

These names give future scripts stable targets for container inspection, replacement, health validation, and cleanup.

## Port Assignments

`BLUE_PORT` and `GREEN_PORT` define separate host ports for each color.

Separate ports allow both environments to run at the same time so the idle environment can be validated before traffic is switched.

## Health Endpoint

`HEALTH_ENDPOINT` defines the HTTP path used to check whether a candidate environment is healthy.

Future deployment scripts should verify this endpoint on the idle environment before promoting it to active traffic.
