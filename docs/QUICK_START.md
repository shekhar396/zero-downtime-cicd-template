# Quick Start

This guide onboards the official [zero-downtime-demo-go](https://github.com/shekhar396/zero-downtime-demo-go) application, deploys a second release, and tests rollback.

## 1. Prerequisites

Use a Linux VM with:

- systemd
- Bash, Git, `curl`, and Go
- Apache with `a2enmod`, `a2ensite`, and `a2enconf`
- a normal user with passwordless non-interactive `sudo`
- ports `8080`, `18080`, and `18081` available

On Debian or Ubuntu, install the common packages with:

```bash
sudo apt-get update
sudo apt-get install -y apache2 curl git golang-go
```

Confirm non-interactive sudo is ready:

```bash
sudo -n true
```

## 2. Clone both repositories

```bash
git clone https://github.com/shekhar396/zero-downtime-cicd-template.git
git clone https://github.com/shekhar396/zero-downtime-demo-go.git
cd zero-downtime-cicd-template
```

## 3. Review the service configuration

Open `config/services.yml`. The included service uses Apache, public port `8080`, and application ports `18080` and `18081`.

```bash
./scripts/validate-config.sh
```

See [Configuration](CONFIGURATION.md) before changing a field.

## 4. Check required ports

```bash
sudo ss -ltnp | grep -E ':(8080|18080|18081)[[:space:]]' || true
```

No output means the ports are available. Resolve unexpected listeners before continuing.

## 5. Run onboarding

```bash
./scripts/onboard.sh \
  --source ../zero-downtime-demo-go \
  --environment production
```

The demo Makefile supplies `make test` and `make build`; onboarding detects `bin/zero-downtime-demo-go` as the artifact.

Onboarding creates or installs:

- the deploy path and shared environment file
- release, log, and state directories
- blue and green systemd units
- Apache modules, Listen configuration, and site configuration
- the first release and `current` symlink

It then starts the inactive color, checks its health, switches traffic, and stops the previously active color when appropriate.

| Situation | Behavior |
| --- | --- |
| First run | Creates and installs required resources |
| Rerun with matching resources | Reuses existing configuration |
| Managed files differ | Aborts without replacing them |
| `--force` | Backs up and replaces differing managed files |
| Shared `.env` exists | Preserves it |

## 6. Edit the shared environment when needed

The first run copies `config/app.env.example` to:

```text
/var/www/zero-downtime-demo-go/shared/.env
```

Edit common runtime values there if needed:

```bash
sudoedit /var/www/zero-downtime-demo-go/shared/.env
```

Do not add `PORT` or `ACTIVE_COLOR`. The generated systemd units inject those values for each color.

## 7. Verify the first release

```bash
curl --fail http://127.0.0.1:8080/live
curl --fail http://127.0.0.1:8080/health
curl --fail http://127.0.0.1:8080/ready
curl --fail http://127.0.0.1:8080/version
./scripts/show-state.sh zero-downtime-demo-go
./scripts/list-releases.sh zero-downtime-demo-go
```

Note the active color and release ID.

## 8. Deploy a second release

Rebuild the demo, then deploy its binary:

```bash
cd ../zero-downtime-demo-go
make test
make build
cd ../zero-downtime-cicd-template

./scripts/deploy.sh \
  zero-downtime-demo-go \
  ../zero-downtime-demo-go/bin/zero-downtime-demo-go
```

## 9. Confirm the active color changed

```bash
./scripts/show-state.sh zero-downtime-demo-go
curl --fail http://127.0.0.1:8080/health
```

The active color should be the opposite of the color recorded after onboarding.

## 10. Run rollback

Preview the rollback, then execute it:

```bash
./scripts/rollback.sh zero-downtime-demo-go --dry-run
./scripts/rollback.sh zero-downtime-demo-go
```

## 11. Confirm rollback succeeded

```bash
./scripts/show-state.sh zero-downtime-demo-go
./scripts/list-releases.sh zero-downtime-demo-go
curl --fail http://127.0.0.1:8080/health
curl --fail http://127.0.0.1:8080/version
```

The active color should have changed again, and the public endpoint should report the retained release selected by rollback. The previously active color remains running after `deploy.sh` and `rollback.sh`; see [Operations](OPERATIONS.md) before stopping it.
