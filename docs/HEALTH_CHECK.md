# Health Check Validation

Health checks are the promotion gate for the planned `v1.0.0` VM-based blue/green deployment flow.

The complete deployment and rollback design lives in [ARCHITECTURE.md](ARCHITECTURE.md). This document focuses only on health-check behavior.

## v1 Role

For each registered service, the deployment workflow should:

1. start the candidate container on the inactive color
2. call the configured health endpoint on the candidate port
3. retry according to the service configuration
4. fail the deployment without switching traffic if the candidate does not become healthy
5. run post-switch verification after NGINX traffic changes

## Configuration Inputs

Each service should define health-check settings in `config/services.yml`:

```yaml
health_check:
  path: /health
  expected_status: 200
  timeout_seconds: 3
  retries: 10
  interval_seconds: 3
```

## Expected Script Contract

The v1 `scripts/health-check.sh` command should accept a fully resolved URL and return:

- `0` when the endpoint returns the expected status within the retry policy
- `1` when validation fails or usage is invalid

The deployment orchestrator should decide whether the health check is candidate validation or post-switch verification.

## Why This Matters

Traffic should not switch to a candidate just because a container started successfully. Health checks verify that the service can respond through its configured readiness endpoint before users are sent to it.
