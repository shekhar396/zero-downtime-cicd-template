# Service Onboarding Guide

This guide takes a new Ubuntu server from a repository clone to one verified, systemd-based blue/green deployment. Replace every value in angle brackets before running a command.

## 1. Overview

Onboarding registers a service and prepares the host so later deployments are repeatable:

```text
Clone template
  ↓
Register service in services.yml
  ↓
Validate configuration
  ↓
Prepare deployment path and permissions
  ↓
Initialize service directories and state
  ↓
Generate/install blue and green systemd units
  ↓
Prepare shared files such as .env
  ↓
Configure reverse proxy
  ↓
Perform first deployment
  ↓
Verify health, service status, and traffic
```

`config/services.yml` is the source of truth and may register multiple services. `init-service.sh` only prepares directories, state, and optionally systemd units; it does not deploy code or switch traffic. `--install-systemd` enables both units but deliberately does not start them. The first real deployment is performed by `onboard.sh` or `deploy.sh`.

## 2. Prerequisites

The live workflow requires Linux, Bash, Git, curl, a running systemd, `sudo`, and either Apache HTTPD or NGINX. Install the runtime needed to build and run your service (for example Go, Java, Node.js, or Python). You also need the service source or a built file/directory, and an unauthenticated HTTP health endpoint that returns a 2xx response. Jenkins is optional.

Check the base host:

```bash
bash --version
git --version
curl --version
systemctl --version
test -d /run/systemd/system && echo "systemd is running"
sudo -v
```

Install either proxy according to `proxy_runtime`. On Ubuntu, the usual packages are `apache2` or `nginx`. The end-to-end `onboard.sh` command requires passwordless `sudo` (`sudo -n true`) for privileged work. Run builds and the repository as a normal user, not root. Jenkins also requires narrowly scoped passwordless sudo for its privileged operations.

## 3. Clone the repository

```bash
git clone https://github.com/shekhar396/zero-downtime-cicd-template.git
cd zero-downtime-cicd-template
```

The scripts are committed executable. If a transfer has removed those mode bits, restore them with `chmod +x scripts/*.sh`.

## 4. Understand the main files

- `config/services.yml`: registered services and their runtime/proxy settings.
- `scripts/init-service.sh`: directory/state initialization and systemd generation/installation.
- `scripts/onboard.sh`: host checks, build, runtime/proxy preparation, deployment, and verification.
- `scripts/deploy.sh`: release creation, inactive-color startup, health gate, and traffic switch.
- `scripts/rollback.sh`: switch an earlier retained release onto the inactive color.
- `scripts/show-state.sh`: active/inactive color, current release, history, and lock inspection.
- `build/systemd/`: default output for generated units (created on demand).
- `apache/templates/` and `nginx/templates/`: generated proxy configuration templates.
- `docs/`: reference and operational documentation.

## 5. Register a new service

Back up and edit `config/services.yml`. The schema is a YAML list under `services`, not a map keyed by service name:

```yaml
services:
  - service_name: my-app
    runtime: systemd
    proxy_runtime: apache
    public_port: 8080
    blue_port: 18080
    green_port: 18081
    health_path: /health
    deploy_path: /var/www/my-app
    nginx_server_name: _
    retention_count: 5
    start_command: sudo systemctl start my-app-{color}
    stop_command: sudo systemctl stop my-app-{color}
    status_command: sudo systemctl is-active my-app-{color}
    working_directory: /var/www/my-app/current/artifact
    env_file: /var/www/my-app/shared/.env
    executable: bin/my-app
    user: my-app
    group: my-app
```

Field meanings:

- `service_name` is the unique CLI name and systemd unit prefix.
- `runtime` is `systemd` here (`container` is also implemented).
- `proxy_runtime` is `apache` or `nginx`; if omitted it defaults to `nginx`.
- `public_port` is the proxy listener; `blue_port` and `green_port` are distinct local application ports. All registered ports must be unique.
- `health_path` starts with `/` and must return 2xx when the service is ready.
- `deploy_path` is an absolute directory containing releases, shared data, and state.
- `nginx_server_name` is required by the schema. Apache uses it as a fallback ServerName (`_` becomes `localhost`); optional `apache_server_name` may override it.
- `retention_count` is a positive release count (default 5); values over 10 produce a warning.
- `start_command`, `stop_command`, and `status_command` are required for systemd and support `{color}`, `{release_id}`, `{port}`, `{release_dir}`, `{deploy_path}`, and `{service_name}` placeholders.
- `working_directory` defaults to `<deploy-path>/current/artifact` if omitted.
- `env_file` is loaded optionally by the generated unit (`EnvironmentFile=-...`).
- `executable` is an absolute path or a path below the release's `artifact/` directory. If omitted, the unit selects the first executable top-level file in that directory.
- `user` and `group` become systemd `User=` and `Group=`. Create them first and ensure they can read/execute releases and write anything the service needs.

For the example service account:

```bash
sudo useradd --system --home /var/www/my-app --shell /usr/sbin/nologin my-app
```

Add further list items for multiple services:

```yaml
services:
  - service_name: app-one
    # ...all required fields...
  - service_name: app-two
    # ...all required fields...
```

See [Configuration](CONFIGURATION.md) and `config/examples/services.systemd.example.yml` for more examples.

## 6. Prepare the deployment directory and permissions

Initialization and deployment must be able to write the deploy path. For a normal operator using `/var/www`:

```bash
sudo mkdir -p /var/www/my-app
sudo chown -R "$USER":"$USER" /var/www/my-app
sudo chmod 755 /var/www/my-app
```

The owner should match the user performing initialization/deployment or your server's operational design. If the unit runs as `my-app`, grant that account read and execute access to releases and only the write access the application requires. Do not run the repository as root merely to avoid permission errors; use `sudo` only for directory creation, systemd installation, and proxy operations.

## 7. Validate configuration

```bash
./scripts/validate-config.sh
```

A successful run ends with output like:

```text
[validate-config] Configuration is valid: .../config/services.yml
[validate-config] Registered services:
  - my-app
```

Stop onboarding and correct every error before continuing.

## 8. Initialize one service

Each command displays a plan and prompts `Continue? [Y/n]` unless `--yes` is used.

### Directory and state initialization only

```bash
./scripts/init-service.sh my-app
```

This ensures `<deploy-path>/releases`, `shared`, and `state`; initializes `state/active_color` to `blue` only when absent; and creates an empty `state/history.log` only when absent. Reruns preserve existing state and are idempotent.

### Generate systemd units only

```bash
./scripts/init-service.sh my-app --generate-systemd
ls -l build/systemd/my-app-*.service
systemd-analyze verify build/systemd/my-app-blue.service build/systemd/my-app-green.service
```

Generation writes to `build/systemd` by default. `--systemd-output <dir>` changes that location. It does not install or enable units, reload systemd, or start a process.

### Install systemd units

```bash
./scripts/init-service.sh my-app --install-systemd
```

This generates both units, creates absolute-target symlinks under `/etc/systemd/system`, runs `systemctl daemon-reload`, and enables them. It does not start them.

```bash
systemctl cat my-app-blue.service
systemctl cat my-app-green.service
systemctl is-enabled my-app-blue.service
systemctl is-enabled my-app-green.service
systemctl is-active my-app-blue.service || true
systemctl is-active my-app-green.service || true
```

Before the first deployment, expect `enabled`, `enabled`, `inactive`, `inactive`.

## 9. Interactive and multi-service initialization

```bash
./scripts/init-service.sh
./scripts/init-service.sh --all
./scripts/init-service.sh --all --generate-systemd
./scripts/init-service.sh --all --install-systemd
./scripts/init-service.sh --all --install-systemd --yes
echo "exit_code=$?"
```

With no argument, select a registered service by number. `--all` processes each independently and prints `SUCCESS`, `SKIPPED`, or `FAILED`. Existing unit conflicts are skipped, other services continue, and the overall exit is non-zero if any service was skipped or failed. For a non-systemd service, `--all --generate-systemd` initializes its state and reports that its systemd portion was skipped. `--yes` makes confirmation non-interactive.

## 10. Existing systemd service safety behavior

Generation requested through `init-service.sh` checks both `my-app-blue.service` and `my-app-green.service` before writing. A unit known through systemd, a file in a systemd lookup directory, or even a broken `/etc/systemd/system` symlink is a conflict. Both existing units, only blue, or only green all stop single-service processing; the script will neither overwrite nor repair them. A failed new installation transaction removes links and enablement that transaction created.

> Existing services must be reviewed or removed manually before retrying installation.

Inspect first with `systemctl cat`, `systemctl show -p FragmentPath`, and `ls -l /etc/systemd/system/my-app-*.service`. There is no `remove-service.sh`; remove or replace units only under your change-control process, then run `sudo systemctl daemon-reload`.

## 11. Prepare shared application files

Persistent configuration belongs below `<deploy-path>/shared`, outside release directories. Typical examples are `.env`, credentials, runtime configuration, or application-managed uploads. The template automatically loads only the configured `env_file`; your service must explicitly use any other shared path.

```bash
cp /path/to/application.env /var/www/my-app/shared/.env
chmod 600 /var/www/my-app/shared/.env
sudo chown my-app:my-app /var/www/my-app/shared/.env
```

Set ownership so the systemd `user` can read it. Never commit secrets. `onboard.sh` creates a missing env file from `config/app.env.example` but never overwrites an existing one; edit the generated file before production use.

## 12. Prepare the application artifact or source

`deploy.sh` accepts an existing file or directory and copies it into `<release>/artifact`. For the systemd unit above, the copied directory must contain executable `bin/my-app`:

```bash
./scripts/deploy.sh my-app /path/to/built-output --dry-run
```

`onboard.sh` instead accepts an application source directory. It runs each supplied build command from that directory. Without `--build-command`, it requires a Makefile and runs `make test` then `make build`. Use `--artifact`; otherwise it searches `dist`, `build`, common binary names, and `app` below the source.

```bash
./scripts/onboard.sh --source /srv/src/my-app --service my-app \
  --build-command 'make test' --build-command 'make build' \
  --artifact build
```

Relative artifact paths are resolved from `--source`. Build commands run through `bash -c`, so keep them reviewed and trusted.

## 13. Configure the reverse proxy

Generated configuration routes `public_port` to `127.0.0.1:<active-color-port>`. The active color comes from state for ordinary generation and is explicitly rendered to the target color during a traffic switch.

### Apache

```bash
./scripts/generate-apache.sh --service my-app --output build/apache
./scripts/validate-apache.sh build/apache/my-app.conf
sudo apache2ctl configtest
```

Apache needs `proxy`, `proxy_http`, and `headers`. `onboard.sh` enables them, installs the site in `/etc/apache2/sites-available`, adds a managed `Listen` configuration for a non-80 public port, enables the site, tests configuration, and reloads Apache. A direct live `deploy.sh` needs the switch overrides shown in [Operations](OPERATIONS.md), including `APACHE_CONFIG_DIR`, `APACHE_INSTALL_CMD`, `APACHE_ENABLE_CMD`, and `APACHE_RELOAD_CMD`.

### NGINX

```bash
./scripts/generate-nginx.sh --service my-app --output build/nginx
./scripts/validate-nginx.sh build/nginx
sudo nginx -t
```

For a production switch, override the safe local defaults so the generated file is installed where NGINX includes it:

```bash
sudo mkdir -p /etc/nginx/conf.d/zero-downtime
NGINX_INSTALL_DIR=/etc/nginx/conf.d/zero-downtime \
NGINX_RELOAD_CMD='sudo -n systemctl reload nginx' \
./scripts/deploy.sh my-app /path/to/built-output
```

Ensure `/etc/nginx/nginx.conf` includes that directory (for example, `include /etc/nginx/conf.d/zero-downtime/*.conf;`) and grant the operator permission to copy there; `switch-traffic.sh` uses plain `cp` for NGINX. By default it installs only under `build/nginx-installed`, which is safe for local validation but does not configure the host proxy.

The supplied templates proxy all paths and set forwarding/color headers. They set HTTP/1.1 but do not add WebSocket `Upgrade`/`Connection` headers and do not implement path-prefix stripping; customize and test the templates if your service needs those behaviors.

## 14. Perform the first deployment

For an Apache-backed first service, the preferred end-to-end command is:

```bash
./scripts/onboard.sh --source /srv/src/my-app \
  --service my-app \
  --environment production \
  --build-command 'make test' \
  --build-command 'make build' \
  --artifact build
```

`onboard.sh` validates Linux/systemd/config/proxy prerequisites, prepares directories and a missing env file, builds as the normal user, installs matching systemd units, configures Apache when selected, invokes `deploy.sh`, stops the previously active color after a successful change, then checks `/live`, `/health`, `/ready`, and `/version` on `public_port`. Your application must expose all four paths for this final onboard verification. Use `--force` only after reviewing differences; it creates timestamped backups before replacing differing managed systemd or Apache files.

For a prepared host or NGINX with the overrides above, deploy the artifact directly:

```bash
./scripts/deploy.sh my-app /path/to/built-output --dry-run
./scripts/deploy.sh my-app /path/to/built-output
```

The live deployment creates a retained release and updates `current`, chooses and starts the inactive color, checks its configured `health_path`, verifies the target runtime, generates/installs/validates proxy configuration, reloads the proxy, updates `active_color`, and appends traffic-switch and deploy history. Direct `deploy.sh` leaves the old color running.

## 15. Verify the first deployment

```bash
./scripts/show-state.sh my-app
./scripts/list-releases.sh my-app
systemctl status my-app-blue.service --no-pager
systemctl status my-app-green.service --no-pager
journalctl -u my-app-blue.service -n 100 --no-pager
journalctl -u my-app-green.service -n 100 --no-pager
curl -f http://127.0.0.1:18080/health
curl -f http://127.0.0.1:18081/health
curl -f http://127.0.0.1:8080/health
```

Only the running color's local curl is expected to succeed if the other color has never been deployed or was stopped by `onboard.sh`. The public check must reach the active color.

## 16. Verify active and inactive colors

```bash
./scripts/show-state.sh my-app
cat /var/www/my-app/state/active_color
./scripts/status-color.sh my-app blue || true
./scripts/status-color.sh my-app green || true
```

The active color receives proxy traffic; the inactive color is the next deployment target. Before the first deployment neither unit need be running. Do not casually edit `active_color`: traffic switching updates it only after proxy reload succeeds, and manual edits can make generated configuration disagree with real traffic.

## 17. Rollback

Rollback requires initialized state and at least one earlier successful release still retained. Preview it first:

```bash
./scripts/list-releases.sh my-app
./scripts/rollback.sh my-app --dry-run
./scripts/rollback.sh my-app
```

By default the script selects the previous successful retained release; choose one explicitly with `--release <release-id>`. It starts that release on the inactive color, health-checks it, switches proxy traffic, updates active-color state, and appends switch and rollback history. It leaves the formerly active color running. Use the same Apache/NGINX environment overrides as deployment for a live production proxy.

## 18. Jenkins usage (optional)

Keep `config/services.yml` in source control and secrets outside it. Run Jenkins as an unprivileged account and grant narrowly scoped `sudo -n` rules for required systemd/proxy commands—never store a sudo password in a job.

```bash
./scripts/init-service.sh my-app --install-systemd --yes
init_status=$?
echo "exit_code=$init_status"
test "$init_status" -eq 0
```

The repository `Jenkinsfile` and `examples/jenkins/` demonstrate deployment pipelines. Treat a non-zero initializer or deployment exit as a failed stage, and use Jenkins credentials bindings or an external secret store for sensitive data.

## 19. Complete copy-paste checklist

Replace the source/artifact details and edit configuration before continuing:

```bash
git clone https://github.com/shekhar396/zero-downtime-cicd-template.git
cd zero-downtime-cicd-template

# Edit config/services.yml using the my-app example in this guide.
./scripts/validate-config.sh

sudo mkdir -p /var/www/my-app
sudo chown -R "$USER":"$USER" /var/www/my-app
sudo chmod 755 /var/www/my-app

./scripts/init-service.sh my-app --install-systemd

cp /path/to/application.env /var/www/my-app/shared/.env
chmod 600 /var/www/my-app/shared/.env
sudo chown my-app:my-app /var/www/my-app/shared/.env

# Preferred complete Apache workflow (app must expose the four verification paths):
./scripts/onboard.sh --source /srv/src/my-app --service my-app \
  --environment production --build-command 'make build' --artifact build

./scripts/show-state.sh my-app
systemctl status my-app-blue.service --no-pager || true
systemctl status my-app-green.service --no-pager || true
curl -f http://127.0.0.1:8080/health
```

## 20. Troubleshooting

### Permission denied under `/var/www`

```bash
sudo mkdir -p /var/www/my-app
sudo chown -R "$USER":"$USER" /var/www/my-app
```

Also check the systemd service account can traverse the path and read its artifact/env file.

### Service is not registered

Add its complete list item to `config/services.yml`, check the exact `service_name`, then run `./scripts/validate-config.sh`.

### Existing blue/green services detected

Inspect both units and their fragment paths. The initializer intentionally refuses to overwrite complete, partial, externally located, or broken-symlink installations. Review/remove them manually under change control and reload systemd before retrying.

### Services are enabled but inactive

This is expected after `--install-systemd`; the first deployment starts the inactive color.

### Health check fails

Check both unit logs, `systemctl status`, local port binding, the configured `health_path`, `.env` ownership/content, database connectivity, and missing credentials. Confirm the endpoint returns 2xx rather than merely accepting TCP connections.

### Port already in use

```bash
sudo ss -lntp | grep ':<port>'
```

Choose three unique unused ports and revalidate configuration.

### systemd unit fails to load

```bash
systemctl cat my-app-blue.service
systemd-analyze verify build/systemd/my-app-blue.service
sudo systemctl daemon-reload
```

Also verify the working directory exists after release creation, the artifact is executable, and the configured user/group exist.

### Proxy returns 502

Use `show-state.sh` to identify the active color, verify that unit and its local health URL, then compare the generated/installed upstream port. Run `sudo apache2ctl configtest` or `sudo nginx -t`, inspect proxy logs, and confirm the proxy was reloaded. A firewall normally should not be opened for loopback-only blue/green ports.

### Dirty or incomplete state

Run `./scripts/show-state.sh my-app` and `./scripts/list-releases.sh my-app`; inspect `state/history.log` and any reported `deploy.lock`. Do not delete state, releases, locks, or `current` manually until you understand whether a deployment is running. Preserve evidence and use the operational runbook.

## 21. FAQ

**Can I rerun `init-service.sh`?** Directory/state initialization is idempotent. Systemd generation through this command refuses to proceed if either unit already exists.

**Does `--install-systemd` start the application? Why are units inactive?** No. It enables units for boot but the deployment workflow performs the first start.

**Can I onboard more than one service? What does `--all` do?** Yes. Register each list item; `--all` initializes each independently and optionally generates/installs systemd units.

**Can I regenerate systemd units when services already exist?** Not with `init-service.sh`; review the installed units manually. `onboard.sh` has separate managed-file behavior and replaces differences only with `--force` and backups.

**Where should `.env` files be stored?** At the configured `env_file`, normally `<deploy-path>/shared/.env`, outside Git and release directories.

**Does initialization deploy code or switch traffic?** No. `init-service.sh` does neither. `deploy.sh` and `onboard.sh` perform deployment and switching.

**Can Jenkins run this non-interactively?** Yes. Use `--yes`, checked exit codes, and appropriately scoped passwordless sudo.

## 22. Next steps

- [Configuration reference](CONFIGURATION.md)
- [Operations runbook](OPERATIONS.md)
- [Architecture](ARCHITECTURE.md)
- [Health checks](HEALTH_CHECK.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Jenkins examples](../examples/jenkins/README.md)
