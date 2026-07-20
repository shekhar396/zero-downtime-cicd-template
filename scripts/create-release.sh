#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_CONFIG_FILE="${SERVICE_CONFIG_FILE:-$ROOT_DIR/config/services.yml}"

# shellcheck source=scripts/lib/service-discovery.sh
source "$ROOT_DIR/scripts/lib/service-discovery.sh"
# shellcheck source=scripts/lib/state.sh
source "$ROOT_DIR/scripts/lib/state.sh"
# shellcheck source=scripts/lib/release.sh
source "$ROOT_DIR/scripts/lib/release.sh"

usage() {
  cat <<'USAGE'
Usage: ./scripts/create-release.sh <service_name> <artifact_source>

Creates a release artifact directory for a registered service. This does not
start services, change active blue/green color, touch NGINX, run Jenkins, or
perform rollback.
USAGE
}

copy_artifact() {
  local artifact_source="$1"
  local release_dir="$2"
  local target_dir="$release_dir/artifact"

  mkdir -p "$target_dir"
  if [[ -d "$artifact_source" ]]; then
    cp -a "$artifact_source/." "$target_dir/"
  elif [[ -f "$artifact_source" ]]; then
    cp -a "$artifact_source" "$target_dir/"
  else
    echo "[create-release] ERROR: artifact source is not a file or directory: $artifact_source" >&2
    return 1
  fi
}

if [[ "$#" -ne 2 ]]; then
  usage
  exit 2
fi

service_name="$1"
artifact_source="$2"

echo "[create-release] event=create_release_start service=$service_name artifact=$artifact_source"

echo "[create-release] step=validate_config"
"$ROOT_DIR/scripts/validate-config.sh" "$SERVICE_CONFIG_FILE" >/dev/null

if [[ -z "$(service_discovery_get_service "$service_name" "$SERVICE_CONFIG_FILE")" ]]; then
  echo "[create-release] ERROR: service is not registered: $service_name" >&2
  exit 2
fi

if [[ ! -e "$artifact_source" ]]; then
  echo "[create-release] ERROR: artifact source does not exist: $artifact_source" >&2
  exit 2
fi

state_dir="$(state_service_state_dir "$service_name" "$SERVICE_CONFIG_FILE")"
active_color_file="$(state_active_color_file "$service_name" "$SERVICE_CONFIG_FILE")"
if [[ ! -d "$state_dir" || ! -f "$active_color_file" ]]; then
  echo "[create-release] ERROR: service state is not initialized for $service_name" >&2
  echo "[create-release] HINT: run ./scripts/init-service.sh $service_name" >&2
  exit 2
fi

lock_acquired="no"
cleanup_lock() {
  if [[ "${lock_acquired:-no}" == "yes" ]]; then
    state_release_deployment_lock "$service_name" "$SERVICE_CONFIG_FILE"
  fi
}
trap cleanup_lock EXIT

echo "[create-release] step=acquire_lock"
state_create_deployment_lock "$service_name" "$SERVICE_CONFIG_FILE"
lock_acquired="yes"

retention_count="$(release_retention_count "$service_name" "$SERVICE_CONFIG_FILE")"
release_id="$(release_generate_unique_id "$service_name" "$SERVICE_CONFIG_FILE")"
release_dir="$(release_create_directory "$service_name" "$release_id" "$SERVICE_CONFIG_FILE")"

echo "[create-release] release_id=$release_id"
echo "[create-release] release_dir=$release_dir"
echo "[create-release] retention_count=$retention_count"

echo "[create-release] step=copy_artifact"
copy_artifact "$artifact_source" "$release_dir"

echo "[create-release] step=write_metadata"
release_write_metadata "$service_name" "$release_id" "$release_dir" "$artifact_source" "success" "$SERVICE_CONFIG_FILE"

echo "[create-release] step=update_current_symlink"
release_update_current_symlink "$service_name" "$release_id" "$SERVICE_CONFIG_FILE"

state_append_release_history "$service_name" "release_id=$release_id status=success source=$artifact_source" "$SERVICE_CONFIG_FILE"

echo "[create-release] step=retention_cleanup"
release_cleanup_retention "$service_name" "$SERVICE_CONFIG_FILE"

echo "[create-release] step=release_lock"
state_release_deployment_lock "$service_name" "$SERVICE_CONFIG_FILE"
lock_acquired="no"

echo "[create-release] status=created service=$service_name release_id=$release_id"
echo "[create-release] note=no service start, blue/green color change, NGINX change, Jenkins action, or rollback was performed"
