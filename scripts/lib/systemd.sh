#!/usr/bin/env bash
# systemd unit generation helpers for VM blue/green service runtimes.

set -euo pipefail

SYSTEMD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEMD_ROOT_DIR="$(cd "$SYSTEMD_LIB_DIR/../.." && pwd)"

# shellcheck source=scripts/lib/service-discovery.sh
source "$SYSTEMD_ROOT_DIR/scripts/lib/service-discovery.sh"
# shellcheck source=scripts/lib/state.sh
source "$SYSTEMD_ROOT_DIR/scripts/lib/state.sh"
# shellcheck source=scripts/lib/runtime.sh
source "$SYSTEMD_ROOT_DIR/scripts/lib/runtime.sh"

SYSTEMD_UNIT_DIR="${SYSTEMD_UNIT_DIR:-/etc/systemd/system}"
SYSTEMCTL_BIN="${SYSTEMCTL_BIN:-systemctl}"
SUDO_BIN="${SUDO_BIN:-sudo}"
SYSTEMD_ANALYZE_BIN="${SYSTEMD_ANALYZE_BIN:-systemd-analyze}"

systemd_error() {
  echo "[systemd] ERROR: $*" >&2
}

systemd_unit_name() {
  local service_name="$1" color="$2"
  runtime_require_color "$color"
  printf '%s-%s.service\n' "$service_name" "$color"
}

systemd_unit_path() {
  local unit_name="$1"
  printf '%s/%s\n' "$SYSTEMD_UNIT_DIR" "$unit_name"
}

systemd_unit_exists() {
  local unit_name="$1" unit_path load_state listed_units

  unit_path="$(systemd_unit_path "$unit_name")"
  if [[ -e "$unit_path" || -L "$unit_path" ]]; then
    return 0
  fi

  if "$SYSTEMCTL_BIN" cat "$unit_name" >/dev/null 2>&1; then
    return 0
  fi

  load_state="$("$SYSTEMCTL_BIN" show "$unit_name" --property=LoadState --value 2>/dev/null || true)"
  if [[ -n "$load_state" && "$load_state" != "not-found" ]]; then
    return 0
  fi

  listed_units="$("$SYSTEMCTL_BIN" list-unit-files "$unit_name" --no-legend --no-pager 2>/dev/null || true)"
  awk -v unit="$unit_name" '$1 == unit { found = 1 } END { exit found ? 0 : 1 }' <<< "$listed_units"
}

systemd_existing_service_units() {
  local service_name="$1" color unit_name

  for color in blue green; do
    unit_name="$(systemd_unit_name "$service_name" "$color")"
    if systemd_unit_exists "$unit_name"; then
      printf '%s\n' "$unit_name"
    fi
  done
}

systemd_validate_generated_units() {
  local service_name="$1" output_dir="$2" color unit_name unit_file
  local -a unit_files=()

  for color in blue green; do
    unit_name="$(systemd_unit_name "$service_name" "$color")"
    unit_file="$output_dir/$unit_name"
    if [[ ! -f "$unit_file" || ! -s "$unit_file" || ! -r "$unit_file" ]]; then
      systemd_error "generated unit is missing, empty, or unreadable: $unit_file"
      return 1
    fi
    if [[ "$(basename "$unit_file")" != "$unit_name" ]]; then
      systemd_error "generated unit filename does not match expected name: $unit_file"
      return 1
    fi
    unit_files+=("$unit_file")
  done

  if command -v "$SYSTEMD_ANALYZE_BIN" >/dev/null 2>&1; then
    if ! "$SYSTEMD_ANALYZE_BIN" verify "${unit_files[@]}"; then
      systemd_error "generated unit validation failed for: $service_name"
      return 1
    fi
  else
    echo "[systemd] systemd-analyze is unavailable; skipped syntax validation"
  fi
}

systemd_validate_sudo_access() {
  local non_interactive="${1:-no}"

  if [[ "$non_interactive" == "yes" ]]; then
    "$SUDO_BIN" -n true
  else
    "$SUDO_BIN" -v
  fi
}

_systemd_rollback_installation() {
  local blue_unit="$1" green_unit="$2" blue_path="$3" green_path="$4"
  local blue_link_created="$5" green_link_created="$6"
  local blue_enabled="$7" green_enabled="$8"

  if [[ "$green_enabled" == "yes" ]]; then
    "$SUDO_BIN" "$SYSTEMCTL_BIN" disable "$green_unit" >/dev/null 2>&1 || true
  fi
  if [[ "$blue_enabled" == "yes" ]]; then
    "$SUDO_BIN" "$SYSTEMCTL_BIN" disable "$blue_unit" >/dev/null 2>&1 || true
  fi
  if [[ "$green_link_created" == "yes" ]]; then
    "$SUDO_BIN" rm -- "$green_path" >/dev/null 2>&1 || true
  fi
  if [[ "$blue_link_created" == "yes" ]]; then
    "$SUDO_BIN" rm -- "$blue_path" >/dev/null 2>&1 || true
  fi
  "$SUDO_BIN" "$SYSTEMCTL_BIN" daemon-reload >/dev/null 2>&1 || true
}

systemd_install_service_units() {
  local service_name="$1" output_dir="$2"
  local blue_unit green_unit blue_source green_source blue_path green_path absolute_output_dir
  local blue_link_created="no" green_link_created="no" blue_enabled="no" green_enabled="no"
  local failed="no"

  absolute_output_dir="$(cd "$output_dir" && pwd -P)"
  blue_unit="$(systemd_unit_name "$service_name" blue)"
  green_unit="$(systemd_unit_name "$service_name" green)"
  blue_source="$absolute_output_dir/$blue_unit"
  green_source="$absolute_output_dir/$green_unit"
  blue_path="$(systemd_unit_path "$blue_unit")"
  green_path="$(systemd_unit_path "$green_unit")"

  if [[ -e "$blue_path" || -L "$blue_path" || -e "$green_path" || -L "$green_path" ]]; then
    systemd_error "unit destination appeared before installation for: $service_name"
    return 1
  fi

  if "$SUDO_BIN" ln -s "$blue_source" "$blue_path"; then
    blue_link_created="yes"
  else
    failed="yes"
  fi
  if [[ "$failed" == "no" ]]; then
    if "$SUDO_BIN" ln -s "$green_source" "$green_path"; then
      green_link_created="yes"
    else
      failed="yes"
    fi
  fi
  if [[ "$failed" == "no" ]] && ! "$SUDO_BIN" "$SYSTEMCTL_BIN" daemon-reload; then
    failed="yes"
  fi
  if [[ "$failed" == "no" ]]; then
    if [[ "$("$SYSTEMCTL_BIN" show "$blue_unit" --property=LoadState --value 2>/dev/null || true)" != "loaded" || \
          "$("$SYSTEMCTL_BIN" show "$green_unit" --property=LoadState --value 2>/dev/null || true)" != "loaded" ]]; then
      systemd_error "installed units did not reach LoadState=loaded for: $service_name"
      failed="yes"
    fi
  fi
  if [[ "$failed" == "no" ]]; then
    if "$SUDO_BIN" "$SYSTEMCTL_BIN" enable "$blue_unit"; then
      blue_enabled="yes"
    else
      if [[ "$("$SYSTEMCTL_BIN" is-enabled "$blue_unit" 2>/dev/null || true)" == "enabled" ]]; then
        blue_enabled="yes"
      fi
      failed="yes"
    fi
  fi
  if [[ "$failed" == "no" ]]; then
    if "$SUDO_BIN" "$SYSTEMCTL_BIN" enable "$green_unit"; then
      green_enabled="yes"
    else
      if [[ "$("$SYSTEMCTL_BIN" is-enabled "$green_unit" 2>/dev/null || true)" == "enabled" ]]; then
        green_enabled="yes"
      fi
      failed="yes"
    fi
  fi
  if [[ "$failed" == "no" ]]; then
    if [[ "$("$SYSTEMCTL_BIN" is-enabled "$blue_unit" 2>/dev/null || true)" != "enabled" || \
          "$("$SYSTEMCTL_BIN" is-enabled "$green_unit" 2>/dev/null || true)" != "enabled" ]]; then
      systemd_error "installed units did not report enabled for: $service_name"
      failed="yes"
    fi
  fi

  if [[ "$failed" == "yes" ]]; then
    _systemd_rollback_installation \
      "$blue_unit" "$green_unit" "$blue_path" "$green_path" \
      "$blue_link_created" "$green_link_created" "$blue_enabled" "$green_enabled"
    systemd_error "systemd installation failed for: $service_name"
    echo "[systemd] Rolled back systemd changes created during this execution" >&2
    return 1
  fi
}

systemd_generate_unit_file() {
  local service_name="$1" color="$2" output_dir="$3" config_file="${4:-$SERVICE_CONFIG_FILE}"
  local runtime deploy_path port env_file env_file_line working_directory unit_name output_file
  local executable executable_line service_user user_line service_group group_line

  runtime="$(runtime_resolve_runtime "$service_name" "$config_file")"
  if [[ "$runtime" != "systemd" ]]; then
    systemd_error "service $service_name uses runtime=$runtime; systemd unit generation is only valid for runtime=systemd"
    return 1
  fi

  deploy_path="$(state_resolve_service_deploy_path "$service_name" "$config_file")"
  port="$(runtime_resolve_color_port "$service_name" "$color" "$config_file")"
  env_file="$(runtime_optional_service_field "$service_name" env_file "$config_file")"
  env_file_line=""
  if [[ -n "$env_file" ]]; then
    env_file_line="EnvironmentFile=-$env_file"
  fi
  executable="$(runtime_optional_service_field "$service_name" executable "$config_file")"
  executable_line=""
  if [[ -n "$executable" ]]; then
    executable_line="Environment=ZERO_DOWNTIME_EXECUTABLE=$executable"
  fi
  service_user="$(runtime_optional_service_field "$service_name" user "$config_file")"
  user_line=""
  if [[ -n "$service_user" ]]; then
    user_line="User=$service_user"
  fi
  service_group="$(runtime_optional_service_field "$service_name" group "$config_file")"
  group_line=""
  if [[ -n "$service_group" ]]; then
    group_line="Group=$service_group"
  fi
  working_directory="$(runtime_optional_service_field "$service_name" working_directory "$config_file")"
  if [[ -z "$working_directory" ]]; then
    working_directory="$deploy_path/current/artifact"
  fi

  mkdir -p "$output_dir"
  unit_name="$(systemd_unit_name "$service_name" "$color")"
  output_file="$output_dir/$unit_name"

  cat > "$output_file" <<UNIT
[Unit]
Description=$service_name $color runtime
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
$user_line
$group_line
WorkingDirectory=$working_directory
$env_file_line
$executable_line
Environment=ZERO_DOWNTIME_SERVICE_NAME=$service_name
Environment=ZERO_DOWNTIME_COLOR=$color
Environment=ACTIVE_COLOR=$color
Environment=ZERO_DOWNTIME_PORT=$port
Environment=PORT=$port
Environment=ZERO_DOWNTIME_DEPLOY_PATH=$deploy_path
Environment=ZERO_DOWNTIME_RELEASE_DIR=$deploy_path/current
ExecStart=/usr/bin/env bash -lc 'artifact="\${ZERO_DOWNTIME_RELEASE_DIR}/artifact"; exec_file="\${ZERO_DOWNTIME_EXECUTABLE:-}"; if [ -n "\$exec_file" ]; then case "\$exec_file" in /*) candidate="\$exec_file" ;; *) candidate="\$artifact/\$exec_file" ;; esac; else candidate="\$(find "\$artifact" -maxdepth 1 -type f -perm -111 | sort | head -n 1)"; fi; if [ -z "\$candidate" ] || [ ! -x "\$candidate" ]; then echo "No executable artifact found in \$artifact; set ZERO_DOWNTIME_EXECUTABLE in the environment file" >&2; exit 127; fi; exec "\$candidate"'
Restart=always
RestartSec=3
KillSignal=SIGTERM
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
UNIT

  printf '%s\n' "$output_file"
}

systemd_generate_service_units() {
  local service_name="$1" output_dir="$2" config_file="${3:-$SERVICE_CONFIG_FILE}" color

  for color in blue green; do
    systemd_generate_unit_file "$service_name" "$color" "$output_dir" "$config_file"
  done
}
