# Contributing

Thank you for considering a contribution. This repository is intended to become a safety-focused CI/CD template, so changes should be reviewed through an operational-risk lens.

## Branch Naming

Use descriptive branch names:

- `docs/<topic>`
- `feat/<capability>`
- `fix/<issue>`
- `chore/<maintenance>`
- `release/<version>`

Examples:

- `docs/mvp-scope`
- `feat/health-check-gate`
- `fix/nginx-rollback-validation`

## Commit Message Style

Use concise conventional-style commit messages:

- `docs: clarify release criteria`
- `feat: add blue green deployment script`
- `fix: validate health check timeout`
- `chore: update repository hygiene files`

## Pull Request Requirements

Pull requests should include:

- clear summary of the change
- reason for the change
- testing or validation performed
- rollback or safety considerations for deployment-related changes
- documentation updates when behavior changes

Deployment-related PRs should explain the failure modes they address and any new risks they introduce.

## Documentation Expectations

Documentation must stay aligned with implementation. Do not document features as complete before they are implemented and tested. Planning documents should use future-oriented language until behavior is validated.

## Safety-First Deployment Changes

Changes to deployment scripts, Jenkins stages, Docker behavior, NGINX switching, health checks, rollback, or environment handling require careful review. Prefer explicit failure behavior over silent continuation.

Deployment changes should be tested in a non-production environment before being recommended for production use.

## Secrets Policy

Do not commit secrets. This includes credentials, tokens, SSH keys, certificates, private URLs, or production configuration values. Use placeholders in examples and document where real values should be provided by operators.

