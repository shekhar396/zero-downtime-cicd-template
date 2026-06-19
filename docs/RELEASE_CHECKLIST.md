# Release Checklist

Use this checklist before tagging or publishing a v1.0.0 release.

## Repository Checks

```bash
make help
make validate-config
make lint-shell
make deploy-dry-run SERVICE=billing-api ARTIFACT=examples/mock-artifact
make rollback-dry-run SERVICE=billing-api
git diff --check
```

## Documentation Checks

- README explains the problem, audience, features, limitations, quick start, Jenkins, rollback, and roadmap.
- `docs/QUICK_START.md` works with `billing-api` and `examples/mock-artifact`.
- `docs/DEMO_WALKTHROUGH.md` covers create release, start color, health check, switch dry-run, rollback dry-run, and deploy dry-run.
- `docs/TROUBLESHOOTING.md` documents common operator failures.
- Kubernetes is described only as future v2.0.0 roadmap scope.
- v1.0.0 is consistently described as a Linux VM template using Docker/container runtime.
- Local deploy path examples use `/tmp/zero-downtime-cicd/services/<service-name>`.
- Production deploy path recommendations use `/opt/apps/<service-name>`.

## Manual VM Verification

Before production use, manually verify on a Linux VM with Docker and NGINX installed:

- service initialization creates the expected directory layout
- release creation copies artifacts and writes metadata
- runtime start launches the selected color container
- health check passes against the selected color port
- generated NGINX config passes real `nginx -t`
- traffic switch reloads NGINX and updates `active_color` only after success
- rollback dry-run selects the expected retained release
- live rollback works in a controlled staging environment

## Jenkins Verification

- Root `Jenkinsfile` is reviewed in a Jenkins controller.
- Pipeline parameters are documented.
- Dry-run is the default behavior.
- Production approval is required unless `AUTO_APPROVE=true` is intentionally selected.
- Secrets are stored in Jenkins credentials or environment controls, not in repository files.

## Release Tag Recommendation

```bash
git status --short
git diff --check
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin main
git push origin v1.0.0
```
