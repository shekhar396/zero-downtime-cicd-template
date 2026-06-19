#!/usr/bin/env bash
# State helpers for v1.0.0 Linux VM blue/green foundations.
# This library manages filesystem state only; it does not deploy, switch traffic,
# reload NGINX, or roll back releases.

set -euo pipefail

STATE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_ROOT_DIR="$(cd "$STATE_LIB_DIR/../.." && pwd)"

# shellcheck source=scripts/lib/service-discovery.sh
source "$STATE_ROOT_DIR/scripts/lib/service-discovery.sh"

STATE_DEFAULT_ACTIVE_COLOR="${STATE_DEFAULT_ACTIVE_COLOR:-blue}"

_state_error() {
  echo "[state] ERROR: $*" >&2
}

_state_require_service() {
  local service_name="${1:-}"

  if [[ -z "$service_name" ]]; then
    _state_error "service name is required"
    return 1
  fi
}

_state_require_color() {
  local color="${1:-}"

  case "$color" in
    blue|green)
      return 0
      ;;
    *)
      _state_error "active color must be blue or green: ${color:-<empty>}"
      return 1
      ;;
  esac
}

_state_service_definition() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  local service_definition

  service_definition="$(service_discovery_get_service "$service_name" "$config_file")"
  if [[ -z "$service_definition" ]]; then
    _state_error "service is not registered: $service_name"
    return 1
  fi

  printf '%s\n' "$service_definition"
}

state_resolve_service_deploy_path() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"

  _state_require_service "$service_name"

  _state_service_definition "$service_name" "$config_file" | awk -F= '$1 == "deploy_path" { print substr($0, length($1) + 2); found = 1 } END { exit found ? 0 : 1 }'
}

state_service_state_dir() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  local deploy_path

  deploy_path="$(state_resolve_service_deploy_path "$service_name" "$config_file")"
  printf '%s/state\n' "$deploy_path"
}

state_service_releases_dir() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  local deploy_path

  deploy_path="$(state_resolve_service_deploy_path "$service_name" "$config_file")"
  printf '%s/releases\n' "$deploy_path"
}

state_service_shared_dir() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  local deploy_path

  deploy_path="$(state_resolve_service_deploy_path "$service_name" "$config_file")"
  printf '%s/shared\n' "$deploy_path"
}

state_active_color_file() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  printf '%s/active_color\n' "$(state_service_state_dir "$service_name" "$config_file")"
}

state_lock_file() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  printf '%s/deploy.lock\n' "$(state_service_state_dir "$service_name" "$config_file")"
}

state_history_file() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  printf '%s/history.log\n' "$(state_service_state_dir "$service_name" "$config_file")"
}

state_current_link() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  local deploy_path

  deploy_path="$(state_resolve_service_deploy_path "$service_name" "$config_file")"
  printf '%s/current\n' "$deploy_path"
}

state_initialize_service_directories() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  local deploy_path releases_dir shared_dir state_dir active_color_file history_file

  _state_require_service "$service_name"
  deploy_path="$(state_resolve_service_deploy_path "$service_name" "$config_file")"
  releases_dir="$deploy_path/releases"
  shared_dir="$deploy_path/shared"
  state_dir="$deploy_path/state"
  active_color_file="$state_dir/active_color"
  history_file="$state_dir/history.log"

  mkdir -p "$releases_dir" "$shared_dir" "$state_dir"

  if [[ ! -e "$active_color_file" ]]; then
    printf '%s\n' "$STATE_DEFAULT_ACTIVE_COLOR" > "$active_color_file"
  fi

  if [[ ! -e "$history_file" ]]; then
    : > "$history_file"
  fi
}

state_read_active_color() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  local active_color_file active_color

  active_color_file="$(state_active_color_file "$service_name" "$config_file")"
  if [[ ! -f "$active_color_file" ]]; then
    _state_error "active color file does not exist for $service_name: $active_color_file"
    return 1
  fi

  active_color="$(tr -d '[:space:]' < "$active_color_file")"
  _state_require_color "$active_color"
  printf '%s\n' "$active_color"
}

state_write_active_color() {
  local service_name="$1"
  local color="$2"
  local config_file="${3:-$SERVICE_CONFIG_FILE}"
  local active_color_file tmp_file

  _state_require_color "$color"
  active_color_file="$(state_active_color_file "$service_name" "$config_file")"
  mkdir -p "$(dirname "$active_color_file")"

  tmp_file="${active_color_file}.tmp.$$"
  printf '%s\n' "$color" > "$tmp_file"
  mv "$tmp_file" "$active_color_file"
}

state_determine_inactive_color() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  local active_color

  active_color="$(state_read_active_color "$service_name" "$config_file")"
  case "$active_color" in
    blue)
      printf 'green\n'
      ;;
    green)
      printf 'blue\n'
      ;;
  esac
}

state_create_deployment_lock() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  local lock_file

  lock_file="$(state_lock_file "$service_name" "$config_file")"
  mkdir -p "$(dirname "$lock_file")"

  if (
    set -o noclobber
    printf 'pid=%s created_at=%s service=%s\n' "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$service_name" > "$lock_file"
  ) 2>/dev/null; then
    return 0
  fi

  _state_error "deployment lock already exists for $service_name: $lock_file"
  return 1
}

state_release_deployment_lock() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  local lock_file

  lock_file="$(state_lock_file "$service_name" "$config_file")"
  if [[ -e "$lock_file" ]]; then
    rm -f -- "$lock_file"
  fi
}

state_append_release_history() {
  local service_name="$1"
  local entry="$2"
  local config_file="${3:-$SERVICE_CONFIG_FILE}"
  local history_file timestamp

  if [[ -z "$entry" ]]; then
    _state_error "release history entry cannot be empty"
    return 1
  fi

  history_file="$(state_history_file "$service_name" "$config_file")"
  mkdir -p "$(dirname "$history_file")"
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s service=%s %s\n' "$timestamp" "$service_name" "$entry" >> "$history_file"
}

state_read_latest_release_history() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  local history_file

  history_file="$(state_history_file "$service_name" "$config_file")"
  if [[ ! -s "$history_file" ]]; then
    return 0
  fi

  tail -n 1 "$history_file"
}
