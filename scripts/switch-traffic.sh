#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_CONFIG_FILE="${SERVICE_CONFIG_FILE:-$ROOT_DIR/config/services.yml}"
NGINX_INSTALL_DIR="${NGINX_INSTALL_DIR:-$ROOT_DIR/build/nginx-installed}"
NGINX_RELOAD_CMD="${NGINX_RELOAD_CMD:-nginx -s reload}"
SWITCH_BUILD_DIR="${SWITCH_BUILD_DIR:-$ROOT_DIR/build/nginx-switch}"
dry_run="no"

source "$ROOT_DIR/scripts/lib/service-discovery.sh"
source "$ROOT_DIR/scripts/lib/state.sh"
source "$ROOT_DIR/scripts/lib/runtime.sh"
source "$ROOT_DIR/scripts/lib/nginx.sh"
source "$ROOT_DIR/scripts/lib/health.sh"

usage() {
  cat <<'USAGE'
Usage: ./scripts/switch-traffic.sh <service_name> <target_color> [--dry-run]

Controlled NGINX traffic switch for one service. Dry-run validates config/state,
generates candidate config, and shows intended install/reload actions without
copying config, reloading NGINX, or updating active_color.
USAGE
}

fail() {
  echo "[switch-traffic] ERROR: $*" >&2
  exit 1
}

require_color() {
  case "${1:-}" in
    blue|green) ;;
    *) fail "target_color must be blue or green: ${1:-<empty>}" ;;
  esac
}

container_running() {
  local service_name="$1" color="$2" container_name runtime running
  runtime="$(runtime_resolve_runtime "$service_name" "$SERVICE_CONFIG_FILE")"
  runtime_require_container_runtime "$runtime"
  container_name="$(runtime_container_name "$service_name" "$color")"
  if ! docker container inspect "$container_name" >/dev/null 2>&1; then
    fail "target container does not exist: $container_name"
  fi
  running="$(docker inspect -f '{{.State.Running}}' "$container_name")"
  [[ "$running" == "true" ]] || fail "target container is not running: $container_name"
}

if [[ "$#" -lt 2 || "$#" -gt 3 ]]; then
  usage
  exit 2
fi

service_name="$1"
target_color="$2"
shift 2

if [[ "$#" -eq 1 ]]; then
  case "$1" in
    --dry-run) dry_run="yes" ;;
    *) echo "[switch-traffic] ERROR: unknown argument: $1" >&2; usage; exit 2 ;;
  esac
fi

require_color "$target_color"

echo "[switch-traffic] event=switch_start service=$service_name target_color=$target_color dry_run=$dry_run"
echo "[switch-traffic] step=validate_config"
"$ROOT_DIR/scripts/validate-config.sh" "$SERVICE_CONFIG_FILE" >/dev/null

if [[ -z "$(service_discovery_get_service "$service_name" "$SERVICE_CONFIG_FILE")" ]]; then
  echo "[switch-traffic] ERROR: service is not registered: $service_name" >&2
  exit 2
fi

state_dir="$(state_service_state_dir "$service_name" "$SERVICE_CONFIG_FILE")"
active_color_file="$(state_active_color_file "$service_name" "$SERVICE_CONFIG_FILE")"
[[ -d "$state_dir" && -f "$active_color_file" ]] || fail "service state is not initialized for $service_name; run ./scripts/init-service.sh $service_name"

active_before="$(state_read_active_color "$service_name" "$SERVICE_CONFIG_FILE")"
target_port="$(runtime_resolve_color_port "$service_name" "$target_color" "$SERVICE_CONFIG_FILE")"
health_path="$(runtime_service_field "$service_name" health_path "$SERVICE_CONFIG_FILE")"
health_url="$(health_build_url "$target_port" "$health_path")"

echo "[switch-traffic] active_color_before=$active_before"
echo "[switch-traffic] target_port=$target_port"
echo "[switch-traffic] health_url=$health_url"
echo "[switch-traffic] install_dir=$NGINX_INSTALL_DIR"
echo "[switch-traffic] reload_cmd=$NGINX_RELOAD_CMD"

if [[ "$dry_run" == "yes" ]]; then
  if command -v docker >/dev/null 2>&1; then
    container_running "$service_name" "$target_color"
    "$ROOT_DIR/scripts/healthcheck.sh" "$health_url"
  else
    echo "[switch-traffic] WARN: docker is not installed; dry-run skipped container running and live health checks" >&2
  fi
  generated_file="$(nginx_generate_service_config_for_color "$service_name" "$target_color" "$SWITCH_BUILD_DIR" "$SERVICE_CONFIG_FILE")"
  echo "[switch-traffic] generated=$generated_file"
  "$ROOT_DIR/scripts/validate-nginx.sh" "$SWITCH_BUILD_DIR" >/dev/null
  echo "[switch-traffic] dry_run=passed"
  echo "[switch-traffic] note=no config install, nginx reload, or active_color update was performed"
  exit 0
fi

container_running "$service_name" "$target_color"
echo "[switch-traffic] step=health_check"
"$ROOT_DIR/scripts/healthcheck.sh" "$health_url"

generated_file="$(nginx_generate_service_config_for_color "$service_name" "$target_color" "$SWITCH_BUILD_DIR" "$SERVICE_CONFIG_FILE")"
echo "[switch-traffic] generated=$generated_file"

echo "[switch-traffic] step=install_generated_config"
mkdir -p "$NGINX_INSTALL_DIR"
installed_file="$NGINX_INSTALL_DIR/$service_name.conf"
cp "$generated_file" "$installed_file"
echo "[switch-traffic] installed=$installed_file"

echo "[switch-traffic] step=validate_nginx"
"$ROOT_DIR/scripts/validate-nginx.sh" "$NGINX_INSTALL_DIR" >/dev/null

echo "[switch-traffic] step=reload_nginx"
bash -c "$NGINX_RELOAD_CMD"

echo "[switch-traffic] step=update_active_color"
state_write_active_color "$service_name" "$target_color" "$SERVICE_CONFIG_FILE"
state_append_release_history "$service_name" "event=traffic_switch target_color=$target_color previous_color=$active_before nginx_config=$installed_file" "$SERVICE_CONFIG_FILE"

echo "[switch-traffic] status=switched service=$service_name active_color=$target_color previous_color=$active_before"
echo "[switch-traffic] note=old color remains running until explicitly stopped; no rollback or Jenkins action was performed"
