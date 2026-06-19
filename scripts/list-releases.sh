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
Usage: ./scripts/list-releases.sh <service_name>

Lists retained release directories and metadata for one service.
USAGE
}

if [[ "$#" -ne 1 ]]; then
  usage
  exit 2
fi

service_name="$1"

if [[ -z "$(service_discovery_get_service "$service_name" "$SERVICE_CONFIG_FILE")" ]]; then
  echo "[list-releases] ERROR: service is not registered: $service_name" >&2
  exit 2
fi

releases_dir="$(state_service_releases_dir "$service_name" "$SERVICE_CONFIG_FILE")"
current_id="$(release_current_id "$service_name" "$SERVICE_CONFIG_FILE")"
retention_count="$(release_retention_count "$service_name" "$SERVICE_CONFIG_FILE")"

echo "service: $service_name"
echo "releases_dir: $releases_dir"
echo "retention_count: $retention_count"
echo "retained releases:"

found="no"
while IFS= read -r release_id; do
  [[ -z "$release_id" ]] && continue
  found="yes"
  release_dir="$releases_dir/$release_id"
  metadata_file="$release_dir/release.json"
  created_at="$(release_metadata_value "$metadata_file" created_at)"
  source="$(release_metadata_value "$metadata_file" source)"
  git_commit="$(release_metadata_value "$metadata_file" git_commit)"
  current_marker=""
  if [[ "$release_id" == "$current_id" ]]; then
    current_marker=" current"
  fi

  echo "- release_id: $release_id$current_marker"
  echo "  created_at: ${created_at:-unknown}"
  echo "  source: ${source:-unknown}"
  echo "  git_commit: ${git_commit:-}"
done < <(release_list_ids "$service_name" "$SERVICE_CONFIG_FILE")

if [[ "$found" == "no" ]]; then
  echo "  none"
fi
