#!/usr/bin/env bash
# Health-check helpers for Phase 3 release validation foundations.
# This library builds and checks health URLs only. It does not deploy, promote,
# switch traffic, reload NGINX, or roll back releases.

set -euo pipefail

HEALTH_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEALTH_ROOT_DIR="$(cd "$HEALTH_LIB_DIR/../.." && pwd)"

health_error() {
  echo "[health] ERROR: $*" >&2
}

health_is_positive_integer() {
  [[ "${1:-}" =~ ^[1-9][0-9]*$ ]]
}

health_is_port() {
  local port="${1:-}"
  [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 ))
}

health_normalize_path() {
  local path="${1:-}"

  if [[ -z "$path" ]]; then
    health_error "health path is required"
    return 1
  fi

  if [[ "$path" != /* ]]; then
    path="/$path"
  fi

  printf '%s\n' "$path"
}

health_build_url() {
  local candidate_port="${1:-}"
  local health_path="${2:-}"
  local host="${3:-localhost}"
  local normalized_path

  if ! health_is_port "$candidate_port"; then
    health_error "candidate port must be between 1 and 65535: ${candidate_port:-<empty>}"
    return 1
  fi

  normalized_path="$(health_normalize_path "$health_path")"
  printf 'http://%s:%s%s\n' "$host" "$candidate_port" "$normalized_path"
}

health_execute_validation() {
  local url="${1:-}"
  local retries="${2:-5}"
  local timeout="${3:-5}"

  if [[ -z "$url" ]]; then
    health_error "health URL is required"
    return 2
  fi

  if ! health_is_positive_integer "$retries"; then
    health_error "retries must be a positive integer: $retries"
    return 2
  fi

  if ! health_is_positive_integer "$timeout"; then
    health_error "timeout must be a positive integer: $timeout"
    return 2
  fi

  "$HEALTH_ROOT_DIR/scripts/healthcheck.sh" "$url" --retries "$retries" --timeout "$timeout"
}
