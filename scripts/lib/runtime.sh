#!/usr/bin/env bash
# Runtime helpers for v1.0.0 blue/green service instances.
# This library starts/stops/statuses named color runtimes only. It does not
# switch NGINX traffic, update active_color, perform rollback, or call Jenkins.

set -euo pipefail

RUNTIME_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_ROOT_DIR="$(cd "$RUNTIME_LIB_DIR/../.." && pwd)"

# shellcheck source=scripts/lib/service-discovery.sh
source "$RUNTIME_ROOT_DIR/scripts/lib/service-discovery.sh"
# shellcheck source=scripts/lib/state.sh
source "$RUNTIME_ROOT_DIR/scripts/lib/state.sh"
# shellcheck source=scripts/lib/release.sh
source "$RUNTIME_ROOT_DIR/scripts/lib/release.sh"

RUNTIME_DEMO_IMAGE="${RUNTIME_DEMO_IMAGE:-python:3.12-alpine}"
RUNTIME_CONTAINER_PORT="${RUNTIME_CONTAINER_PORT:-8080}"

runtime_error() {
  echo "[runtime] ERROR: $*" >&2
}

runtime_require_color() {
  local color="${1:-}"
  case "$color" in
    blue|green) return 0 ;;
    *)
      runtime_error "color must be blue or green: ${color:-<empty>}"
      return 1
      ;;
  esac
}

runtime_service_field() {
  local service_name="$1"
  local field_name="$2"
  local config_file="${3:-$SERVICE_CONFIG_FILE}"

  service_discovery_get_service "$service_name" "$config_file" | awk -F= -v field="$field_name" '$1 == field { print substr($0, length($1) + 2); found = 1 } END { exit found ? 0 : 1 }'
}

runtime_optional_service_field() {
  local service_name="$1"
  local field_name="$2"
  local config_file="${3:-$SERVICE_CONFIG_FILE}"

  runtime_service_field "$service_name" "$field_name" "$config_file" 2>/dev/null || true
}

runtime_resolve_runtime() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  local runtime

  runtime="$(runtime_service_field "$service_name" runtime "$config_file")"
  case "$runtime" in
    container|systemd)
      printf '%s\n' "$runtime"
      ;;
    *)
      runtime_error "unsupported runtime '$runtime'; expected container or systemd"
      return 1
      ;;
  esac
}

runtime_resolve_color_port() {
  local service_name="$1"
  local color="$2"
  local config_file="${3:-$SERVICE_CONFIG_FILE}"

  runtime_require_color "$color"
  runtime_service_field "$service_name" "${color}_port" "$config_file"
}

runtime_active_color() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  state_read_active_color "$service_name" "$config_file"
}

runtime_inactive_color() {
  local service_name="$1"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"
  state_determine_inactive_color "$service_name" "$config_file"
}

runtime_color_name() {
  local service_name="$1"
  local color="$2"
  runtime_require_color "$color"
  printf '%s-%s\n' "$service_name" "$color"
}

runtime_container_name() {
  runtime_color_name "$1" "$2"
}

runtime_require_container_runtime() {
  if ! command -v docker >/dev/null 2>&1; then
    runtime_error "docker command is required for runtime: container"
    return 127
  fi
}

runtime_release_dir() {
  local service_name="$1"
  local release_id="$2"
  local config_file="${3:-$SERVICE_CONFIG_FILE}"
  local releases_dir release_dir

  releases_dir="$(state_service_releases_dir "$service_name" "$config_file")"
  release_dir="$releases_dir/$release_id"

  if [[ ! -d "$release_dir" ]]; then
    runtime_error "release does not exist for $service_name: $release_id"
    return 1
  fi

  printf '%s\n' "$release_dir"
}

runtime_container_exists() {
  local container_name="$1"
  docker container inspect "$container_name" >/dev/null 2>&1
}

runtime_systemd_render_command() {
  local command_template="$1"
  local service_name="$2"
  local color="$3"
  local release_id="${4:-}"
  local port="$5"
  local release_dir="${6:-}"
  local deploy_path="$7"
  local command

  command="$command_template"
  command="${command//\{service_name\}/$service_name}"
  command="${command//\{color\}/$color}"
  command="${command//\{release_id\}/$release_id}"
  command="${command//\{port\}/$port}"
  command="${command//\{release_dir\}/$release_dir}"
  command="${command//\{deploy_path\}/$deploy_path}"
  printf '%s\n' "$command"
}

runtime_systemd_export_context() {
  local service_name="$1"
  local color="$2"
  local release_id="${3:-}"
  local config_file="$4"
  local port release_dir deploy_path working_directory env_file

  port="$(runtime_resolve_color_port "$service_name" "$color" "$config_file")"
  deploy_path="$(state_resolve_service_deploy_path "$service_name" "$config_file")"
  working_directory="$(runtime_optional_service_field "$service_name" working_directory "$config_file")"
  env_file="$(runtime_optional_service_field "$service_name" env_file "$config_file")"
  release_dir=""
  if [[ -n "$release_id" ]]; then
    release_dir="$(runtime_release_dir "$service_name" "$release_id" "$config_file")"
  fi

  export ZERO_DOWNTIME_SERVICE_NAME="$service_name"
  export ZERO_DOWNTIME_COLOR="$color"
  export ZERO_DOWNTIME_RELEASE_ID="$release_id"
  export ZERO_DOWNTIME_PORT="$port"
  export ZERO_DOWNTIME_RELEASE_DIR="$release_dir"
  export ZERO_DOWNTIME_DEPLOY_PATH="$deploy_path"
  export ZERO_DOWNTIME_WORKING_DIRECTORY="$working_directory"
  export ZERO_DOWNTIME_ENV_FILE="$env_file"

  printf '%s\n' "$release_dir"
}

runtime_systemd_command() {
  local service_name="$1"
  local color="$2"
  local command_field="$3"
  local release_id="${4:-}"
  local config_file="${5:-$SERVICE_CONFIG_FILE}"
  local command_template command port release_dir deploy_path

  runtime_require_color "$color"
  command_template="$(runtime_service_field "$service_name" "$command_field" "$config_file")"
  port="$(runtime_resolve_color_port "$service_name" "$color" "$config_file")"
  deploy_path="$(state_resolve_service_deploy_path "$service_name" "$config_file")"
  release_dir="$(runtime_systemd_export_context "$service_name" "$color" "$release_id" "$config_file")"
  command="$(runtime_systemd_render_command "$command_template" "$service_name" "$color" "$release_id" "$port" "$release_dir" "$deploy_path")"

  printf '%s\n' "$command"
}

runtime_systemd_start_color() {
  local service_name="$1"
  local color="$2"
  local release_id="$3"
  local config_file="$4"
  local command

  command="$(runtime_systemd_command "$service_name" "$color" start_command "$release_id" "$config_file")"
  echo "[runtime] action=start runtime=systemd service=$service_name color=$color release_id=$release_id command=$command"
  bash -c "$command"
}

runtime_systemd_stop_color() {
  local service_name="$1"
  local color="$2"
  local config_file="$3"
  local command

  command="$(runtime_systemd_command "$service_name" "$color" stop_command "" "$config_file")"
  echo "[runtime] action=stop runtime=systemd service=$service_name color=$color command=$command"
  bash -c "$command"
}

runtime_systemd_status_color() {
  local service_name="$1"
  local color="$2"
  local config_file="$3"
  local command output exit_code port unit_name

  command="$(runtime_systemd_command "$service_name" "$color" status_command "" "$config_file")"
  port="$(runtime_resolve_color_port "$service_name" "$color" "$config_file")"
  unit_name="$(runtime_color_name "$service_name" "$color")"

  set +e
  output="$(bash -c "$command" 2>&1)"
  exit_code="$?"
  set -e

  cat <<EOF
service: $service_name
color: $color
runtime: systemd
unit: $unit_name
port: $port
status_command: $command
active: $([[ "$exit_code" -eq 0 ]] && printf 'yes' || printf 'no')
exit_code: $exit_code
output: ${output:-<empty>}
EOF
}

runtime_container_start_color() {
  local service_name="$1"
  local color="$2"
  local release_id="$3"
  local config_file="$4"
  local port release_dir artifact_dir container_name health_path

  runtime_require_container_runtime

  release_dir="$(runtime_release_dir "$service_name" "$release_id" "$config_file")"
  artifact_dir="$release_dir/artifact"
  if [[ ! -d "$artifact_dir" ]]; then
    runtime_error "release artifact directory is missing: $artifact_dir"
    return 1
  fi

  if [[ ! -f "$artifact_dir/app.txt" ]]; then
    runtime_error "generic demo container mode requires artifact/app.txt in $release_dir"
    return 1
  fi

  port="$(runtime_resolve_color_port "$service_name" "$color" "$config_file")"
  health_path="$(runtime_service_field "$service_name" health_path "$config_file")"
  container_name="$(runtime_container_name "$service_name" "$color")"

  if runtime_container_exists "$container_name"; then
    runtime_error "container already exists: $container_name. Stop it before starting this color."
    return 1
  fi

  echo "[runtime] action=start runtime=container service=$service_name color=$color release_id=$release_id container=$container_name port=$port"
  docker run -d \
    --name "$container_name" \
    --label "zero-downtime.service=$service_name" \
    --label "zero-downtime.color=$color" \
    --label "zero-downtime.release_id=$release_id" \
    -e "SERVICE_NAME=$service_name" \
    -e "SERVICE_COLOR=$color" \
    -e "RELEASE_ID=$release_id" \
    -e "HEALTH_PATH=$health_path" \
    -v "$artifact_dir:/app/artifact:ro" \
    -p "$port:$RUNTIME_CONTAINER_PORT" \
    "$RUNTIME_DEMO_IMAGE" \
    sh -c 'cat > /tmp/zero_downtime_demo.py <<"ENDDEMO"
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

service = os.environ.get("SERVICE_NAME", "service")
color = os.environ.get("SERVICE_COLOR", "color")
release = os.environ.get("RELEASE_ID", "release")
health_path = os.environ.get("HEALTH_PATH", "/health")
artifact_file = "/app/artifact/app.txt"

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return

    def do_GET(self):
        if self.path == health_path:
            body = b"OK\n"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        if self.path == "/":
            try:
                with open(artifact_file, "r", encoding="utf-8") as fh:
                    artifact = fh.read().strip()
            except OSError:
                artifact = "artifact unavailable"
            body = f"service={service}\ncolor={color}\nrelease_id={release}\nartifact={artifact}\n".encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        body = b"Not Found\n"
        self.send_response(404)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
ENDDEMO
python /tmp/zero_downtime_demo.py'
}

runtime_container_stop_color() {
  local service_name="$1"
  local color="$2"
  local config_file="$3"
  local container_name

  runtime_require_container_runtime
  container_name="$(runtime_container_name "$service_name" "$color")"

  if ! runtime_container_exists "$container_name"; then
    echo "[runtime] action=stop runtime=container service=$service_name color=$color container=$container_name status=not_found"
    return 0
  fi

  echo "[runtime] action=stop runtime=container service=$service_name color=$color container=$container_name"
  docker rm -f "$container_name" >/dev/null
  echo "[runtime] status=stopped container=$container_name"
}

runtime_container_status_color() {
  local service_name="$1"
  local color="$2"
  local container_name exists running mapped_port release_id

  runtime_require_container_runtime
  container_name="$(runtime_container_name "$service_name" "$color")"

  exists="no"
  running="no"
  mapped_port=""
  release_id=""

  if runtime_container_exists "$container_name"; then
    exists="yes"
    running="$(docker inspect -f '{{.State.Running}}' "$container_name")"
    if [[ "$running" == "true" ]]; then
      running="yes"
    else
      running="no"
    fi
    mapped_port="$(docker port "$container_name" "$RUNTIME_CONTAINER_PORT/tcp" 2>/dev/null || true)"
    release_id="$(docker inspect -f '{{ index .Config.Labels "zero-downtime.release_id" }}' "$container_name" 2>/dev/null || true)"
  fi

  cat <<EOF
service: $service_name
color: $color
runtime: container
container: $container_name
exists: $exists
running: $running
mapped_port: ${mapped_port:-not mapped}
release_id: ${release_id:-unknown}
EOF
}

runtime_start_color() {
  local service_name="$1"
  local color="$2"
  local release_id="$3"
  local config_file="${4:-$SERVICE_CONFIG_FILE}"
  local runtime

  runtime_require_color "$color"
  runtime="$(runtime_resolve_runtime "$service_name" "$config_file")"
  case "$runtime" in
    container) runtime_container_start_color "$service_name" "$color" "$release_id" "$config_file" ;;
    systemd) runtime_systemd_start_color "$service_name" "$color" "$release_id" "$config_file" ;;
  esac
}

runtime_stop_color() {
  local service_name="$1"
  local color="$2"
  local config_file="${3:-$SERVICE_CONFIG_FILE}"
  local runtime

  runtime_require_color "$color"
  runtime="$(runtime_resolve_runtime "$service_name" "$config_file")"
  case "$runtime" in
    container) runtime_container_stop_color "$service_name" "$color" "$config_file" ;;
    systemd) runtime_systemd_stop_color "$service_name" "$color" "$config_file" ;;
  esac
}

runtime_status_color() {
  local service_name="$1"
  local color="$2"
  local config_file="${3:-$SERVICE_CONFIG_FILE}"
  local runtime

  runtime_require_color "$color"
  runtime="$(runtime_resolve_runtime "$service_name" "$config_file")"
  case "$runtime" in
    container) runtime_container_status_color "$service_name" "$color" "$config_file" ;;
    systemd) runtime_systemd_status_color "$service_name" "$color" "$config_file" ;;
  esac
}
