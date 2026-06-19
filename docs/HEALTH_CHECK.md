# Health Check Validation

Health checks are the release validation gate for the planned `v1.0.0` Linux VM blue/green deployment flow. Phase 3 provides reusable health-check commands only. It does not deploy services, switch traffic, promote releases, reload NGINX, call Jenkins, or roll back releases.

## Health Check Contract

A health endpoint is considered healthy when it returns any HTTP `2xx` status code before retries are exhausted.

A health endpoint is considered unhealthy when:

- the endpoint returns a non-`2xx` status
- the request times out
- the endpoint cannot be reached
- retries are exhausted before a `2xx` response appears

## Command Usage

Run a direct health check:

```bash
./scripts/healthcheck.sh http://localhost:8080/health
```

Override retry and timeout behavior:

```bash
./scripts/healthcheck.sh http://localhost:8080/health --retries 10 --timeout 3
```

Use the Make target:

```bash
make health URL=http://localhost:8080/health
```

## Retry Behavior

Defaults:

- retries: `5`
- timeout: `5` seconds per request
- interval: `1` second between attempts

Overrides:

- `--retries <count>`
- `--timeout <seconds>`
- `--interval <seconds>`
- `HEALTHCHECK_RETRIES=<count>`
- `HEALTHCHECK_TIMEOUT=<seconds>`
- `HEALTHCHECK_INTERVAL=<seconds>`

## Exit Codes

`scripts/healthcheck.sh` returns:

- `0` when a `2xx` response is received
- `1` when the endpoint does not become healthy
- `2` for usage or configuration errors

`scripts/validate-release.sh` returns:

- `0` when the registered service candidate endpoint is healthy
- `1` when health validation fails
- `2` when service config, service state, or input arguments are invalid

## Release Validation

Validate a registered service candidate by service name and candidate port:

```bash
./scripts/validate-release.sh billing-api 18080
```

The release validator:

1. validates `config/services.yml`
2. confirms the service exists
3. confirms service state has been initialized
4. reads the service `health_path`
5. builds `http://localhost:<candidate_port><health_path>`
6. calls `scripts/healthcheck.sh`
7. returns non-zero on failure

The validator prints structured operator output with service name, deploy path, state directory, health URL, retry settings, and final status.

## Local Mock Server

A shell-only mock health service is available for local validation:

```bash
./examples/mock-health-server/server.sh 18080
```

In another terminal:

```bash
./scripts/healthcheck.sh http://localhost:18080/health
./scripts/validate-release.sh billing-api 18080
```

The mock server returns:

- `200 OK` for `/health`
- `404 Not Found` for every other path

## Future Deployment Integration

Future deployment phases should call `scripts/validate-release.sh` after a candidate service has been started on the inactive blue/green port and before any traffic promotion decision. A failed health check must stop promotion and leave current traffic untouched.
