# Configuration

This document describes the Phase 1 configuration foundation for the planned `v1.0.0` Linux VM deployment template. It does not define deployment, rollback, NGINX generation, or Jenkins pipeline logic.

## Configuration Structure

```text
config/
├── services.yml
├── environments/
│   ├── staging.yml
│   └── production.yml
└── examples/
    └── services.example.yml
```

`config/services.yml` is the default service registry used by validation and future deployment phases.

`config/environments/*.yml` contains VM-oriented environment settings such as release roots, state roots, log roots, deployment user, Docker network name, and release history retention.

`config/examples/services.example.yml` shows the same service registration format in a safe example location.

## Service Configuration Format

Each service is registered as a flat YAML object under `services`:

```yaml
services:
  - service_name: billing-api
    runtime: container
    public_port: 8080
    blue_port: 18080
    green_port: 18081
    health_path: /health
    deploy_path: /opt/zero-downtime-cicd/releases/billing-api
    nginx_server_name: billing.example.com
```

Required fields:

- `service_name` - stable service identifier used by scripts and future release state
- `runtime` - runtime category, currently `container` in the examples
- `public_port` - externally exposed service port for the VM-level contract
- `blue_port` - host port reserved for the blue deployment slot
- `green_port` - host port reserved for the green deployment slot
- `health_path` - HTTP path future health checks will call before promotion
- `deploy_path` - absolute path where service release data will live on the VM
- `nginx_server_name` - server name future NGINX configuration will target

## Environment Override Strategy

Environment files are intentionally separate from service registration:

```yaml
environment: staging
release_root: /opt/zero-downtime-cicd
state_root: /opt/zero-downtime-cicd/state
log_root: /opt/zero-downtime-cicd/logs
deployment_user: deploy
docker_network: zero-downtime-staging
release_history_limit: 20
```

The intended strategy is:

- keep service identity and ports in `config/services.yml`
- keep VM paths, state paths, deployment user, and environment-level settings in `config/environments/*.yml`
- keep secrets out of this repository
- keep active blue/green state out of static config; future phases should write state files instead

## Service Discovery Utility

`scripts/lib/service-discovery.sh` provides shell functions and a small CLI for future scripts.

List registered services:

```bash
./scripts/lib/service-discovery.sh list
```

Retrieve one service definition:

```bash
./scripts/lib/service-discovery.sh get billing-api
```

Validate required fields only:

```bash
./scripts/lib/service-discovery.sh validate
```

Use a non-default service file:

```bash
./scripts/lib/service-discovery.sh list config/examples/services.example.yml
```

## Validation Process

Run validation with Make:

```bash
make validate-config
```

Run validation directly:

```bash
./scripts/validate-config.sh
```

Validate an example file:

```bash
./scripts/validate-config.sh config/examples/services.example.yml
```

The validator checks:

- all required fields are present
- service names are unique
- ports are unique across `public_port`, `blue_port`, and `green_port`
- `blue_port` and `green_port` differ for each service
- `health_path` begins with `/`
- `deploy_path` is absolute

## Example Services

The default `config/services.yml` registers three realistic services:

- `billing-api`
- `photo-api`
- `drive-api`

These examples are Linux VM focused and intentionally stop at configuration. They do not deploy containers, switch traffic, generate NGINX files, call Jenkins, or perform rollback.
