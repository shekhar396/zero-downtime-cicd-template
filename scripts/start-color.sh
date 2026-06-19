#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_CONFIG_FILE="${SERVICE_CONFIG_FILE:-$ROOT_DIR/config/services.yml}"

# shellcheck source=scripts/lib/service-discovery.sh
source "$ROOT_DIR/scripts/lib/service-discovery.sh"
# shellcheck source=scripts/lib/state.sh
source "$ROOT_DIR/scripts/lib/state.sh"
# shellcheck source=scripts/lib/runtime.sh
source "$ROOT_DIR/scripts/lib/runtime.sh"

usage() {
  cat <<'USAGE'
Usage: ./scripts/start-color.sh <service_name> <color> <release_id>

Starts one blue/green color runtime for an existing release artifact. For
runtime: container this starts Docker; for runtime: systemd this runs the
configured start_command. This does not switch traffic, update active_color,
stop the other color, perform rollback, or call Jenkins.
USAGE
}

if [[ "$#" -ne 3 ]]; then
  usage
  exit 2
fi

service_name="$1"
color="$2"
release_id="$3"

echo "[start-color] step=validate_config"
"$ROOT_DIR/scripts/validate-config.sh" "$SERVICE_CONFIG_FILE" >/dev/null

if [[ -z "$(service_discovery_get_service "$service_name" "$SERVICE_CONFIG_FILE")" ]]; then
  echo "[start-color] ERROR: service is not registered: $service_name" >&2
  exit 2
fi

state_dir="$(state_service_state_dir "$service_name" "$SERVICE_CONFIG_FILE")"
active_color_file="$(state_active_color_file "$service_name" "$SERVICE_CONFIG_FILE")"
if [[ ! -d "$state_dir" || ! -f "$active_color_file" ]]; then
  echo "[start-color] ERROR: service state is not initialized for $service_name" >&2
  echo "[start-color] HINT: run ./scripts/init-service.sh $service_name" >&2
  exit 2
fi

active_before="$(state_read_active_color "$service_name" "$SERVICE_CONFIG_FILE")"
runtime_start_color "$service_name" "$color" "$release_id" "$SERVICE_CONFIG_FILE"
active_after="$(state_read_active_color "$service_name" "$SERVICE_CONFIG_FILE")"

echo "[start-color] active_color_before=$active_before active_color_after=$active_after"
echo "[start-color] note=no traffic switch, active color update, NGINX change, rollback, or Jenkins action was performed"
