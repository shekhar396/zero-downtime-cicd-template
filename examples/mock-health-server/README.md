# Mock Health Server

A minimal shell-only HTTP mock for local validation.

Behavior:

- `GET /health` returns `200 OK`
- any other path returns `404 Not Found`

Start it on the default port:

```bash
./examples/mock-health-server/server.sh
```

Start it on a custom port:

```bash
./examples/mock-health-server/server.sh 18080
```

Then validate:

```bash
./scripts/healthcheck.sh http://localhost:18080/health
./scripts/validate-release.sh billing-api 18080
```

Stop the server with `Ctrl+C`.
