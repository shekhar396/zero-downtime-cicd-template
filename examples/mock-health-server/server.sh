#!/usr/bin/env bash
set -euo pipefail

HOST="${MOCK_HEALTH_HOST:-127.0.0.1}"
PORT="${1:-${MOCK_HEALTH_PORT:-19080}}"

is_port() {
  [[ "${1:-}" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 ))
}

cleanup() {
  if [[ -n "${MOCK_HEALTH_TMP_DIR:-}" && -d "$MOCK_HEALTH_TMP_DIR" ]]; then
    rm -rf "$MOCK_HEALTH_TMP_DIR"
  fi
}
trap cleanup EXIT INT TERM

if ! is_port "$PORT"; then
  echo "[mock-health-server] ERROR: port must be between 1 and 65535: $PORT" >&2
  exit 2
fi

if ! command -v nc >/dev/null 2>&1; then
  echo "[mock-health-server] ERROR: nc is required for the shell mock server" >&2
  exit 2
fi

MOCK_HEALTH_TMP_DIR="$(mktemp -d)"
response_fifo="$MOCK_HEALTH_TMP_DIR/response.fifo"
mkfifo "$response_fifo"

echo "[mock-health-server] listening on http://${HOST}:${PORT}"
echo "[mock-health-server] returns 200 for /health and 404 elsewhere"
echo "[mock-health-server] press Ctrl+C to stop"

while true; do
  cat "$response_fifo" | nc -l "$HOST" "$PORT" | {
    request_line=""
    IFS= read -r request_line || true
    path="$(printf '%s\n' "$request_line" | awk '{ print $2 }')"
    path="${path:-/}"

    if [[ "$path" == "/health" ]]; then
      body='OK'
      {
        printf 'HTTP/1.1 200 OK\r\n'
        printf 'Content-Type: text/plain\r\n'
        printf 'Content-Length: %s\r\n' "${#body}"
        printf 'Connection: close\r\n'
        printf '\r\n'
        printf '%s\n' "$body"
      } > "$response_fifo"
    else
      body='Not Found'
      {
        printf 'HTTP/1.1 404 Not Found\r\n'
        printf 'Content-Type: text/plain\r\n'
        printf 'Content-Length: %s\r\n' "${#body}"
        printf 'Connection: close\r\n'
        printf '\r\n'
        printf '%s\n' "$body"
      } > "$response_fifo"
    fi
  }
done
