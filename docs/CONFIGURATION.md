# Configuration

This document describes the initial configuration model for the blue/green deployment workflow.

The current configuration is intentionally small. It establishes the values future deployment engine components will read, but it does not implement deployment, rollback, or traffic switching behavior.

## Deployment State

Deployment state is represented by the `ACTIVE_ENV` value in `config/app.env.example`.

`ACTIVE_ENV` identifies which color is currently expected to receive traffic. The supported values are:

- `blue`
- `green`

The idle environment is the opposite color. If blue is active, green is idle. If green is active, blue is idle.

## Future Script Usage

Future deployment scripts will use `ACTIVE_ENV` to decide which environment should receive the next candidate release.

For example, when `ACTIVE_ENV=blue`, the deployment engine can treat green as idle, deploy the new application version there, validate it, and only then promote green. After a successful promotion, the recorded active environment can change to `green`.

## Separate Ports

The blue and green environments use separate host ports so both versions can run at the same time on a single server.

This separation allows the idle environment to be started and tested without interrupting the active environment. It also gives NGINX a clear target when traffic switching is added later.

## Health Checks

Health checks are required before promotion because a running container is not enough evidence that the application is ready to serve traffic.

Future deployment scripts should call the configured `HEALTH_ENDPOINT` on the idle environment and promote that environment only after the health check succeeds.
