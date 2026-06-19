# Jenkins Examples

These examples show how to call the repository scripts from Jenkins without embedding deployment logic in the pipeline.

## Files

- `Jenkinsfile.single-service` - deploy one service selected by parameter.
- `Jenkinsfile.multi-service` - iterate over a space-separated service list.

## Required Agent Tools

The Jenkins agent should have Bash, Make, Git, Docker for live runtime work, and NGINX on target VMs for real validation/reload. Agents also need access to the Linux VM deployment target if scripts are adapted for remote execution.

## Parameters

- `SERVICE_NAME` - registered service from `config/services.yml`
- `SERVICES` - space-separated services for the multi-service example
- `ARTIFACT_PATH` - artifact directory or file in the workspace
- `DEPLOY_ENV` - `staging` or `production` operator label
- `DRY_RUN` - when true, run validation and deploy dry-run only
- `AUTO_APPROVE` - bypass production manual approval only when intentionally enabled


## Apache Production Overrides

When Jenkins installs Apache config into a system directory, use non-interactive sudo command overrides and configure sudoers outside this repository:

```bash
APACHE_CONFIG_DIR=/etc/apache2/sites-available \
APACHE_INSTALL_CMD="sudo -n cp" \
APACHE_ENABLE_CMD="sudo -n a2ensite pico-photos-api.conf" \
APACHE_RELOAD_CMD="sudo -n systemctl reload apache2" \
./scripts/switch-traffic.sh pico-photos-api green
```

Do not hard-code service-specific values in shared Jenkinsfiles; pass them as job parameters or environment-specific settings.

## Rollback

Rollback remains an explicit operator action:

```bash
./scripts/rollback.sh billing-api --dry-run
./scripts/rollback.sh billing-api
```

Pipelines print rollback instructions on failure but do not auto-rollback.

## Notes

Do not store production secrets in Jenkinsfiles. Use Jenkins credentials and environment-specific operator controls. These examples do not assume any cloud provider or container orchestration platform.
