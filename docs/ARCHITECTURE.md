# Architecture

This document describes the planned `v1.0.0` architecture for a generic Linux VM-based zero-downtime CI/CD template. It is intentionally application-agnostic and focused on Jenkins, Docker-compatible service images, NGINX traffic switching, blue/green deployment slots, rollback, and release history tracking.

Kubernetes is future `v2.0.0` roadmap scope only and is not part of this architecture.

## Design Goals

- support many application stacks through configuration rather than application-specific scripts
- deploy one or more services to Linux VMs with the same release mechanics
- keep the currently healthy color serving traffic while candidates start on the inactive color
- promote only after service health checks and NGINX validation pass
- make rollback faster than debugging during an incident
- preserve release history for audits, incident review, and operator confidence
- keep the repository structure clear enough for contributors and recruiters to evaluate quickly

## Final Repository Tree

The complete `v1.0.0` repository should use this structure. Files marked as scripts are design targets only until implementation begins.

```text
.
├── README.md
├── CHANGELOG.md
├── LICENSE
├── .editorconfig
├── .env.example
├── .gitignore
├── Jenkinsfile
├── config/
│   ├── README.md
│   ├── environments/
│   │   ├── development.yml
│   │   ├── staging.yml
│   │   └── production.yml
│   ├── services.yml
│   └── nginx/
│       ├── nginx.conf.tpl
│       └── upstream.conf.tpl
├── docs/
│   ├── AI_AGENT_USAGE.md
│   ├── ARCHITECTURE.md
│   ├── CONFIGURATION.md
│   ├── CONTRIBUTING.md
│   ├── HEALTH_CHECK.md
│   ├── MVP.md
│   ├── OPERATIONS.md
│   ├── PRE_RELEASE_PLAN.md
│   ├── REAL_WORLD_PROBLEMS.md
│   ├── RELEASE_PLAN.md
│   ├── RELEASE_SCOPE.md
│   └── ROADMAP.md
├── examples/
│   ├── three-services/
│   │   ├── services.yml
│   │   └── production.yml
│   └── single-service/
│       ├── services.yml
│       └── staging.yml
├── scripts/
│   ├── common/
│   │   ├── colors.sh
│   │   ├── config.sh
│   │   ├── docker.sh
│   │   ├── logging.sh
│   │   ├── nginx.sh
│   │   └── state.sh
│   ├── deploy.sh
│   ├── generate-nginx.sh
│   ├── health-check.sh
│   ├── init-host.sh
│   ├── list-releases.sh
│   ├── rollback.sh
│   ├── smoke-test.sh
│   ├── switch-traffic.sh
│   └── validate-config.sh
└── tests/
    ├── fixtures/
    │   ├── services.valid.yml
    │   └── services.invalid.yml
    ├── test-config-validation.sh
    ├── test-nginx-generation.sh
    └── test-state-transitions.sh
```

The current repository may contain early scaffold files such as `demo-app/` or single-service examples. For `v1.0.0`, those should be treated as examples, not as the core deployment model.

## Configuration Format

The v1 configuration should be YAML, split between service registration and environment-specific deployment settings.

`config/services.yml` defines application-agnostic service metadata:

```yaml
version: 1
services:
  - name: api
    image: registry.example.com/company/api
    route:
      host: example.com
      path_prefix: /api
    ports:
      blue: 8101
      green: 8102
    health_check:
      path: /health
      expected_status: 200
      timeout_seconds: 3
      retries: 10
      interval_seconds: 3
    deploy:
      start_order: 10
      stop_grace_seconds: 20
      environment_file: api.env

  - name: web
    image: registry.example.com/company/web
    route:
      host: example.com
      path_prefix: /
    ports:
      blue: 8201
      green: 8202
    health_check:
      path: /healthz
      expected_status: 200
      timeout_seconds: 3
      retries: 10
      interval_seconds: 3
    deploy:
      start_order: 20
      stop_grace_seconds: 20
      environment_file: web.env
```

`config/environments/<environment>.yml` defines where and how the services run:

```yaml
environment: production
release_root: /opt/zero-downtime-cicd
state_root: /opt/zero-downtime-cicd/state
log_root: /opt/zero-downtime-cicd/logs
deployment_user: deploy
nginx:
  config_dir: /etc/nginx/conf.d
  generated_upstream_file: /etc/nginx/conf.d/zero-downtime-upstreams.conf
  reload_command: sudo systemctl reload nginx
  validate_command: sudo nginx -t
docker:
  network: zero-downtime
  registry: registry.example.com
release:
  keep_history: 20
  default_timeout_seconds: 300
```

Configuration rules:

- service names must be unique and stable
- each service must define blue and green ports
- health checks must be explicit per service
- routes must be explicit so NGINX generation is deterministic
- environment files may contain runtime values, but secrets must not be committed
- image tags should be supplied by Jenkins at release time, not hardcoded as mutable `latest`

## Service Registration Model

A service is registered by adding an entry to `config/services.yml`. The deployment engine should not require service-specific scripts for normal operation.

A registered service contains:

- `name` - stable identifier used in containers, state, logs, and release history
- `image` - repository path without assuming a specific application language
- `route` - NGINX host and path mapping
- `ports` - blue and green host ports
- `health_check` - readiness gate before promotion
- `deploy` - ordering, graceful stop behavior, and optional environment file reference

Service registration should support partial deployments. Jenkins may deploy all services for a release or a selected subset, but state must always record exactly which services were included.

## Deployment Workflow

```mermaid
flowchart TD
    A[Release Trigger in Jenkins] --> B[Load Environment Config]
    B --> C[Load Service Registry]
    C --> D[Validate Config and Inputs]
    D --> E[Resolve Image Tags]
    E --> F[Read Current State]
    F --> G[Determine Inactive Color Per Service]
    G --> H[Create Release Record]
    H --> I[Pull Images on VM]
    I --> J[Start Candidate Containers]
    J --> K[Run Service Health Checks]
    K -->|fail| L[Mark Release Failed and Keep Current Traffic]
    K -->|pass| M[Generate NGINX Upstream Config]
    M --> N[Validate NGINX Config]
    N -->|fail| L
    N -->|pass| O[Switch Traffic]
    O --> P[Post-Switch Health Checks]
    P -->|fail| Q[Rollback Traffic]
    P -->|pass| R[Mark Release Successful]
    Q --> S[Mark Release Rolled Back]
```

Deployment guarantees are intentionally scoped. The template can avoid switching traffic to unhealthy candidates, but application compatibility, database safety, and external dependency behavior remain the responsibility of the application team.

## Rollback Workflow

```mermaid
flowchart TD
    A[Rollback Trigger] --> B[Load Environment Config]
    B --> C[Read Active State]
    C --> D[Select Rollback Target]
    D --> E[Verify Previous Color Exists]
    E --> F[Generate NGINX Config for Previous Color]
    F --> G[Validate NGINX Config]
    G -->|fail| H[Stop and Preserve Current State]
    G -->|pass| I[Switch NGINX Traffic Back]
    I --> J[Run Health Checks on Restored Services]
    J -->|fail| K[Mark Rollback Failed and Escalate]
    J -->|pass| L[Record Rollback Event]
    L --> M[Keep Failed Release for Inspection]
```

Rollback should restore traffic first and clean up later. Failed candidates and logs should remain available until an operator has captured enough context for troubleshooting.

## State Management Design

Phase 2 uses per-service filesystem state under each registered service `deploy_path`. This keeps state close to the service it describes and lets operators inspect one service without parsing a global state document.

For each service:

```text
<deploy_path>/
├── releases/
├── shared/
├── state/
│   ├── active_color
│   ├── deploy.lock
│   └── history.log
└── current -> releases/<release_id>
```

Persistent state files:

- `state/active_color` stores the current active color, either `blue` or `green`.
- `state/history.log` stores append-only release history entries.
- `current` is a future symlink to the active release directory.

Transient state files:

- `state/deploy.lock` exists only while a future deployment operation holds the service lock.

Phase 2 provides the foundation only. It initializes directories and state files, reads active and inactive colors, creates and releases lock files, appends history entries, and reads the latest history entry. It does not deploy releases, modify the `current` symlink, switch NGINX traffic, or perform rollback.

State update rules:

- initialize missing state without overwriting existing state
- preserve `active_color` if it already exists
- preserve `history.log` if it already exists
- use `deploy.lock` to prevent concurrent future deployments per service
- append release history instead of rewriting it
- avoid deleting service state as part of initialization or inspection

## Phase 2 State Commands

Initialize a service state layout:

```bash
./scripts/init-service.sh billing-api
make init-service SERVICE=billing-api
```

Inspect service state:

```bash
./scripts/show-state.sh billing-api
make show-state SERVICE=billing-api
```

## NGINX Generation Strategy

NGINX configuration should be generated from `config/services.yml`, environment settings, and current or candidate color selection. Operators should not manually edit generated upstream files during normal deployment.

The strategy:

1. Render an upstream block per service using the selected color port.
2. Render route rules from each service's `host` and `path_prefix`.
3. Write generated config to a temporary file.
4. Run `nginx -t` or the configured validation command.
5. Atomically move the generated file into the configured NGINX include path.
6. Reload NGINX with the configured reload command.
7. Run post-switch health checks through the public route where possible.

Template inputs:

- service name
- route host
- route path prefix
- active or candidate color
- host port for selected color
- proxy timeout defaults
- optional service-specific headers

Generated files should include a warning comment such as `# Generated by zero-downtime-cicd-template. Do not edit directly.`

## Release Directory Structure

The target VM uses the service `deploy_path` from `config/services.yml`. Phase 2 initializes this layout for each service:

```text
<deploy_path>/
├── releases/
├── shared/
├── state/
│   ├── active_color
│   ├── deploy.lock
│   └── history.log
└── current -> releases/<release_id>
```

Directory responsibilities:

- `releases/` will hold versioned release directories in future deployment phases.
- `shared/` is reserved for service data that should survive release changes.
- `state/` contains service-local state and lock files.
- `current` is reserved for a future symlink to the active release.

Phase 2 creates `releases/`, `shared/`, `state/`, `active_color`, and `history.log`. It does not create release directories or the `current` symlink because no deployment has occurred yet.

## Example Configuration for Three Services

```yaml
version: 1
services:
  - name: api
    image: registry.example.com/acme/api
    route:
      host: app.example.com
      path_prefix: /api
    ports:
      blue: 8101
      green: 8102
    health_check:
      path: /health
      expected_status: 200
      timeout_seconds: 3
      retries: 12
      interval_seconds: 5
    deploy:
      start_order: 10
      stop_grace_seconds: 30
      environment_file: api.env

  - name: worker
    image: registry.example.com/acme/worker
    route:
      host: internal.example.com
      path_prefix: /worker-health
    ports:
      blue: 8301
      green: 8302
    health_check:
      path: /health
      expected_status: 200
      timeout_seconds: 3
      retries: 12
      interval_seconds: 5
    deploy:
      start_order: 20
      stop_grace_seconds: 45
      environment_file: worker.env

  - name: web
    image: registry.example.com/acme/web
    route:
      host: app.example.com
      path_prefix: /
    ports:
      blue: 8201
      green: 8202
    health_check:
      path: /healthz
      expected_status: 200
      timeout_seconds: 3
      retries: 10
      interval_seconds: 3
    deploy:
      start_order: 30
      stop_grace_seconds: 20
      environment_file: web.env
```

Example image tags should be supplied at deployment time:

```text
api=registry.example.com/acme/api:1.4.2
worker=registry.example.com/acme/worker:0.9.7
web=registry.example.com/acme/web:2.8.0
```

## Phase 3 Health Validation Foundation

Phase 3 introduces reusable health validation primitives for future deployments:

- `scripts/healthcheck.sh` checks any HTTP URL and succeeds only on `2xx`.
- `scripts/lib/health.sh` builds health URLs and wraps common validation behavior.
- `scripts/validate-release.sh` validates one registered service candidate port using the service `health_path`.
- `examples/mock-health-server/` provides a local shell-only endpoint for validation.

Release validation depends on Phase 1 configuration and Phase 2 service state. It verifies that a service exists, state has been initialized, and the candidate health endpoint responds successfully. It does not create releases, update state, switch NGINX traffic, run Jenkins, or roll back.

Future deployment phases should call release validation after starting the inactive color and before promotion.

## Required v1.0.0 Scripts

These scripts are required for `v1.0.0`, but this document does not implement them.

| Script | Responsibility |
| --- | --- |
| `scripts/init-host.sh` | Create target VM directories, validate required tools, and prepare Docker network assumptions. |
| `scripts/validate-config.sh` | Validate service and environment YAML before deployment. |
| `scripts/deploy.sh` | Orchestrate candidate deployment for one or more services. |
| `scripts/health-check.sh` | Run HTTP health checks with timeout and retry behavior. |
| `scripts/generate-nginx.sh` | Render NGINX config from service registration and selected colors. |
| `scripts/switch-traffic.sh` | Validate, install, and reload generated NGINX config. |
| `scripts/rollback.sh` | Restore traffic to the previous healthy color and record rollback state. |
| `scripts/list-releases.sh` | Show active release, previous release, and history records. |
| `scripts/smoke-test.sh` | Run optional post-switch checks against public routes. |
| `scripts/common/config.sh` | Load and normalize configuration values. |
| `scripts/common/colors.sh` | Resolve active and inactive colors per service. |
| `scripts/common/docker.sh` | Wrap Docker operations used by deployment scripts. |
| `scripts/common/nginx.sh` | Wrap NGINX validation, file installation, and reload behavior. |
| `scripts/common/state.sh` | Read, lock, write, and validate release state. |
| `scripts/common/logging.sh` | Provide consistent logs for Jenkins and operators. |

## Jenkins Integration

`Jenkinsfile` should call the scripts rather than embedding deployment logic directly. The planned stages are:

1. checkout
2. validate configuration
3. resolve service image tags
4. initialize or verify target host
5. deploy inactive color
6. run candidate health checks
7. generate and validate NGINX config
8. switch traffic
9. run post-switch verification
10. record release result
11. expose rollback action

Jenkins should capture release metadata including build URL, Git commit, target environment, service list, image tags, operator, and result.

## Future Architecture

The future `v2.0.0` roadmap targets Kubernetes, Helm, rolling and blue/green strategies, and a cloud-native deployment workflow. Those concepts should not be implemented in the v1 VM architecture.
