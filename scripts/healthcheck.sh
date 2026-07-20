#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./scripts/healthcheck.sh <url> [--retries <count>] [--timeout <seconds>] [--interval <seconds>]

Examples:
  ./scripts/healthcheck.sh http://localhost:8080/health
  ./scripts/healthcheck.sh http://localhost:8080/health --retries 10 --timeout 3

Exit codes:
  0  health check succeeded with a 2xx HTTP response
  1  health check completed but endpoint did not become healthy
  2  usage or configuration error
USAGE
}

is_positive_integer() {
  [[ "${1:-}" =~ ^[1-9][0-9]*$ ]]
}

url=""
retries="${HEALTHCHECK_RETRIES:-5}"
timeout="${HEALTHCHECK_TIMEOUT:-5}"
interval="${HEALTHCHECK_INTERVAL:-1}"

if [[ "$#" -lt 1 ]]; then
  usage
  exit 2
fi

url="$1"
shift

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --retries)
      if [[ "$#" -lt 2 ]]; then
        echo "[healthcheck] ERROR: --retries requires a value" >&2
        exit 2
      fi
      retries="$2"
      shift 2
      ;;
    --timeout)
      if [[ "$#" -lt 2 ]]; then
        echo "[healthcheck] ERROR: --timeout requires a value" >&2
        exit 2
      fi
      timeout="$2"
      shift 2
      ;;
    --interval)
      if [[ "$#" -lt 2 ]]; then
        echo "[healthcheck] ERROR: --interval requires a value" >&2
        exit 2
      fi
      interval="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[healthcheck] ERROR: unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$url" ]]; then
  echo "[healthcheck] ERROR: URL is required" >&2
  exit 2
fi

if ! is_positive_integer "$retries"; then
  echo "[healthcheck] ERROR: retries must be a positive integer: $retries" >&2
  exit 2
fi

if ! is_positive_integer "$timeout"; then
  echo "[healthcheck] ERROR: timeout must be a positive integer: $timeout" >&2
  exit 2
fi

if ! is_positive_integer "$interval"; then
  echo "[healthcheck] ERROR: interval must be a positive integer: $interval" >&2
  exit 2
fi

echo "[healthcheck] url=$url"
echo "[healthcheck] retries=$retries timeout=${timeout}s interval=${interval}s"

for attempt in $(seq 1 "$retries"); do
  echo "[healthcheck] attempt=${attempt}/${retries}"
  http_status="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' --max-time "$timeout" "$url" 2>/dev/null || true)"
  http_status="${http_status:-000}"
  echo "[healthcheck] http_status=$http_status"

  if [[ "$http_status" =~ ^2[0-9][0-9]$ ]]; then
    echo "[healthcheck] result=healthy"
    exit 0
  fi

  if [[ "$attempt" -lt "$retries" ]]; then
    echo "[healthcheck] result=retrying"
    sleep "$interval"
  fi
done

echo "[healthcheck] result=unhealthy"
exit 1
