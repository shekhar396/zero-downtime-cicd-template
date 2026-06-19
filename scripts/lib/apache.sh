#!/usr/bin/env bash
set -euo pipefail

APACHE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APACHE_ROOT_DIR="$(cd "$APACHE_LIB_DIR/../.." && pwd)"
APACHE_TEMPLATE_FILE="${APACHE_TEMPLATE_FILE:-$APACHE_ROOT_DIR/apache/templates/service.conf.tpl}"
APACHE_DEFAULT_OUTPUT_DIR="${APACHE_DEFAULT_OUTPUT_DIR:-$APACHE_ROOT_DIR/build/apache}"

source "$APACHE_ROOT_DIR/scripts/lib/service-discovery.sh"
source "$APACHE_ROOT_DIR/scripts/lib/state.sh"

apache_error() { echo "[apache] ERROR: $*" >&2; }
apache_warn() { echo "[apache] WARN: $*" >&2; }

apache_service_field() {
  local service_name="$1" field_name="$2" config_file="${3:-$SERVICE_CONFIG_FILE}"
  service_discovery_get_service "$service_name" "$config_file" | awk -F= -v field="$field_name" '$1 == field { print substr($0, length($1) + 2); found = 1 } END { exit found ? 0 : 1 }'
}

apache_optional_service_field() {
  apache_service_field "$1" "$2" "${3:-$SERVICE_CONFIG_FILE}" 2>/dev/null || true
}

apache_resolve_color_port() {
  local service_name="$1" color="$2" config_file="${3:-$SERVICE_CONFIG_FILE}"
  case "$color" in blue|green) ;; *) apache_error "color must be blue or green: ${color:-<empty>}"; return 1 ;; esac
  apache_service_field "$service_name" "${color}_port" "$config_file"
}

apache_resolve_active_color() { state_read_active_color "$1" "${2:-$SERVICE_CONFIG_FILE}"; }

apache_resolve_active_upstream_port() {
  local service_name="$1" config_file="${2:-$SERVICE_CONFIG_FILE}" active_color
  active_color="$(apache_resolve_active_color "$service_name" "$config_file")"
  apache_resolve_color_port "$service_name" "$active_color" "$config_file"
}

apache_render_template() {
  local service_name="$1" output_file="$2" config_file="${3:-$SERVICE_CONFIG_FILE}" target_color="${4:-}"
  local active_color active_upstream_port server_name
  [[ -f "$APACHE_TEMPLATE_FILE" ]] || { apache_error "template not found: $APACHE_TEMPLATE_FILE"; return 1; }
  if [[ -n "$target_color" ]]; then
    case "$target_color" in blue|green) ;; *) apache_error "target color must be blue or green: $target_color"; return 1 ;; esac
    active_color="$target_color"
    active_upstream_port="$(apache_resolve_color_port "$service_name" "$target_color" "$config_file")"
  else
    active_color="$(apache_resolve_active_color "$service_name" "$config_file")"
    active_upstream_port="$(apache_resolve_active_upstream_port "$service_name" "$config_file")"
  fi
  server_name="$(apache_optional_service_field "$service_name" apache_server_name "$config_file")"
  if [[ -z "$server_name" ]]; then
    server_name="$(apache_optional_service_field "$service_name" nginx_server_name "$config_file")"
  fi
  if [[ -z "$server_name" || "$server_name" == "_" ]]; then
    server_name="localhost"
  fi
  mkdir -p "$(dirname "$output_file")"
  sed -e "s|{{service_name}}|$service_name|g" \
    -e "s|{{active_color}}|$active_color|g" \
    -e "s|{{active_upstream_port}}|$active_upstream_port|g" \
    -e "s|{{apache_server_name}}|$server_name|g" \
    "$APACHE_TEMPLATE_FILE" > "$output_file"
}

apache_generate_service_config() {
  local service_name="$1" output_dir="${2:-$APACHE_DEFAULT_OUTPUT_DIR}" config_file="${3:-$SERVICE_CONFIG_FILE}"
  local output_file state_dir active_color_file
  [[ -n "$(service_discovery_get_service "$service_name" "$config_file")" ]] || { apache_error "service is not registered: $service_name"; return 1; }
  state_dir="$(state_service_state_dir "$service_name" "$config_file")"
  active_color_file="$(state_active_color_file "$service_name" "$config_file")"
  output_file="$output_dir/$service_name.conf"
  if [[ -d "$state_dir" && -f "$active_color_file" ]]; then
    apache_render_template "$service_name" "$output_file" "$config_file"
  else
    apache_warn "service state is not initialized for $service_name; generating with blue as the default active color"
    apache_render_template "$service_name" "$output_file" "$config_file" blue
  fi
  printf '%s\n' "$output_file"
}

apache_generate_service_config_for_color() {
  local service_name="$1" target_color="$2" output_dir="${3:-$APACHE_DEFAULT_OUTPUT_DIR}" config_file="${4:-$SERVICE_CONFIG_FILE}"
  local output_file
  [[ -n "$(service_discovery_get_service "$service_name" "$config_file")" ]] || { apache_error "service is not registered: $service_name"; return 1; }
  output_file="$output_dir/$service_name.conf"
  apache_render_template "$service_name" "$output_file" "$config_file" "$target_color"
  printf '%s\n' "$output_file"
}

apache_generate_all_configs() {
  local output_dir="${1:-$APACHE_DEFAULT_OUTPUT_DIR}" config_file="${2:-$SERVICE_CONFIG_FILE}" service_name
  while IFS= read -r service_name; do
    [[ -z "$service_name" ]] && continue
    apache_generate_service_config "$service_name" "$output_dir" "$config_file"
  done < <(service_discovery_list_services "$config_file")
}

apache_static_validate_file() {
  local file="$1" errors=0
  [[ -s "$file" ]] || { apache_error "generated config is empty: $file"; return 1; }
  grep -q 'Generated by zero-downtime-cicd-template' "$file" || { apache_error "missing generated header: $file"; errors=$((errors + 1)); }
  grep -q '<VirtualHost \*:80>' "$file" || { apache_error "missing VirtualHost *:80: $file"; errors=$((errors + 1)); }
  grep -q 'ServerName ' "$file" || { apache_error "missing ServerName: $file"; errors=$((errors + 1)); }
  grep -q 'ProxyPreserveHost On' "$file" || { apache_error "missing ProxyPreserveHost: $file"; errors=$((errors + 1)); }
  grep -q 'ProxyPass / http://127.0.0.1:' "$file" || { apache_error "missing ProxyPass upstream: $file"; errors=$((errors + 1)); }
  grep -q 'ProxyPassReverse / http://127.0.0.1:' "$file" || { apache_error "missing ProxyPassReverse upstream: $file"; errors=$((errors + 1)); }
  grep -q 'RequestHeader set X-Forwarded-Proto' "$file" || { apache_error "missing RequestHeader X-Forwarded-Proto: $file"; errors=$((errors + 1)); }
  grep -q '</VirtualHost>' "$file" || { apache_error "missing closing VirtualHost: $file"; errors=$((errors + 1)); }
  return "$errors"
}

apache_is_generated_file() {
  local file="$1"
  grep -q 'Generated by zero-downtime-cicd-template' "$file"
}

apache_syntax_validate() {
  if ! command -v apache2ctl >/dev/null 2>&1; then
    apache_warn "apache2ctl is not installed; static validation passed but apache2ctl -t was skipped"
    return 0
  fi
  apache2ctl -t >/dev/null
}

apache_validate_generated_file() {
  local config_file="$1"
  [[ -f "$config_file" ]] || { apache_error "config file not found: $config_file"; return 1; }
  [[ "$config_file" == *.conf ]] || { apache_error "config file must end with .conf: $config_file"; return 1; }
  apache_static_validate_file "$config_file" || return 1
  apache_syntax_validate
}

apache_validate_generated_dir() {
  local config_dir="$1" file found=0 errors=0
  [[ -d "$config_dir" ]] || { apache_error "config directory not found: $config_dir"; return 1; }
  config_dir="$(cd "$config_dir" && pwd)"
  while IFS= read -r file; do
    apache_is_generated_file "$file" || continue
    found=1
    apache_static_validate_file "$file" || errors=$((errors + 1))
  done < <(find "$config_dir" -maxdepth 1 -type f -name '*.conf' | sort)
  if [[ "$found" -ne 1 ]]; then
    apache_warn "no generated zero-downtime .conf files found in $config_dir; static validation skipped"
  fi
  [[ "$errors" -eq 0 ]] || return 1
  apache_syntax_validate
}

apache_validate_generated_path() {
  local config_path="$1"
  if [[ -f "$config_path" ]]; then
    apache_validate_generated_file "$config_path"
  elif [[ -d "$config_path" ]]; then
    apache_validate_generated_dir "$config_path"
  else
    apache_error "config path not found: $config_path"
    return 1
  fi
}
