#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_CONFIG_FILE="${SERVICE_CONFIG_FILE:-$ROOT_DIR/config/services.yml}"
generate_systemd="no"
systemd_output_dir="$ROOT_DIR/build/systemd"

# shellcheck source=scripts/lib/service-discovery.sh
source "$ROOT_DIR/scripts/lib/service-discovery.sh"
# shellcheck source=scripts/lib/state.sh
source "$ROOT_DIR/scripts/lib/state.sh"
# shellcheck source=scripts/lib/systemd.sh
source "$ROOT_DIR/scripts/lib/systemd.sh"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/init-service.sh <service_name>
  ./scripts/init-service.sh <service_name> --generate-systemd [--systemd-output <dir>]

Initializes the release/state directory structure for one registered service.
When --generate-systemd is supplied for runtime: systemd services, also renders
blue/green unit files to the requested output directory. It does not install,
enable, restart, or reload systemd.
USAGE
}

if [[ "$#" -lt 1 ]]; then
  usage
  exit 1
fi

service_name="$1"
shift

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --generate-systemd)
      generate_systemd="yes"
      shift
      ;;
    --systemd-output)
      [[ "$#" -ge 2 ]] || { echo "[init-service] ERROR: --systemd-output requires a value" >&2; exit 2; }
      systemd_output_dir="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[init-service] ERROR: unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

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

if [[ "$generate_systemd" == "yes" ]]; then
  echo "[init-service] Generating systemd units..."
  while IFS= read -r generated_unit; do
    echo "[init-service] generated=$generated_unit"
  done < <(systemd_generate_service_units "$service_name" "$systemd_output_dir" "$SERVICE_CONFIG_FILE")
  echo "[init-service] systemd_output_dir=$systemd_output_dir"
fi

echo "[init-service] Done. No deployment was performed."
