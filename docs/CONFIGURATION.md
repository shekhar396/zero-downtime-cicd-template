# Configuration

This document describes the configuration foundation for the `v1.0.0` Linux VM deployment template. Configuration is consumed by validation, state, release, runtime, NGINX or Apache proxy, rollback, deploy, and Jenkins workflows.

## Configuration Structure

```text
config/
├── services.yml
├── environments/
│   ├── staging.yml
│   └── production.yml
└── examples/
    ├── services.example.yml
    └── services.systemd.example.yml
```

`config/services.yml` is the default service registry used by validation and deployment scripts.

`config/environments/*.yml` contains VM-oriented environment settings such as release roots, state roots, log roots, deployment user, optional Docker network name, and release history retention.

`config/examples/services.example.yml` shows the container/demo service registration format. `config/examples/services.systemd.example.yml` shows the no-Docker systemd format.

## Service Configuration Format

Each service is registered as a flat YAML object under `services`:

```yaml
services:
  - service_name: billing-api
    runtime: container
    proxy_runtime: nginx
    public_port: 8080
    blue_port: 18080
    green_port: 18081
    health_path: /health
    deploy_path: /tmp/zero-downtime-cicd/services/billing-api
    nginx_server_name: billing.example.com
```

Required fields:

- `service_name` - stable service identifier used by scripts and release state
- `runtime` - process runtime category, either `systemd` or `container`
- `proxy_runtime` - traffic proxy category, either `nginx` or `apache`; defaults to `nginx` when omitted
- `public_port` - externally exposed proxy port; Apache uses this as the VirtualHost listen port
- `blue_port` - host port reserved for the blue application deployment slot
- `green_port` - host port reserved for the green application deployment slot
- `health_path` - HTTP path health checks call before promotion
- `deploy_path` - absolute path where service release data will live on the VM
- `nginx_server_name` - server name generated NGINX or Apache configuration will target; `_` maps to `localhost` in Apache templates



## Proxy Runtime Fields

`proxy_runtime` controls which reverse proxy config is generated and switched for a service. It is optional and defaults to `nginx` for backward compatibility.

Supported values:

- `proxy_runtime: nginx`
- `proxy_runtime: apache`

Use `proxy_runtime: apache` when Apache HTTPD owns the service public port on the VM. Apache reverse proxy mode generates a VirtualHost listening on the configured `public_port`, for example `<VirtualHost *:{{public_port}}>`, and proxies traffic to the active blue/green application port.

Apache mode requires these modules on the target VM:

- `proxy`
- `proxy_http`
- `headers`

Safe local Apache paths:

```text
build/apache
build/apache-installed
```

Production Apache install path can be set with `APACHE_CONFIG_DIR`, for example `/etc/apache2/sites-available`. Apache installs can use `APACHE_INSTALL_CMD`, defaulting to `cp`; Jenkins can use `APACHE_INSTALL_CMD="sudo -n cp"`. Optional site enable can use `APACHE_ENABLE_CMD`, for example `APACHE_ENABLE_CMD="sudo -n a2ensite pico-photos-api.conf"`. Reload can be overridden with `APACHE_RELOAD_CMD`, for example `APACHE_RELOAD_CMD="sudo -n systemctl reload apache2"`.

## Systemd Runtime Fields

Use `runtime: systemd` for live Linux VM deployments where Docker is unavailable or not desired. Systemd services should be split by color, for example:

```text
billing-api-blue
billing-api-green
```

Example:

```yaml
services:
  - service_name: billing-api
    runtime: systemd
    public_port: 8080
    blue_port: 8860
    green_port: 8861
    health_path: /api/v1/health
    deploy_path: /opt/apps/billing-api
    nginx_server_name: _
    retention_count: 5
    start_command: sudo systemctl start billing-api-{color}
    stop_command: sudo systemctl stop billing-api-{color}
    status_command: sudo systemctl is-active billing-api-{color}
    working_directory: /opt/apps/billing-api/current/artifact
    env_file: /opt/apps/billing-api/shared/.env
```

For `runtime: systemd`, these fields are required:

- `start_command`
- `stop_command`
- `status_command`

These fields are optional but supported:

- `working_directory`
- `env_file`

Runtime commands may use placeholders:

- `{color}` - `blue` or `green`
- `{release_id}` - release being started, when available
- `{port}` - configured blue or green port
- `{release_dir}` - release directory path
- `{deploy_path}` - service deploy path
- `{service_name}` - service name

The runtime helper also exports `ZERO_DOWNTIME_SERVICE_NAME`, `ZERO_DOWNTIME_COLOR`, `ZERO_DOWNTIME_RELEASE_ID`, `ZERO_DOWNTIME_PORT`, `ZERO_DOWNTIME_RELEASE_DIR`, `ZERO_DOWNTIME_DEPLOY_PATH`, `ZERO_DOWNTIME_WORKING_DIRECTORY`, and `ZERO_DOWNTIME_ENV_FILE` before running a systemd command.

`PORT` should be injected per color through the systemd unit, a drop-in, or the configured environment file. This template does not rewrite systemd unit files.

A commented `pico-photos-api` placeholder is included in `config/examples/services.systemd.example.yml` for the first production validation target. Its real ports and health path are intentionally marked `TBD` until known.

## Container Runtime Fields

Use `runtime: container` for Docker-backed VM deployments or the built-in demo artifact flow. Container support remains available, but it is optional for no-Docker servers.

## Local Sample Paths

The sample service registry uses `/tmp/zero-downtime-cicd/services` so validation and state initialization can run without root privileges on a development machine. Operators can change `deploy_path` to an approved VM path such as `/opt/apps/<service-name>` when preparing a real host.

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
- keep active blue/green state out of static config; deployment scripts write state files instead

## Service Discovery Utility

`scripts/lib/service-discovery.sh` provides shell functions and a small CLI for repository scripts.

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
- runtime is either `systemd` or `container`
- proxy runtime is either `nginx` or `apache` when set
- systemd services define `start_command`, `stop_command`, and `status_command`
- service names are unique
- ports are numeric, in the range `1` to `65535`, and unique across `public_port`, `blue_port`, and `green_port`
- `blue_port` and `green_port` differ for each service
- `health_path` begins with `/`
- `deploy_path` is absolute

## Example Services

The default `config/services.yml` registers three realistic services:

- `billing-api`
- `photo-api`
- `drive-api`

These examples are Linux VM focused. Container examples are safe local defaults; the systemd example is intended for no-Docker VM deployments after service ports, health paths, and units are confirmed.
