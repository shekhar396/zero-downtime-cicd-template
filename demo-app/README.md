# Demo App

This is a minimal FastAPI application for validating the deployment engine in the `zero-downtime-cicd-template` project.

The app is intentionally simple and only exists to validate blue/green deployment behavior behind NGINX.

## Build

```bash
docker build -t demo-app:v1 ./demo-app
```

## Run

Run the blue environment on port 8001:

```bash
docker run -d \
  --name demo-blue \
  -p 8001:8000 \
  -e APP_VERSION=v1 \
  demo-app:v1
```

Run the green environment on port 8002:

```bash
docker run -d \
  --name demo-green \
  -p 8002:8000 \
  -e APP_VERSION=v2 \
  demo-app:v1
```

## Test

```bash
curl http://localhost:8001
curl http://localhost:8001/health
curl http://localhost:8002
curl http://localhost:8002/health
```
