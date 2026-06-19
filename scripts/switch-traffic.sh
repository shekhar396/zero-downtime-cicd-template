#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_CONFIG_FILE="${SERVICE_CONFIG_FILE:-$ROOT_DIR/config/services.yml}"
NGINX_INSTALL_DIR="${NGINX_INSTALL_DIR:-$ROOT_DIR/build/nginx-installed}"
NGINX_RELOAD_CMD="${NGINX_RELOAD_CMD:-nginx -s reload}"
APACHE_CONFIG_DIR="${APACHE_CONFIG_DIR:-$ROOT_DIR/build/apache-installed}"
APACHE_RELOAD_CMD="${APACHE_RELOAD_CMD:-apache2ctl graceful}"
NGINX_SWITCH_BUILD_DIR="${NGINX_SWITCH_BUILD_DIR:-$ROOT_DIR/build/nginx-switch}"
APACHE_SWITCH_BUILD_DIR="${APACHE_SWITCH_BUILD_DIR:-$ROOT_DIR/build/apache-switch}"
dry_run="no"

source "$ROOT_DIR/scripts/lib/service-discovery.sh"
source "$ROOT_DIR/scripts/lib/state.sh"
source "$ROOT_DIR/scripts/lib/runtime.sh"
source "$ROOT_DIR/scripts/lib/nginx.sh"
source "$ROOT_DIR/scripts/lib/apache.sh"
source "$ROOT_DIR/scripts/lib/health.sh"

usage() {
  cat <<'USAGE'
Usage: ./scripts/switch-traffic.sh <service_name> <target_color> [--dry-run]

Controlled traffic switch for one service. proxy_runtime defaults to nginx and
may be set to apache per service. Dry-run validates config/state where present,
generates candidate config, and shows intended install/reload actions without
copying config, reloading the proxy, or updating active_color.
USAGE
}

fail() {
  echo "[switch-traffic] ERROR: $*" >&2
  exit 1
}

warn() {
  echo "[switch-traffic] WARN: $*" >&2
}

require_color() {
  case "${1:-}" in
    blue|green) ;;
    *) fail "target_color must be blue or green: ${1:-<empty>}" ;;
  esac
}

service_field_optional() {
  local service_name="$1" field_name="$2" config_file="${3:-$SERVICE_CONFIG_FILE}"
  service_discovery_get_service "$service_name" "$config_file" | awk -F= -v field="$field_name" '$1 == field { print substr($0, length($1) + 2); found = 1 } END { exit found ? 0 : 1 }' 2>/dev/null || true
}

resolve_proxy_runtime() {
  local service_name="$1" config_file="${2:-$SERVICE_CONFIG_FILE}" proxy_runtime
  proxy_runtime="$(service_field_optional "$service_name" proxy_runtime "$config_file")"
  if [[ -z "$proxy_runtime" ]]; then
    proxy_runtime="nginx"
  fi
  case "$proxy_runtime" in
    nginx|apache) printf '%s\n' "$proxy_runtime" ;;
    *) fail "proxy_runtime must be nginx or apache for $service_name: $proxy_runtime" ;;
  esac
}

target_runtime_running() {
  local service_name="$1" color="$2" runtime container_name running status_command output exit_code
  runtime="$(runtime_resolve_runtime "$service_name" "$SERVICE_CONFIG_FILE")"
  case "$runtime" in
    container)
      runtime_require_container_runtime
      container_name="$(runtime_container_name "$service_name" "$color")"
      if ! docker container inspect "$container_name" >/dev/null 2>&1; then
        fail "target container does not exist: $container_name"
      fi
      running="$(docker inspect -f '{{.State.Running}}' "$container_name")"
      [[ "$running" == "true" ]] || fail "target container is not running: $container_name"
      ;;
    systemd)
      status_command="$(runtime_systemd_command "$service_name" "$color" status_command "" "$SERVICE_CONFIG_FILE")"
      set +e
      output="$(bash -c "$status_command" 2>&1)"
      exit_code="$?"
      set -e
      [[ "$exit_code" -eq 0 ]] || fail "target systemd service is not active for $service_name/$color: command='$status_command' output='${output:-<empty>}'"
      ;;
    *)
      fail "unsupported runtime: $runtime"
      ;;
  esac
}

generate_proxy_config_for_color() {
  local proxy_runtime="$1" service_name="$2" color="$3"
  case "$proxy_runtime" in
    nginx) nginx_generate_service_config_for_color "$service_name" "$color" "$NGINX_SWITCH_BUILD_DIR" "$SERVICE_CONFIG_FILE" ;;
    apache) apache_generate_service_config_for_color "$service_name" "$color" "$APACHE_SWITCH_BUILD_DIR" "$SERVICE_CONFIG_FILE" ;;
  esac
}

validate_proxy_dir() {
  local proxy_runtime="$1" config_dir="$2"
  case "$proxy_runtime" in
    nginx) "$ROOT_DIR/scripts/validate-nginx.sh" "$config_dir" >/dev/null ;;
    apache) "$ROOT_DIR/scripts/validate-apache.sh" "$config_dir" >/dev/null ;;
  esac
}

proxy_build_dir() {
  case "$1" in
    nginx) printf '%s\n' "$NGINX_SWITCH_BUILD_DIR" ;;
    apache) printf '%s\n' "$APACHE_SWITCH_BUILD_DIR" ;;
  esac
}

proxy_install_dir() {
  case "$1" in
    nginx) printf '%s\n' "$NGINX_INSTALL_DIR" ;;
    apache) printf '%s\n' "$APACHE_CONFIG_DIR" ;;
  esac
}

proxy_reload_cmd() {
  case "$1" in
    nginx) printf '%s\n' "$NGINX_RELOAD_CMD" ;;
    apache) printf '%s\n' "$APACHE_RELOAD_CMD" ;;
  esac
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

proxy_runtime="$(resolve_proxy_runtime "$service_name" "$SERVICE_CONFIG_FILE")"
install_dir="$(proxy_install_dir "$proxy_runtime")"
reload_cmd="$(proxy_reload_cmd "$proxy_runtime")"
build_dir="$(proxy_build_dir "$proxy_runtime")"
state_dir="$(state_service_state_dir "$service_name" "$SERVICE_CONFIG_FILE")"
active_color_file="$(state_active_color_file "$service_name" "$SERVICE_CONFIG_FILE")"
active_before="unknown"

if [[ -d "$state_dir" && -f "$active_color_file" ]]; then
  active_before="$(state_read_active_color "$service_name" "$SERVICE_CONFIG_FILE")"
elif [[ "$dry_run" == "yes" ]]; then
  warn "service state is not initialized for $service_name; dry-run will not read active_color"
else
  fail "service state is not initialized for $service_name; run ./scripts/init-service.sh $service_name"
fi

target_port="$(runtime_resolve_color_port "$service_name" "$target_color" "$SERVICE_CONFIG_FILE")"
health_path="$(runtime_service_field "$service_name" health_path "$SERVICE_CONFIG_FILE")"
health_url="$(health_build_url "$target_port" "$health_path")"

echo "[switch-traffic] proxy_runtime=$proxy_runtime"
echo "[switch-traffic] active_color_before=$active_before"
echo "[switch-traffic] target_port=$target_port"
echo "[switch-traffic] health_url=$health_url"
echo "[switch-traffic] install_dir=$install_dir"
echo "[switch-traffic] reload_cmd=$reload_cmd"

if [[ "$dry_run" == "yes" ]]; then
  echo "[switch-traffic] step=generate_${proxy_runtime}"
  generated_file="$(generate_proxy_config_for_color "$proxy_runtime" "$service_name" "$target_color")"
  echo "[switch-traffic] generated=$generated_file"
  validate_proxy_dir "$proxy_runtime" "$build_dir"
  echo "[switch-traffic] dry_run=passed"
  echo "[switch-traffic] note=no runtime status check, health call, config install, proxy reload, or active_color update was performed"
  exit 0
fi

target_runtime_running "$service_name" "$target_color"
echo "[switch-traffic] step=health_check"
"$ROOT_DIR/scripts/healthcheck.sh" "$health_url"

echo "[switch-traffic] step=generate_${proxy_runtime}"
generated_file="$(generate_proxy_config_for_color "$proxy_runtime" "$service_name" "$target_color")"
echo "[switch-traffic] generated=$generated_file"

echo "[switch-traffic] step=install_generated_config"
mkdir -p "$install_dir"
installed_file="$install_dir/$service_name.conf"
cp "$generated_file" "$installed_file"
echo "[switch-traffic] installed=$installed_file"

echo "[switch-traffic] step=validate_${proxy_runtime}"
validate_proxy_dir "$proxy_runtime" "$install_dir"

echo "[switch-traffic] step=reload_${proxy_runtime}"
bash -c "$reload_cmd"

echo "[switch-traffic] step=update_active_color"
state_write_active_color "$service_name" "$target_color" "$SERVICE_CONFIG_FILE"
state_append_release_history "$service_name" "event=traffic_switch proxy_runtime=$proxy_runtime target_color=$target_color previous_color=$active_before proxy_config=$installed_file" "$SERVICE_CONFIG_FILE"

echo "[switch-traffic] status=switched service=$service_name proxy_runtime=$proxy_runtime active_color=$target_color previous_color=$active_before"
echo "[switch-traffic] note=old color remains running until explicitly stopped; no rollback or Jenkins action was performed"
