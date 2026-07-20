#!/usr/bin/env bash
set -euo pipefail

NGINX_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_ROOT_DIR="$(cd "$NGINX_LIB_DIR/../.." && pwd)"
NGINX_TEMPLATE_FILE="${NGINX_TEMPLATE_FILE:-$NGINX_ROOT_DIR/nginx/templates/service.conf.tpl}"
NGINX_DEFAULT_OUTPUT_DIR="${NGINX_DEFAULT_OUTPUT_DIR:-$NGINX_ROOT_DIR/build/nginx}"

source "$NGINX_ROOT_DIR/scripts/lib/service-discovery.sh"
source "$NGINX_ROOT_DIR/scripts/lib/state.sh"

nginx_error() { echo "[nginx] ERROR: $*" >&2; }
nginx_warn() { echo "[nginx] WARN: $*" >&2; }

nginx_service_field() {
  local service_name="$1" field_name="$2" config_file="${3:-$SERVICE_CONFIG_FILE}"
  service_discovery_get_service "$service_name" "$config_file" | awk -F= -v field="$field_name" '$1 == field { print substr($0, length($1) + 2); found = 1 } END { exit found ? 0 : 1 }'
}

nginx_resolve_public_port() { nginx_service_field "$1" public_port "${2:-$SERVICE_CONFIG_FILE}"; }

nginx_resolve_color_port() {
  local service_name="$1" color="$2" config_file="${3:-$SERVICE_CONFIG_FILE}"
  case "$color" in blue|green) ;; *) nginx_error "color must be blue or green: ${color:-<empty>}"; return 1 ;; esac
  nginx_service_field "$service_name" "${color}_port" "$config_file"
}

nginx_resolve_active_color() { state_read_active_color "$1" "${2:-$SERVICE_CONFIG_FILE}"; }

nginx_resolve_active_upstream_port() {
  local service_name="$1" config_file="${2:-$SERVICE_CONFIG_FILE}" active_color
  active_color="$(nginx_resolve_active_color "$service_name" "$config_file")"
  nginx_resolve_color_port "$service_name" "$active_color" "$config_file"
}

nginx_render_template() {
  local service_name="$1" output_file="$2" config_file="${3:-$SERVICE_CONFIG_FILE}" target_color="${4:-}"
  local public_port blue_port green_port active_color active_upstream_port health_path nginx_server_name
  [[ -f "$NGINX_TEMPLATE_FILE" ]] || { nginx_error "template not found: $NGINX_TEMPLATE_FILE"; return 1; }
  public_port="$(nginx_resolve_public_port "$service_name" "$config_file")"
  blue_port="$(nginx_resolve_color_port "$service_name" blue "$config_file")"
  green_port="$(nginx_resolve_color_port "$service_name" green "$config_file")"
  if [[ -n "$target_color" ]]; then
    case "$target_color" in blue|green) ;; *) nginx_error "target color must be blue or green: $target_color"; return 1 ;; esac
    active_color="$target_color"
    active_upstream_port="$(nginx_resolve_color_port "$service_name" "$target_color" "$config_file")"
  else
    active_color="$(nginx_resolve_active_color "$service_name" "$config_file")"
    active_upstream_port="$(nginx_resolve_active_upstream_port "$service_name" "$config_file")"
  fi
  health_path="$(nginx_service_field "$service_name" health_path "$config_file")"
  nginx_server_name="$(nginx_service_field "$service_name" nginx_server_name "$config_file")"
  mkdir -p "$(dirname "$output_file")"
  sed -e "s|{{service_name}}|$service_name|g" \
    -e "s|{{public_port}}|$public_port|g" \
    -e "s|{{blue_port}}|$blue_port|g" \
    -e "s|{{green_port}}|$green_port|g" \
    -e "s|{{active_color}}|$active_color|g" \
    -e "s|{{active_upstream_port}}|$active_upstream_port|g" \
    -e "s|{{health_path}}|$health_path|g" \
    -e "s|{{nginx_server_name}}|$nginx_server_name|g" \
    "$NGINX_TEMPLATE_FILE" > "$output_file"
}

nginx_generate_service_config() {
  local service_name="$1" output_dir="${2:-$NGINX_DEFAULT_OUTPUT_DIR}" config_file="${3:-$SERVICE_CONFIG_FILE}"
  local output_file state_dir active_color_file
  [[ -n "$(service_discovery_get_service "$service_name" "$config_file")" ]] || { nginx_error "service is not registered: $service_name"; return 1; }
  state_dir="$(state_service_state_dir "$service_name" "$config_file")"
  active_color_file="$(state_active_color_file "$service_name" "$config_file")"
  [[ -d "$state_dir" && -f "$active_color_file" ]] || { nginx_error "service state is not initialized for $service_name; run ./scripts/init-service.sh $service_name"; return 1; }
  output_file="$output_dir/$service_name.conf"
  nginx_render_template "$service_name" "$output_file" "$config_file"
  printf '%s\n' "$output_file"
}

nginx_generate_service_config_for_color() {
  local service_name="$1" target_color="$2" output_dir="${3:-$NGINX_DEFAULT_OUTPUT_DIR}" config_file="${4:-$SERVICE_CONFIG_FILE}"
  local output_file state_dir active_color_file
  [[ -n "$(service_discovery_get_service "$service_name" "$config_file")" ]] || { nginx_error "service is not registered: $service_name"; return 1; }
  state_dir="$(state_service_state_dir "$service_name" "$config_file")"
  active_color_file="$(state_active_color_file "$service_name" "$config_file")"
  [[ -d "$state_dir" && -f "$active_color_file" ]] || { nginx_error "service state is not initialized for $service_name; run ./scripts/init-service.sh $service_name"; return 1; }
  output_file="$output_dir/$service_name.conf"
  nginx_render_template "$service_name" "$output_file" "$config_file" "$target_color"
  printf '%s\n' "$output_file"
}

nginx_generate_all_configs() {
  local output_dir="${1:-$NGINX_DEFAULT_OUTPUT_DIR}" config_file="${2:-$SERVICE_CONFIG_FILE}" service_name
  while IFS= read -r service_name; do
    [[ -z "$service_name" ]] && continue
    nginx_generate_service_config "$service_name" "$output_dir" "$config_file"
  done < <(service_discovery_list_services "$config_file")
}

nginx_static_validate_file() {
  local file="$1" errors=0
  [[ -s "$file" ]] || { nginx_error "generated config is empty: $file"; return 1; }
  grep -q 'Generated by zero-downtime-cicd-template' "$file" || { nginx_error "missing generated header: $file"; errors=$((errors + 1)); }
  grep -q '^upstream ' "$file" || { nginx_error "missing upstream block: $file"; errors=$((errors + 1)); }
  grep -q 'server 127.0.0.1:' "$file" || { nginx_error "missing local upstream server: $file"; errors=$((errors + 1)); }
  grep -q '^server {' "$file" || { nginx_error "missing server block: $file"; errors=$((errors + 1)); }
  grep -q 'proxy_set_header Host' "$file" || { nginx_error "missing proxy headers: $file"; errors=$((errors + 1)); }
  return "$errors"
}

nginx_validate_generated_dir() {
  local config_dir="$1" file found=0 errors=0 tmp_root tmp_conf
  [[ -d "$config_dir" ]] || { nginx_error "config directory not found: $config_dir"; return 1; }
  config_dir="$(cd "$config_dir" && pwd)"
  while IFS= read -r file; do
    found=1
    nginx_static_validate_file "$file" || errors=$((errors + 1))
  done < <(find "$config_dir" -maxdepth 1 -type f -name '*.conf' | sort)
  [[ "$found" -eq 1 ]] || { nginx_error "no generated .conf files found in $config_dir"; return 1; }
  [[ "$errors" -eq 0 ]] || return 1
  if ! command -v nginx >/dev/null 2>&1; then
    nginx_warn "nginx command is not installed; static validation passed but nginx -t was skipped"
    return 0
  fi
  tmp_root="$(mktemp -d)"
  tmp_conf="$tmp_root/nginx.conf"
  trap 'rm -rf "$tmp_root"' RETURN
  cat > "$tmp_conf" <<EOF
pid $tmp_root/nginx.pid;
events { worker_connections 128; }
http { include $config_dir/*.conf; }
EOF
  nginx -t -c "$tmp_conf" -p "$tmp_root" >/dev/null
  rm -rf "$tmp_root"
  trap - RETURN
}
