#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_CONFIG_FILE="${SERVICE_CONFIG_FILE:-$ROOT_DIR/config/services.yml}"
dry_run="no"

source "$ROOT_DIR/scripts/lib/service-discovery.sh"
source "$ROOT_DIR/scripts/lib/state.sh"
source "$ROOT_DIR/scripts/lib/runtime.sh"
source "$ROOT_DIR/scripts/lib/health.sh"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/deploy.sh <service_name> <artifact_source>
  ./scripts/deploy.sh <service_name> <artifact_source> --dry-run

Creates a release, starts the inactive color, validates health, and switches
traffic. Dry-run prints the plan without creating a release, starting a
container, reloading NGINX, switching traffic, or updating active_color.
USAGE
}

fail() {
  echo "[deploy] ERROR: $*" >&2
  exit 1
}

if [[ "$#" -lt 2 || "$#" -gt 3 ]]; then
  usage
  exit 2
fi

service_name="$1"
artifact_source="$2"
shift 2

if [[ "$#" -eq 1 ]]; then
  case "$1" in
    --dry-run) dry_run="yes" ;;
    *) echo "[deploy] ERROR: unknown argument: $1" >&2; usage; exit 2 ;;
  esac
fi

echo "[deploy] event=deploy_start service=$service_name artifact=$artifact_source dry_run=$dry_run"
echo "[deploy] step=validate_config"
"$ROOT_DIR/scripts/validate-config.sh" "$SERVICE_CONFIG_FILE" >/dev/null

if [[ -z "$(service_discovery_get_service "$service_name" "$SERVICE_CONFIG_FILE")" ]]; then
  echo "[deploy] ERROR: service is not registered: $service_name" >&2
  exit 2
fi

if [[ ! -e "$artifact_source" ]]; then
  echo "[deploy] ERROR: artifact source does not exist: $artifact_source" >&2
  exit 2
fi

state_dir="$(state_service_state_dir "$service_name" "$SERVICE_CONFIG_FILE")"
active_color_file="$(state_active_color_file "$service_name" "$SERVICE_CONFIG_FILE")"
if [[ ! -d "$state_dir" || ! -f "$active_color_file" ]]; then
  echo "[deploy] step=init_service_state"
  "$ROOT_DIR/scripts/init-service.sh" "$service_name" >/dev/null
fi

active_color="$(state_read_active_color "$service_name" "$SERVICE_CONFIG_FILE")"
target_color="$(state_determine_inactive_color "$service_name" "$SERVICE_CONFIG_FILE")"
target_port="$(runtime_resolve_color_port "$service_name" "$target_color" "$SERVICE_CONFIG_FILE")"
health_path="$(runtime_service_field "$service_name" health_path "$SERVICE_CONFIG_FILE")"
health_url="$(health_build_url "$target_port" "$health_path")"

cat <<EOF
[deploy] active_color=$active_color
[deploy] target_color=$target_color
[deploy] target_port=$target_port
[deploy] health_url=$health_url
EOF

if [[ "$dry_run" == "yes" ]]; then
  echo "[deploy] planned_create_release=./scripts/create-release.sh $service_name $artifact_source"
  echo "[deploy] planned_start=./scripts/start-color.sh $service_name $target_color <new_release_id>"
  echo "[deploy] planned_health=./scripts/validate-release.sh $service_name $target_port"
  echo "[deploy] planned_switch=./scripts/switch-traffic.sh $service_name $target_color"
  echo "[deploy] dry_run=passed"
  echo "[deploy] note=no release creation, container start, health call, NGINX reload, traffic switch, active_color update, or cleanup was performed"
  exit 0
fi

echo "[deploy] step=create_release"
create_output="$($ROOT_DIR/scripts/create-release.sh "$service_name" "$artifact_source")"
printf '%s\n' "$create_output"
release_id="$(printf '%s\n' "$create_output" | awk -F= '$1 == "[create-release] release_id" { print $2; exit }')"
[[ -n "$release_id" ]] || fail "could not determine release_id from create-release output"

echo "[deploy] step=start_inactive_color"
"$ROOT_DIR/scripts/start-color.sh" "$service_name" "$target_color" "$release_id"

echo "[deploy] step=health_check_inactive_color"
"$ROOT_DIR/scripts/validate-release.sh" "$service_name" "$target_port"

echo "[deploy] step=switch_traffic"
"$ROOT_DIR/scripts/switch-traffic.sh" "$service_name" "$target_color"

active_after="$(state_read_active_color "$service_name" "$SERVICE_CONFIG_FILE")"
state_append_release_history "$service_name" "event=deploy release_id=$release_id artifact=$artifact_source target_color=$target_color previous_color=$active_color active_color=$active_after" "$SERVICE_CONFIG_FILE"

cat <<EOF
[deploy] status=deployed
[deploy] service=$service_name
[deploy] release_id=$release_id
[deploy] previous_active_color=$active_color
[deploy] active_color=$active_after
[deploy] old_color_status=left_running
[deploy] note=no old active color stop, rollback, or Jenkins action was performed
EOF
