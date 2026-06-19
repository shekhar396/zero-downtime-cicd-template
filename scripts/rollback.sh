#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_CONFIG_FILE="${SERVICE_CONFIG_FILE:-$ROOT_DIR/config/services.yml}"
dry_run="no"
manual_release=""

source "$ROOT_DIR/scripts/lib/service-discovery.sh"
source "$ROOT_DIR/scripts/lib/state.sh"
source "$ROOT_DIR/scripts/lib/release.sh"
source "$ROOT_DIR/scripts/lib/runtime.sh"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/rollback.sh <service_name>
  ./scripts/rollback.sh <service_name> --release <release_id>
  ./scripts/rollback.sh <service_name> --dry-run

Rolls one service back by starting the selected release on the inactive color,
health-checking it, and switching traffic. Dry-run does not start containers,
reload NGINX, switch traffic, or update active_color.
USAGE
}

fail() {
  echo "[rollback] ERROR: $*" >&2
  exit 1
}

if [[ "$#" -lt 1 ]]; then
  usage
  exit 2
fi

service_name="$1"
shift

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --release)
      [[ "$#" -ge 2 ]] || { echo "[rollback] ERROR: --release requires a value" >&2; exit 2; }
      manual_release="$2"
      shift 2
      ;;
    --dry-run)
      dry_run="yes"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[rollback] ERROR: unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

echo "[rollback] event=rollback_start service=$service_name dry_run=$dry_run"
echo "[rollback] step=validate_config"
"$ROOT_DIR/scripts/validate-config.sh" "$SERVICE_CONFIG_FILE" >/dev/null

if [[ -z "$(service_discovery_get_service "$service_name" "$SERVICE_CONFIG_FILE")" ]]; then
  echo "[rollback] ERROR: service is not registered: $service_name" >&2
  exit 2
fi

state_dir="$(state_service_state_dir "$service_name" "$SERVICE_CONFIG_FILE")"
active_color_file="$(state_active_color_file "$service_name" "$SERVICE_CONFIG_FILE")"
[[ -d "$state_dir" && -f "$active_color_file" ]] || fail "service state is not initialized for $service_name; run ./scripts/init-service.sh $service_name"

active_before="$(state_read_active_color "$service_name" "$SERVICE_CONFIG_FILE")"
target_color="$(state_determine_inactive_color "$service_name" "$SERVICE_CONFIG_FILE")"
target_port="$(runtime_resolve_color_port "$service_name" "$target_color" "$SERVICE_CONFIG_FILE")"

if [[ -n "$manual_release" ]]; then
  rollback_release="$manual_release"
else
  rollback_release="$(release_previous_successful_id "$service_name" "$SERVICE_CONFIG_FILE")"
fi

[[ -n "$rollback_release" ]] || fail "no previous retained successful release found for $service_name"
release_dir="$(runtime_release_dir "$service_name" "$rollback_release" "$SERVICE_CONFIG_FILE")"

cat <<EOF
[rollback] active_color=$active_before
[rollback] target_color=$target_color
[rollback] candidate_port=$target_port
[rollback] rollback_release=$rollback_release
[rollback] release_dir=$release_dir
EOF

if [[ "$dry_run" == "yes" ]]; then
  echo "[rollback] intended_start=./scripts/start-color.sh $service_name $target_color $rollback_release"
  echo "[rollback] intended_health=./scripts/validate-release.sh $service_name $target_port"
  echo "[rollback] intended_switch=./scripts/switch-traffic.sh $service_name $target_color"
  echo "[rollback] dry_run=passed"
  echo "[rollback] note=no container start, health call, NGINX reload, traffic switch, active_color update, or cleanup was performed"
  exit 0
fi

echo "[rollback] step=start_target_color"
"$ROOT_DIR/scripts/start-color.sh" "$service_name" "$target_color" "$rollback_release"

echo "[rollback] step=health_check_target_color"
"$ROOT_DIR/scripts/validate-release.sh" "$service_name" "$target_port"

echo "[rollback] step=switch_traffic"
"$ROOT_DIR/scripts/switch-traffic.sh" "$service_name" "$target_color"

active_after="$(state_read_active_color "$service_name" "$SERVICE_CONFIG_FILE")"
state_append_release_history "$service_name" "event=rollback release_id=$rollback_release target_color=$target_color previous_color=$active_before active_color=$active_after" "$SERVICE_CONFIG_FILE"

echo "[rollback] status=rolled_back service=$service_name release_id=$rollback_release active_color=$active_after previous_color=$active_before"
echo "[rollback] note=old color remains running until explicitly stopped; no Jenkins action was performed"
