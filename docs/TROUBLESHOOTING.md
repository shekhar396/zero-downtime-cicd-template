# Troubleshooting

Start with state and service logs:

```bash
./scripts/show-state.sh zero-downtime-demo-go
./scripts/list-releases.sh zero-downtime-demo-go
journalctl -u zero-downtime-demo-go-blue.service -n 100 --no-pager
journalctl -u zero-downtime-demo-go-green.service -n 100 --no-pager
```

## Permission denied on the deploy path

**Symptom:** Onboarding cannot create or write under the configured `deploy_path`.

**Cause:** The existing directory is not writable by the deployment user.

**Fix:** Check ownership with `namei -l /var/www/zero-downtime-demo-go`, then assign the service deploy path to the deployment user. Do not make it world-writable.

## Root-owned build directory

**Symptom:** Onboarding reports that the repository `build` directory is not writable.

**Cause:** A previous command created generated files as root.

**Fix:** From the repository root, run `sudo chown -R "$(id -un):$(id -gn)" build`, then rerun onboarding as a normal user.

## No space left on device

**Symptom:** Builds, release copies, or logs fail with `No space left on device`.

**Cause:** The filesystem or inode table is full.

**Fix:** Check `df -h` and `df -i`. Remove unrelated safe-to-delete data or old logs, then rerun. Do not manually remove the current release.

## Port already in use

**Symptom:** A service fails to bind or Apache cannot listen on a configured port.

**Cause:** Another process owns `public_port`, `blue_port`, or `green_port`.

**Fix:** Run `sudo ss -ltnp | grep -E ':(8080|18080|18081)[[:space:]]'`, identify the owner, and stop it or choose unused unique ports in `config/services.yml`.

## Health check returns status 000

**Symptom:** `healthcheck.sh` repeatedly reports `http_status=000`.

**Cause:** The connection failed, timed out, or the application is not listening.

**Fix:** Check the color service status and journal, then run `curl -v http://127.0.0.1:18080/health` using the candidate port. Confirm the configured health path and port.

## systemd service fails

**Symptom:** `systemctl is-active` fails or the unit enters a restart loop.

**Cause:** The artifact is missing or not executable, its working directory is wrong, or runtime configuration is invalid.

**Fix:** Run `systemctl status <unit>` and `journalctl -u <unit> -n 100 --no-pager`. Confirm the `current` symlink, artifact execute bit, and shared environment file.

## Both colors use the same port

**Symptom:** The second color fails with an address-in-use error.

**Cause:** `blue_port` equals `green_port`, or a shared environment value overrides the generated unit.

**Fix:** Give each color a unique port, remove color-specific values from the shared file, run `./scripts/validate-config.sh`, and reconcile the units with onboarding.

## Shared environment contains PORT

**Symptom:** Both colors bind the value from the shared file instead of their configured ports.

**Cause:** `PORT` was added to `<deploy_path>/shared/.env`.

**Fix:** Remove `PORT` from the shared file and restart the affected color. Generated systemd units inject it.

## Shared environment contains ACTIVE_COLOR

**Symptom:** Health metadata reports the wrong color.

**Cause:** `ACTIVE_COLOR` in the shared file conflicts with the per-color unit value.

**Fix:** Remove `ACTIVE_COLOR` from the shared file and restart the affected color.

## Apache proxy modules are missing

**Symptom:** Apache reports unknown `ProxyPass`, `ProxyPassReverse`, or `RequestHeader` directives.

**Cause:** Required modules are disabled.

**Fix:** Run `sudo a2enmod proxy proxy_http headers`, validate with `sudo apache2ctl configtest`, then reload Apache.

## Apache is not listening on public_port

**Symptom:** The application ports work directly, but the public port refuses connections.

**Cause:** The generated Listen configuration is absent or disabled.

**Fix:** Inspect `/etc/apache2/conf-enabled/`, confirm one `Listen 8080`, run `sudo apache2ctl configtest`, and rerun onboarding if the managed file is missing.

## Duplicate Apache Listen directive

**Symptom:** Apache reports that an address is already in use or a Listen directive overlaps.

**Cause:** Another Apache file already declares the same public port.

**Fix:** Run `sudo grep -Rni '^[[:space:]]*Listen[[:space:]]\+8080' /etc/apache2`. Keep one intentional directive, disable the duplicate configuration, and test before reloading.

## Apache managed file differs

**Symptom:** Onboarding aborts because an Apache site or Listen file differs.

**Cause:** The installed managed file was edited or the service configuration changed.

**Fix:** Compare the installed and generated files. If the new configuration is intentional, rerun `onboard.sh` with `--force`; it creates a timestamped backup before replacement.

## systemd managed file differs

**Symptom:** Onboarding aborts because a generated blue or green unit differs from the installed unit.

**Cause:** The installed unit was edited or configuration changed.

**Fix:** Review `systemctl cat <unit>` and the generated unit in `build/systemd-onboarding`. Use onboarding `--force` only after confirming the replacement.

## Understanding --force

**Symptom:** A rerun refuses to reconcile managed files.

**Cause:** Safe default behavior prevents overwriting a differing system file.

**Fix:** Review the difference first. `./scripts/onboard.sh --source ../zero-downtime-demo-go --environment production --force` backs up and replaces differing managed files; it preserves an existing shared `.env`.

## Apache AH00558 ServerName warning

**Symptom:** Apache warns that it cannot reliably determine its fully qualified domain name.

**Cause:** Apache lacks a global `ServerName`; this is separate from the generated virtual host.

**Fix:** Set an appropriate global `ServerName` in Apache's normal configuration, run `sudo apache2ctl configtest`, and reload. Do not invent a public domain for the demo.

## Non-interactive sudo fails

**Symptom:** Onboarding or Jenkins reports that a password is required.

**Cause:** `sudo -n` is not authorized for the required commands.

**Fix:** Ask an administrator to grant narrowly scoped sudo permissions for systemd and proxy management. Verify with `sudo -n true`. Never put a sudo password in scripts, environment files, or Jenkinsfiles.

## Rollback fails

**Symptom:** Rollback cannot select, start, validate, or switch to a retained release.

**Cause:** No previous successful release exists, the selected release was removed, the service cannot start, or proxy reload failed.

**Fix:** Run `list-releases.sh`, inspect both color journals, check the candidate endpoint directly, and run rollback with `--dry-run`. If selecting manually, use an ID shown by `list-releases.sh`; do not change `active_color` by hand.
