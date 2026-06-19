#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_CONFIG_FILE="${SERVICE_CONFIG_FILE:-$ROOT_DIR/config/services.yml}"
HEALTHCHECK_RETRIES="${HEALTHCHECK_RETRIES:-5}"
HEALTHCHECK_TIMEOUT="${HEALTHCHECK_TIMEOUT:-5}"

# shellcheck source=scripts/lib/service-discovery.sh
source "$ROOT_DIR/scripts/lib/service-discovery.sh"
# shellcheck source=scripts/lib/state.sh
source "$ROOT_DIR/scripts/lib/state.sh"
# shellcheck source=scripts/lib/health.sh
source "$ROOT_DIR/scripts/lib/health.sh"

usage() {
  cat <<'USAGE'
Usage: ./scripts/validate-release.sh <service_name> <candidate_port>

Validates that a candidate service endpoint is healthy. This does not deploy,
promote, switch traffic, modify state, or roll back releases.
USAGE
}

service_field() {
  local service_name="$1"
  local field_name="$2"
  service_discovery_get_service "$service_name" "$SERVICE_CONFIG_FILE" | awk -F= -v field="$field_name" '$1 == field { print substr($0, length($1) + 2); found = 1 } END { exit found ? 0 : 1 }'
}

if [[ "$#" -ne 2 ]]; then
  usage
  exit 2
fi

service_name="$1"
candidate_port="$2"

echo "[validate-release] event=validate_release_start service=$service_name candidate_port=$candidate_port"

echo "[validate-release] step=validate_config"
"$ROOT_DIR/scripts/validate-config.sh" "$SERVICE_CONFIG_FILE" >/dev/null

if [[ -z "$(service_discovery_get_service "$service_name" "$SERVICE_CONFIG_FILE")" ]]; then
  echo "[validate-release] status=failed reason=service_not_registered service=$service_name" >&2
  exit 2
fi

if ! health_is_port "$candidate_port"; then
  echo "[validate-release] status=failed reason=invalid_candidate_port candidate_port=$candidate_port" >&2
  exit 2
fi

deploy_path="$(state_resolve_service_deploy_path "$service_name" "$SERVICE_CONFIG_FILE")"
state_dir="$(state_service_state_dir "$service_name" "$SERVICE_CONFIG_FILE")"
active_color_file="$(state_active_color_file "$service_name" "$SERVICE_CONFIG_FILE")"

if [[ ! -d "$state_dir" || ! -f "$active_color_file" ]]; then
  echo "[validate-release] status=failed reason=state_not_initialized service=$service_name deploy_path=$deploy_path" >&2
  echo "[validate-release] hint=run ./scripts/init-service.sh $service_name" >&2
  exit 2
fi

health_path="$(service_field "$service_name" health_path)"
health_url="$(health_build_url "$candidate_port" "$health_path")"

echo "[validate-release] service=$service_name"
echo "[validate-release] deploy_path=$deploy_path"
echo "[validate-release] state_dir=$state_dir"
echo "[validate-release] health_url=$health_url"
echo "[validate-release] retries=$HEALTHCHECK_RETRIES timeout=${HEALTHCHECK_TIMEOUT}s"

if health_execute_validation "$health_url" "$HEALTHCHECK_RETRIES" "$HEALTHCHECK_TIMEOUT"; then
  echo "[validate-release] status=passed service=$service_name candidate_port=$candidate_port"
  exit 0
fi

echo "[validate-release] status=failed reason=healthcheck_failed service=$service_name candidate_port=$candidate_port" >&2
exit 1
