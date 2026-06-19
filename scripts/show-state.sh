#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_CONFIG_FILE="${SERVICE_CONFIG_FILE:-$ROOT_DIR/config/services.yml}"

# shellcheck source=scripts/lib/service-discovery.sh
source "$ROOT_DIR/scripts/lib/service-discovery.sh"
# shellcheck source=scripts/lib/state.sh
source "$ROOT_DIR/scripts/lib/state.sh"

usage() {
  cat <<'USAGE'
Usage: ./scripts/show-state.sh <service_name>

Shows current filesystem state for one registered service.
USAGE
}

if [[ "$#" -ne 1 ]]; then
  usage
  exit 1
fi

service_name="$1"

if [[ -z "$(service_discovery_get_service "$service_name" "$SERVICE_CONFIG_FILE")" ]]; then
  echo "[show-state] ERROR: service is not registered: $service_name" >&2
  exit 1
fi

deploy_path="$(state_resolve_service_deploy_path "$service_name" "$SERVICE_CONFIG_FILE")"
active_color_file="$(state_active_color_file "$service_name" "$SERVICE_CONFIG_FILE")"
lock_file="$(state_lock_file "$service_name" "$SERVICE_CONFIG_FILE")"
history_file="$(state_history_file "$service_name" "$SERVICE_CONFIG_FILE")"
current_link="$(state_current_link "$service_name" "$SERVICE_CONFIG_FILE")"

active_color="not initialized"
inactive_color="not initialized"
if [[ -f "$active_color_file" ]]; then
  active_color="$(state_read_active_color "$service_name" "$SERVICE_CONFIG_FILE")"
  inactive_color="$(state_determine_inactive_color "$service_name" "$SERVICE_CONFIG_FILE")"
fi

current_target="not present"
if [[ -L "$current_link" ]]; then
  current_target="$(readlink "$current_link")"
elif [[ -e "$current_link" ]]; then
  current_target="present but not a symlink"
fi

last_history="not present"
if [[ -s "$history_file" ]]; then
  last_history="$(state_read_latest_release_history "$service_name" "$SERVICE_CONFIG_FILE")"
elif [[ -f "$history_file" ]]; then
  last_history="empty"
fi

lock_status="unlocked"
if [[ -e "$lock_file" ]]; then
  lock_status="locked ($lock_file)"
fi

cat <<EOF
service name: $service_name
deploy path: $deploy_path
active color: $active_color
inactive color: $inactive_color
current symlink target: $current_target
last release history entry: $last_history
lock status: $lock_status
EOF
