#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <health-url>"
  echo
  echo "Example:"
  echo "  $0 http://localhost:8001/health"
  echo
  echo "Optional environment variables:"
  echo "  MAX_RETRIES=10"
  echo "  RETRY_INTERVAL=3"
}

is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

if [[ "$#" -ne 1 ]]; then
  usage
  exit 1
fi

HEALTH_URL="$1"
MAX_RETRIES="${MAX_RETRIES:-10}"
RETRY_INTERVAL="${RETRY_INTERVAL:-3}"

if ! is_positive_integer "$MAX_RETRIES"; then
  echo "[health-check] ERROR: MAX_RETRIES must be a positive integer."
  exit 1
fi

if ! is_positive_integer "$RETRY_INTERVAL"; then
  echo "[health-check] ERROR: RETRY_INTERVAL must be a positive integer."
  exit 1
fi

echo "[health-check] Checking health URL: $HEALTH_URL"
echo "[health-check] Max retries: $MAX_RETRIES"
echo "[health-check] Retry interval: ${RETRY_INTERVAL}s"

for attempt in $(seq 1 "$MAX_RETRIES"); do
  echo "[health-check] Attempt ${attempt}/${MAX_RETRIES}"

  http_status="$(curl --silent --output /dev/null --write-out "%{http_code}" "$HEALTH_URL" || true)"
  http_status="${http_status:-000}"

  echo "[health-check] HTTP status code: $http_status"

  if [[ "$http_status" == "200" ]]; then
    echo "[health-check] Health check succeeded."
    exit 0
  fi

  if [[ "$attempt" -lt "$MAX_RETRIES" ]]; then
    echo "[health-check] Health check not ready. Retrying in ${RETRY_INTERVAL}s..."
    sleep "$RETRY_INTERVAL"
  fi
done

echo "[health-check] Health check failed after ${MAX_RETRIES} attempts."
exit 1
