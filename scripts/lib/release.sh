#!/usr/bin/env bash
# Release artifact helpers for v1.0.0 foundations.
# This library manages release directories and metadata only. It does not start
# services, switch traffic, modify active blue/green color, reload NGINX,
# perform rollback, or call Jenkins.

set -euo pipefail

RELEASE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_ROOT_DIR="$(cd "$RELEASE_LIB_DIR/../.." && pwd)"

# shellcheck source=scripts/lib/service-discovery.sh
source "$RELEASE_ROOT_DIR/scripts/lib/service-discovery.sh"
# shellcheck source=scripts/lib/state.sh
source "$RELEASE_ROOT_DIR/scripts/lib/state.sh"

RELEASE_DEFAULT_RETENTION_COUNT="${RELEASE_DEFAULT_RETENTION_COUNT:-5}"

release_error() {
  echo "[release] ERROR: $*" >&2
}

release_warn() {
  echo "[release] WARN: $*" >&2
}

_release_service_field() {
  local service_name="$1"
  local field_name="$2"
  local config_file="${3:-$SERVICE_CONFIG_FILE}"

  service_discovery_get_service "$service_name" "$config_file" | awk -F= -v field="$field_name" '$1 == field { print substr($0, length($1) + 2); found = 1 } END { exit found ? 0 : 1 }'
}

_release_json_escape() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '%s' "$value"
}

release_git_short_hash() {
  if git -C "$RELEASE_ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$RELEASE_ROOT_DIR" rev-parse --short HEAD 2>/dev/null || true
  fi
}

release_git_full_hash() {
  if git -C "$RELEASE_ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$RELEASE_ROOT_DIR" rev-parse HEAD 2>/dev/null || true
  fi
}

release_generate_id() {
  local timestamp short_hash suffix

  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  short_hash="$(release_git_short_hash)"
  if [[ -n "$short_hash" ]]; then
    suffix="$short_hash"
  else
    suffix="nogit"
  fi

  printf '%s-%s\n' "$timestamp" "$suffix"
}


release_generate_unique_id() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  local base_id candidate releases_dir counter

  base_id="$(release_generate_id)"
  candidate="$base_id"
  releases_dir="$(state_service_releases_dir "$service_name" "$config_file")"
  counter=1

  while [[ -e "$releases_dir/$candidate" ]]; do
    counter=$(( counter + 1 ))
    candidate="${base_id}-${counter}"
  done

  printf '%s\n' "$candidate"
}

release_retention_count() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  local configured

  configured="$(_release_service_field "$service_name" retention_count "$config_file" 2>/dev/null || true)"
  if [[ -z "$configured" ]]; then
    configured="$RELEASE_DEFAULT_RETENTION_COUNT"
  fi

  if [[ ! "$configured" =~ ^[1-9][0-9]*$ ]]; then
    release_error "retention_count must be a positive integer for $service_name: $configured"
    return 1
  fi

  if (( configured > 10 )); then
    release_warn "retention_count is greater than 10 for $service_name: $configured"
  fi

  printf '%s\n' "$configured"
}

release_create_directory() {
  local service_name="$1"
  local release_id="$2"
  local config_file="${3:-$SERVICE_CONFIG_FILE}"
  local releases_dir release_dir

  releases_dir="$(state_service_releases_dir "$service_name" "$config_file")"
  release_dir="$releases_dir/$release_id"

  mkdir -p "$releases_dir"
  if [[ -e "$release_dir" ]]; then
    release_error "release directory already exists: $release_dir"
    return 1
  fi

  mkdir -p "$release_dir"
  printf '%s\n' "$release_dir"
}

release_write_metadata() {
  local service_name="$1"
  local release_id="$2"
  local release_dir="$3"
  local artifact_source="$4"
  local status="${5:-created}"
  local config_file="${6:-$SERVICE_CONFIG_FILE}"
  local metadata_file created_at git_commit deploy_path retention_count

  metadata_file="$release_dir/release.json"
  created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  git_commit="$(release_git_full_hash)"
  deploy_path="$(state_resolve_service_deploy_path "$service_name" "$config_file")"
  retention_count="$(release_retention_count "$service_name" "$config_file")"

  cat > "$metadata_file" <<JSON
{
  "release_id": "$(_release_json_escape "$release_id")",
  "service_name": "$(_release_json_escape "$service_name")",
  "created_at": "$(_release_json_escape "$created_at")",
  "source": "$(_release_json_escape "$artifact_source")",
  "git_commit": "$(_release_json_escape "$git_commit")",
  "deploy_path": "$(_release_json_escape "$deploy_path")",
  "status": "$(_release_json_escape "$status")",
  "retention_count": $retention_count
}
JSON
}

release_update_current_symlink() {
  local service_name="$1"
  local release_id="$2"
  local config_file="${3:-$SERVICE_CONFIG_FILE}"
  local current_link release_target tmp_link deploy_path

  current_link="$(state_current_link "$service_name" "$config_file")"
  deploy_path="$(state_resolve_service_deploy_path "$service_name" "$config_file")"
  release_target="releases/$release_id"
  tmp_link="$deploy_path/.current.tmp.$$"

  if [[ ! -d "$deploy_path/$release_target" ]]; then
    release_error "cannot point current at missing release: $deploy_path/$release_target"
    return 1
  fi

  ln -sfn "$release_target" "$tmp_link"
  mv -Tf "$tmp_link" "$current_link"
}

release_current_id() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  local current_link target

  current_link="$(state_current_link "$service_name" "$config_file")"
  if [[ ! -L "$current_link" ]]; then
    return 0
  fi

  target="$(readlink "$current_link")"
  case "$target" in
    releases/*)
      printf '%s\n' "${target#releases/}"
      ;;
    *)
      printf '%s\n' "$target"
      ;;
  esac
}

release_latest_successful_id() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  local history_file

  history_file="$(state_history_file "$service_name" "$config_file")"
  if [[ ! -s "$history_file" ]]; then
    return 0
  fi

  awk '
    /status=success/ {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^release_id=/) {
          sub(/^release_id=/, "", $i)
          latest = $i
        }
      }
    }
    END { if (latest != "") print latest }
  ' "$history_file"
}


release_previous_successful_id() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  local history_file current_id releases_dir candidate

  history_file="$(state_history_file "$service_name" "$config_file")"
  current_id="$(release_current_id "$service_name" "$config_file")"
  releases_dir="$(state_service_releases_dir "$service_name" "$config_file")"

  if [[ ! -s "$history_file" ]]; then
    return 0
  fi

  tac "$history_file" | awk '
    /status=success/ {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^release_id=/) {
          sub(/^release_id=/, "", $i)
          print $i
        }
      }
    }
  ' | while IFS= read -r candidate; do
    [[ -z "$candidate" ]] && continue
    [[ "$candidate" == "$current_id" ]] && continue
    if [[ -d "$releases_dir/$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
}

release_list_ids() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  local releases_dir

  releases_dir="$(state_service_releases_dir "$service_name" "$config_file")"
  if [[ ! -d "$releases_dir" ]]; then
    return 0
  fi

  find "$releases_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

release_metadata_value() {
  local metadata_file="$1"
  local key="$2"

  if [[ ! -f "$metadata_file" ]]; then
    return 0
  fi

  awk -v key="\"$key\"" '
    index($0, key) {
      value = $0
      sub(/^[[:space:]]*"[^"]+"[[:space:]]*:[[:space:]]*/, "", value)
      sub(/,?[[:space:]]*$/, "", value)
      gsub(/^"|"$/, "", value)
      print value
      exit
    }
  ' "$metadata_file"
}

release_cleanup_retention() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  local retention releases_dir current_id latest_successful_id total delete_count candidate

  retention="$(release_retention_count "$service_name" "$config_file")"
  releases_dir="$(state_service_releases_dir "$service_name" "$config_file")"
  current_id="$(release_current_id "$service_name" "$config_file")"
  latest_successful_id="$(release_latest_successful_id "$service_name" "$config_file")"

  if [[ ! -d "$releases_dir" ]]; then
    echo "[release] retention=noop reason=no_releases_dir service=$service_name"
    return 0
  fi

  mapfile -t release_ids < <(release_list_ids "$service_name" "$config_file")
  total="${#release_ids[@]}"

  if (( total <= retention )); then
    echo "[release] retention=noop service=$service_name total=$total retention_count=$retention"
    return 0
  fi

  delete_count=$(( total - retention ))
  echo "[release] retention=start service=$service_name total=$total retention_count=$retention candidates=$delete_count"

  for candidate in "${release_ids[@]}"; do
    if (( delete_count <= 0 )); then
      break
    fi

    if [[ "$candidate" == "$current_id" ]]; then
      echo "[release] retention=skip reason=current release_id=$candidate"
      continue
    fi

    if [[ -n "$latest_successful_id" && "$candidate" == "$latest_successful_id" ]]; then
      echo "[release] retention=skip reason=latest_successful release_id=$candidate"
      continue
    fi

    case "$candidate" in
      ""|.|..|*/*)
        release_warn "skipping suspicious release id during retention: $candidate"
        continue
        ;;
    esac

    if [[ ! -d "$releases_dir/$candidate" ]]; then
      release_warn "skipping missing release directory during retention: $releases_dir/$candidate"
      continue
    fi

    echo "[release] retention=delete release_id=$candidate path=$releases_dir/$candidate"
    rm -rf -- "$releases_dir/$candidate"
    delete_count=$(( delete_count - 1 ))
  done

  if (( delete_count > 0 )); then
    release_warn "retention left $delete_count old release(s) because protected releases were skipped"
  fi
}
