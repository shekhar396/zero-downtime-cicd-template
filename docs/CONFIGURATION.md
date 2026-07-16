# Configuration

Services are registered in `config/services.yml`. The parser supports a flat YAML list; keep each service definition to simple `key: value` fields.

## Official example

```yaml
services:
  - service_name: zero-downtime-demo-go
    runtime: systemd
    proxy_runtime: apache
    public_port: 8080
    blue_port: 18080
    green_port: 18081
    health_path: /health
    deploy_path: /var/www/zero-downtime-demo-go
    apache_server_name: localhost
    nginx_server_name: _
    retention_count: 5
    start_command: sudo -n systemctl restart zero-downtime-demo-go-{color}
    stop_command: sudo -n systemctl stop zero-downtime-demo-go-{color}
    status_command: sudo -n systemctl is-active zero-downtime-demo-go-{color}
    env_file: /var/www/zero-downtime-demo-go/shared/.env
```

`config/services.yml` is the source of truth. Validate changes before onboarding or deployment:

```bash
./scripts/validate-config.sh
```

## Fields

| Field | Description |
| --- | --- |
| `service_name` | Unique service identifier. It also prefixes generated systemd unit and proxy file names. |
| `runtime` | Application process manager. The documented v1 VM flow uses `systemd`. |
| `proxy_runtime` | Proxy implementation: `apache` or `nginx`. If omitted, the scripts default to `nginx`. |
| `public_port` | Client-facing port where the proxy listens. It must differ from all application ports. |
| `blue_port` | Port assigned to the blue application instance. |
| `green_port` | Port assigned to the green application instance. |
| `health_path` | HTTP path checked on the candidate color before traffic switches. It must start with `/`. |
| `deploy_path` | Absolute service root containing releases, shared files, logs, state, and `current`. |
| `apache_server_name` | Apache virtual-host name. Use `localhost` for the local demo. |
| `nginx_server_name` | NGINX `server_name`; `_` is a generic catch-all value. This field is currently required by validation. |
| `retention_count` | Number of release directories retained. It must be a positive integer. |
| `start_command` | Command used to start or restart a color. `{color}` is replaced with `blue` or `green`. |
| `stop_command` | Command used to stop a color. It supports the same placeholders as `start_command`. |
| `status_command` | Command whose exit status reports whether a color is active. |
| `env_file` | Shared runtime environment file read by both generated systemd units. |

Optional systemd fields include `working_directory`, `executable`, `user`, and `group`. When `working_directory` is omitted it defaults to `<deploy_path>/current/artifact`. When `executable` is omitted, the unit runs the first executable file at the artifact root.

Commands may also use `{service_name}`, `{release_id}`, `{port}`, `{release_dir}`, and `{deploy_path}` placeholders.

## Port roles

```text
client -> public_port (Apache or NGINX) -> blue_port or green_port (application)
```

- `public_port` is the proxy-facing, client-accessible port.
- `blue_port` is the blue application instance port.
- `green_port` is the green application instance port.

All configured ports must be unique across the service registry.

## Shared environment file

Onboarding creates the shared environment file from `config/app.env.example` only when it does not already exist:

```env
APP_NAME=zero-downtime-demo-go
APP_ENV=production
RELEASE_ID=local
```

Keep only values shared by both colors in this file. Never commit real secrets; place server runtime values directly on the target VM.

Do not put these color-specific values in the shared file:

```env
PORT=18080
ACTIVE_COLOR=blue
```

Generated systemd units inject the correct `PORT` and `ACTIVE_COLOR` for each color and derive `RELEASE_ID` from the selected release at start-up. Shared `PORT` or `ACTIVE_COLOR` values would override the intended separation or make both instances bind the same port.

## Apache and NGINX

Set `proxy_runtime` to match the installed proxy. `onboard.sh` manages Apache automatically for the included configuration. NGINX users can generate and inspect configuration with:

```bash
./scripts/generate-nginx.sh --service zero-downtime-demo-go --output build/nginx
```

Apache configuration can be generated without installing it:

```bash
./scripts/generate-apache.sh --service zero-downtime-demo-go --output build/apache
```

See [Operations](OPERATIONS.md) for inspection commands and [Troubleshooting](TROUBLESHOOTING.md) for managed-file conflicts.
