# Contributing

Contributions should keep deployment behavior explicit, testable, and aligned with the documentation.

## Workflow

1. Create a focused branch such as `docs/quick-start`, `fix/health-check`, or `feat/proxy-validation`.
2. Make one coherent change.
3. Add or update tests when behavior changes.
4. Update public documentation in the same pull request.
5. Run the checks below before submitting.

Use concise commit messages such as `docs: clarify rollback flow` or `fix: validate candidate port`.

## Required checks

```bash
find scripts examples -type f -name "*.sh" -print0 | xargs -0 bash -n
./scripts/validate-config.sh
bash tests/init-service-test.sh
git diff --check
```

When changing systemd, Apache, NGINX, deployment, or rollback behavior, also test on a non-production Linux VM and document:

- the failure mode addressed
- validation performed
- rollback or recovery considerations
- any new operational risk

## Documentation

Keep commands synchronized with script usage and implementation. Use only the public `zero-downtime-demo-go` application in user-facing examples. Do not add planning notes as user documentation.

Check relative Markdown links and search the repository for obsolete names, private paths, domains, addresses, credentials, and tokens before release.

## Secrets and private data

Never commit credentials, tokens, SSH keys, certificates, private URLs, internal hostnames, customer data, or production configuration. Use generic placeholders and document which secure system should provide real values.

## Maintainer release check

Before tagging a release:

1. Confirm `CHANGELOG.md` contains the release notes and known limitations.
2. Run all required checks and representative VM deployment and rollback tests.
3. Follow [Quick Start](QUICK_START.md) from a clean checkout.
4. Verify all documentation links and public repository URLs.
5. Search tracked files for private data and obsolete demo references.
6. Confirm the version tag and license are correct.
