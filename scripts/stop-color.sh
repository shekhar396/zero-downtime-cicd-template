#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_CONFIG_FILE="${SERVICE_CONFIG_FILE:-$ROOT_DIR/config/services.yml}"

# shellcheck source=scripts/lib/service-discovery.sh
source "$ROOT_DIR/scripts/lib/service-discovery.sh"
# shellcheck source=scripts/lib/runtime.sh
source "$ROOT_DIR/scripts/lib/runtime.sh"

usage() {
  cat <<'USAGE'
Usage: ./scripts/stop-color.sh <service_name> <color>

Stops and removes only the target color container named <service_name>-<color>.
USAGE
}

if [[ "$#" -ne 2 ]]; then
  usage
  exit 2
fi

service_name="$1"
color="$2"

"$ROOT_DIR/scripts/validate-config.sh" "$SERVICE_CONFIG_FILE" >/dev/null
if [[ -z "$(service_discovery_get_service "$service_name" "$SERVICE_CONFIG_FILE")" ]]; then
  echo "[stop-color] ERROR: service is not registered: $service_name" >&2
  exit 2
fi

runtime_stop_color "$service_name" "$color" "$SERVICE_CONFIG_FILE"
echo "[stop-color] note=no other color, NGINX, active_color, rollback, or Jenkins state was changed"
