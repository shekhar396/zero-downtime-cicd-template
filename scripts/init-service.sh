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
Usage: ./scripts/init-service.sh <service_name>

Initializes the release/state directory structure for one registered service.
USAGE
}

if [[ "$#" -ne 1 ]]; then
  usage
  exit 1
fi

service_name="$1"

echo "[init-service] Validating service configuration..."
"$ROOT_DIR/scripts/validate-config.sh" "$SERVICE_CONFIG_FILE" >/dev/null

if [[ -z "$(service_discovery_get_service "$service_name" "$SERVICE_CONFIG_FILE")" ]]; then
  echo "[init-service] ERROR: service is not registered: $service_name" >&2
  exit 1
fi

deploy_path="$(state_resolve_service_deploy_path "$service_name" "$SERVICE_CONFIG_FILE")"
active_color_file="$(state_active_color_file "$service_name" "$SERVICE_CONFIG_FILE")"
history_file="$(state_history_file "$service_name" "$SERVICE_CONFIG_FILE")"

active_existed="no"
history_existed="no"
[[ -e "$active_color_file" ]] && active_existed="yes"
[[ -e "$history_file" ]] && history_existed="yes"

echo "[init-service] Initializing service: $service_name"
echo "[init-service] Deploy path: $deploy_path"
state_initialize_service_directories "$service_name" "$SERVICE_CONFIG_FILE"

active_color="$(state_read_active_color "$service_name" "$SERVICE_CONFIG_FILE")"
inactive_color="$(state_determine_inactive_color "$service_name" "$SERVICE_CONFIG_FILE")"

echo "[init-service] Ensured directories:"
echo "  - $deploy_path/releases"
echo "  - $deploy_path/shared"
echo "  - $deploy_path/state"

if [[ "$active_existed" == "yes" ]]; then
  echo "[init-service] Preserved existing active color: $active_color"
else
  echo "[init-service] Initialized active color: $active_color"
fi

if [[ "$history_existed" == "yes" ]]; then
  echo "[init-service] Preserved existing history file: $history_file"
else
  echo "[init-service] Created empty history file: $history_file"
fi

echo "[init-service] Inactive color: $inactive_color"
echo "[init-service] Done. No deployment was performed."
