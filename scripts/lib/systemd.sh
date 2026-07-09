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

systemd_error() {
  echo "[systemd] ERROR: $*" >&2
}

systemd_unit_name() {
  local service_name="$1" color="$2"
  runtime_require_color "$color"
  printf '%s-%s.service\n' "$service_name" "$color"
}

systemd_generate_unit_file() {
  local service_name="$1" color="$2" output_dir="$3" config_file="${4:-$SERVICE_CONFIG_FILE}"
  local runtime deploy_path port env_file env_file_line working_directory unit_name output_file

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
WorkingDirectory=$working_directory
$env_file_line
Environment=ZERO_DOWNTIME_SERVICE_NAME=$service_name
Environment=ZERO_DOWNTIME_COLOR=$color
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
