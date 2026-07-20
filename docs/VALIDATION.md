# Deployment Validation

Use this checklist after every deployment or rollback to confirm that the platform and application are operating correctly. Replace `<service>` and `<public-port>` with the values configured for the onboarded application.

## Verify active color

```bash
cat /var/www/<service>/state/active_color
```

This displays the currently active blue or green deployment. It must match the color receiving production traffic.

## Verify current release

```bash
readlink -f /var/www/<service>/current
```

This shows the active release directory. It should point to the latest deployed release after deployment and the previous release after rollback.

## Verify application version

```bash
curl http://127.0.0.1:<public-port>/version
```

The response should contain build metadata such as:

- `version`
- `git_commit`
- `build_time`

This confirms that the expected release is serving production traffic.

## Verify application health

```bash
curl http://127.0.0.1:<public-port>/health
```

Expect an HTTP 200 response.

## Verify runtime services

```bash
sudo systemctl status <service>-blue
sudo systemctl status <service>-green
```

The active service must be healthy. The inactive service may remain running for fast rollback, depending on the deployment policy.

## Verify reverse proxy

For Apache:

```bash
grep -E 'ProxyPass|ProxyPassReverse' \
  /etc/apache2/sites-enabled/<service>.conf
```

The configured upstream port must match the active deployment color.

## Deployment Success Checklist

- [ ] Release directory created
- [ ] Current symlink updated
- [ ] Inactive color started successfully
- [ ] Health checks passed
- [ ] Traffic switched
- [ ] Active color updated
- [ ] Public endpoint returns expected version
- [ ] Previous release retained

# Rollback Validation

After rollback, verify:

- [ ] Active color changed
- [ ] Current symlink points to the previous release
- [ ] Public `/version` endpoint returns the previous `git_commit`
- [ ] Health endpoint succeeds
- [ ] Reverse proxy points to the rollback color
- [ ] Application is reachable without downtime

# Common Validation Commands

```bash
cat /var/www/<service>/state/active_color
readlink -f /var/www/<service>/current
curl http://127.0.0.1:<public-port>/version
curl http://127.0.0.1:<public-port>/health
sudo systemctl status <service>-blue
sudo systemctl status <service>-green
grep -E 'ProxyPass|ProxyPassReverse' \
  /etc/apache2/sites-enabled/<service>.conf
```
