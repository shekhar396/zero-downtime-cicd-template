# Health Check Validation

The health-check script validates an HTTP endpoint before a deployment candidate is promoted.

In the v0.1.0 blue/green deployment flow, this script belongs after the idle environment has been started and before any traffic switching happens. It gives the deployment engine a focused pass/fail signal for whether the candidate environment is ready to serve traffic.

This feature only provides health validation. It does not deploy containers, switch NGINX traffic, or roll back releases.

## Usage

Run the script with the health URL as the first argument:

```bash
./scripts/health-check.sh http://localhost:8001/health
```

If the URL returns HTTP `200`, the script treats the endpoint as healthy.

## Environment Overrides

The script retries before failing. Defaults are:

- `MAX_RETRIES=10`
- `RETRY_INTERVAL=3`

Override them when calling the script:

```bash
MAX_RETRIES=5 RETRY_INTERVAL=2 ./scripts/health-check.sh http://localhost:8001/health
```

## Exit Codes

- `0`: health check succeeded
- `1`: health check failed or usage was invalid

## Success Example

When the endpoint is healthy:

```bash
./scripts/health-check.sh http://localhost:8001/health
```

Expected behavior:

- prints the health URL
- prints each attempt number
- prints the HTTP status code
- exits `0` after receiving HTTP `200`

## Failure Example

When the endpoint is unavailable:

```bash
MAX_RETRIES=2 RETRY_INTERVAL=1 ./scripts/health-check.sh http://localhost:9999/health
```

Expected behavior:

- prints each failed attempt
- prints the HTTP status code, usually `000` when no server responds
- exits `1` after all retries are exhausted

## Why This Matters

Traffic should not switch to the idle environment just because a container started successfully.

Health checks verify that the application can respond through its configured endpoint. Requiring a successful health check before promotion reduces the chance of sending users to a broken or still-starting release.
