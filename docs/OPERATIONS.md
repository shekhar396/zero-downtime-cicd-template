# Operations

These commands assume the repository root and the registered service `zero-downtime-demo-go`.

## Passwordless sudo for deployments

The framework runs system-level deployment operations non-interactively with `sudo -n`. This is required for Jenkins, GitLab CI, GitHub Actions, and other automation where password prompts cannot be answered.

Do not grant the deployment user unrestricted sudo access. Allow only the commands required for its service and proxy. Create a dedicated sudoers file:

```bash
sudo visudo -f /etc/sudoers.d/zero-downtime-cicd
```

Add the following, replacing `<deployment-user>` and `<service>`:

```sudoers
<deployment-user> ALL=(root) NOPASSWD: \
    /usr/bin/systemctl start <service>-blue, \
    /usr/bin/systemctl stop <service>-blue, \
    /usr/bin/systemctl restart <service>-blue, \
    /usr/bin/systemctl status <service>-blue, \
    /usr/bin/systemctl start <service>-green, \
    /usr/bin/systemctl stop <service>-green, \
    /usr/bin/systemctl restart <service>-green, \
    /usr/bin/systemctl status <service>-green, \
    /usr/bin/systemctl daemon-reload, \
    /usr/sbin/apache2ctl configtest, \
    /usr/bin/systemctl reload apache2
```

Secure and validate the file:

```bash
sudo chmod 440 /etc/sudoers.d/zero-downtime-cicd
sudo visudo -c
```

Expected output includes:

```text
/etc/sudoers.d/zero-downtime-cicd: parsed OK
```

## Show state and releases

```bash
./scripts/show-state.sh zero-downtime-demo-go
./scripts/list-releases.sh zero-downtime-demo-go
```

State reports the active and inactive colors, `current` symlink, latest history entry, and deployment lock. Release listing shows retained IDs and metadata.

## Deploy an artifact

Build the official demo, preview the deployment, then deploy:

```bash
cd ../zero-downtime-demo-go
make test
make build
cd ../zero-downtime-cicd-template

./scripts/deploy.sh zero-downtime-demo-go \
  ../zero-downtime-demo-go/bin/zero-downtime-demo-go --dry-run

./scripts/deploy.sh zero-downtime-demo-go \
  ../zero-downtime-demo-go/bin/zero-downtime-demo-go
```

`deploy.sh` creates a release, starts the inactive color, validates health, and switches traffic. It leaves the old color running.

## Check color status

```bash
./scripts/status-color.sh zero-downtime-demo-go blue
./scripts/status-color.sh zero-downtime-demo-go green
```

For native systemd output:

```bash
systemctl status zero-downtime-demo-go-blue.service
systemctl status zero-downtime-demo-go-green.service
```

## Run health checks

Check the public endpoint:

```bash
./scripts/healthcheck.sh http://127.0.0.1:8080/health \
  --retries 5 --timeout 5 --interval 1
```

Check a color directly:

```bash
./scripts/validate-release.sh zero-downtime-demo-go 18080
./scripts/validate-release.sh zero-downtime-demo-go 18081
```

The selected color must be running before direct validation.

## Switch traffic manually

Normally `deploy.sh` and `rollback.sh` switch traffic. Preview a manual switch first:

```bash
./scripts/switch-traffic.sh zero-downtime-demo-go green --dry-run
```

For the onboarded Apache installation, switch directly:

```bash
./scripts/switch-traffic.sh zero-downtime-demo-go green
```

The target color must be running and healthy. Replace `green` with `blue` when appropriate. Apache defaults match the Debian/Ubuntu paths managed by onboarding; other layouts can override `APACHE_CONFIG_DIR`, `APACHE_INSTALL_CMD`, `APACHE_ENABLE_CMD`, and `APACHE_RELOAD_CMD`.

## Stop a color

Confirm the inactive color with `show-state.sh`, then stop only that color:

```bash
./scripts/stop-color.sh zero-downtime-demo-go blue
```

Never stop the active color unless you intend to interrupt public service.

## Roll back

Select the previous successful retained release automatically:

```bash
./scripts/rollback.sh zero-downtime-demo-go --dry-run
./scripts/rollback.sh zero-downtime-demo-go
```

Select a specific retained release:

```bash
./scripts/list-releases.sh zero-downtime-demo-go
./scripts/rollback.sh zero-downtime-demo-go --release <release_id> --dry-run
./scripts/rollback.sh zero-downtime-demo-go --release <release_id>
```

Rollback starts the selected release on the inactive color, validates it, and switches traffic. It leaves the old color running.

## Inspect logs

```bash
journalctl -u zero-downtime-demo-go-blue.service -n 100 --no-pager
journalctl -u zero-downtime-demo-go-green.service -n 100 --no-pager
journalctl -u zero-downtime-demo-go-blue.service -f
```

## Inspect generated and installed configuration

Systemd:

```bash
systemctl cat zero-downtime-demo-go-blue.service
systemctl cat zero-downtime-demo-go-green.service
```

Apache:

```bash
sudo apache2ctl -S
sudo apache2ctl configtest
sudo sed -n '1,160p' /etc/apache2/sites-available/zero-downtime-demo-go.conf
sudo sed -n '1,40p' /etc/apache2/conf-available/zero-downtime-demo-go-listen.conf
```

NGINX:

```bash
sudo nginx -t
sudo nginx -T
```

Use [Troubleshooting](TROUBLESHOOTING.md) when a command fails. Do not edit generated systemd or proxy files in place; update `config/services.yml` and reconcile with onboarding.
