#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_CONFIG_FILE="${SERVICE_CONFIG_FILE:-$ROOT_DIR/config/services.yml}"
ENVIRONMENT="production"
SOURCE_DIR=""
SERVICE_NAME=""
ARTIFACT_SOURCE=""
FORCE="no"
BUILD_COMMANDS=()
VERIFY_PATHS=(/live /health /ready /version)
SYSTEMD_BUILD_DIR="$ROOT_DIR/build/systemd-onboarding"

# shellcheck source=scripts/lib/service-discovery.sh
source "$ROOT_DIR/scripts/lib/service-discovery.sh"
# shellcheck source=scripts/lib/state.sh
source "$ROOT_DIR/scripts/lib/state.sh"
# shellcheck source=scripts/lib/runtime.sh
source "$ROOT_DIR/scripts/lib/runtime.sh"
# shellcheck source=scripts/lib/health.sh
source "$ROOT_DIR/scripts/lib/health.sh"
# shellcheck source=scripts/lib/systemd.sh
source "$ROOT_DIR/scripts/lib/systemd.sh"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onboard.sh --source <app_path> [options]

Options:
  --environment <name>       Environment config name under config/environments (default: production)
  --service <service_name>   Registered service to deploy (default: first service in config/services.yml)
  --config <path>            Service config file (default: config/services.yml)
  --artifact <path>          Built artifact file or directory. Relative paths are resolved from --source.
  --build-command <command>  Build command to run from --source. May be supplied multiple times.
                             Defaults to "make test" and "make build" when a Makefile exists.
  --force                    Backup and replace differing installed systemd units.
  -h, --help                 Show this help.
USAGE
}

log_start() { echo "[onboard] START $*"; }
log_success() { echo "[onboard] SUCCESS $*"; }
fail() { echo "[onboard] FAILURE $*" >&2; exit 1; }

run_step() {
  local name="$1"
  shift
  log_start "$name"
  "$@"
  log_success "$name"
}

service_field() {
  local field_name="$1"
  runtime_service_field "$SERVICE_NAME" "$field_name" "$SERVICE_CONFIG_FILE"
}

service_field_optional() {
  local field_name="$1"
  runtime_optional_service_field "$SERVICE_NAME" "$field_name" "$SERVICE_CONFIG_FILE"
}

resolve_path_from_source() {
  local path="$1"
  case "$path" in
    /*) printf '%s\n' "$path" ;;
    *) printf '%s/%s\n' "$SOURCE_DIR" "$path" ;;
  esac
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --source)
        [[ "$#" -ge 2 ]] || fail "--source requires a value"
        SOURCE_DIR="$2"
        shift 2
        ;;
      --environment)
        [[ "$#" -ge 2 ]] || fail "--environment requires a value"
        ENVIRONMENT="$2"
        shift 2
        ;;
      --service)
        [[ "$#" -ge 2 ]] || fail "--service requires a value"
        SERVICE_NAME="$2"
        shift 2
        ;;
      --config)
        [[ "$#" -ge 2 ]] || fail "--config requires a value"
        SERVICE_CONFIG_FILE="$2"
        shift 2
        ;;
      --artifact)
        [[ "$#" -ge 2 ]] || fail "--artifact requires a value"
        ARTIFACT_SOURCE="$2"
        shift 2
        ;;
      --build-command)
        [[ "$#" -ge 2 ]] || fail "--build-command requires a value"
        BUILD_COMMANDS+=("$2")
        shift 2
        ;;
      --force)
        FORCE="yes"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "unknown argument: $1"
        ;;
    esac
  done

  [[ -n "$SOURCE_DIR" ]] || { usage; fail "--source is required"; }
  SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)" || fail "source directory does not exist: $SOURCE_DIR"
  SERVICE_CONFIG_FILE="$(cd "$(dirname "$SERVICE_CONFIG_FILE")" && pwd)/$(basename "$SERVICE_CONFIG_FILE")"
}

validate_environment() {
  [[ "$(uname -s)" == "Linux" ]] || fail "Linux is required"
  [[ -n "${BASH_VERSION:-}" ]] || fail "bash is required"
  command -v sudo >/dev/null 2>&1 || fail "sudo is required"
  command -v systemctl >/dev/null 2>&1 || fail "systemctl is required"
  [[ -d /run/systemd/system ]] || fail "systemd does not appear to be running on this VM"

  [[ -f "$SERVICE_CONFIG_FILE" ]] || fail "service config not found: $SERVICE_CONFIG_FILE"
  [[ -f "$ROOT_DIR/config/app.env.example" ]] || fail "required env example missing: $ROOT_DIR/config/app.env.example"
  [[ -f "$ROOT_DIR/config/environments/$ENVIRONMENT.yml" ]] || fail "environment config not found: config/environments/$ENVIRONMENT.yml"
  [[ -x "$ROOT_DIR/scripts/validate-config.sh" ]] || fail "missing executable: scripts/validate-config.sh"
  [[ -x "$ROOT_DIR/scripts/init-service.sh" ]] || fail "missing executable: scripts/init-service.sh"
  [[ -x "$ROOT_DIR/scripts/deploy.sh" ]] || fail "missing executable: scripts/deploy.sh"

  if [[ -f "$SOURCE_DIR/go.mod" ]]; then
    command -v go >/dev/null 2>&1 || fail "Go is required because the source contains go.mod"
  fi

  if [[ -z "$SERVICE_NAME" ]]; then
    SERVICE_NAME="$(service_discovery_list_services "$SERVICE_CONFIG_FILE" | head -n 1)"
  fi
  [[ -n "$SERVICE_NAME" ]] || fail "no service registered in $SERVICE_CONFIG_FILE"
  [[ -n "$(service_discovery_get_service "$SERVICE_NAME" "$SERVICE_CONFIG_FILE")" ]] || fail "service is not registered: $SERVICE_NAME"

  local proxy_runtime
  proxy_runtime="$(service_field_optional proxy_runtime)"
  [[ -n "$proxy_runtime" ]] || proxy_runtime="nginx"
  case "$proxy_runtime" in
    apache)
      if ! command -v apache2ctl >/dev/null 2>&1 && ! command -v apachectl >/dev/null 2>&1 && ! command -v httpd >/dev/null 2>&1; then
        fail "Apache is required because proxy_runtime=apache"
      fi
      ;;
    nginx)
      command -v nginx >/dev/null 2>&1 || fail "NGINX is required because proxy_runtime=nginx"
      ;;
    *)
      fail "unsupported proxy_runtime for $SERVICE_NAME: $proxy_runtime"
      ;;
  esac
}

validate_configuration() {
  "$ROOT_DIR/scripts/validate-config.sh" "$SERVICE_CONFIG_FILE"
}

prepare_deployment_directories() {
  local deploy_path dir
  deploy_path="$(state_resolve_service_deploy_path "$SERVICE_NAME" "$SERVICE_CONFIG_FILE")"

  for dir in "$deploy_path" "$deploy_path/shared" "$deploy_path/releases" "$deploy_path/logs" "$deploy_path/state"; do
    if ! sudo -n test -d "$dir"; then
      sudo -n mkdir -p "$dir"
      sudo -n chown "$(id -u):$(id -g)" "$dir"
      echo "[onboard] created_directory=$dir"
    fi
  done

  "$ROOT_DIR/scripts/init-service.sh" "$SERVICE_NAME"
}

prepare_env_file() {
  local deploy_path env_file
  deploy_path="$(state_resolve_service_deploy_path "$SERVICE_NAME" "$SERVICE_CONFIG_FILE")"
  env_file="$(service_field_optional env_file)"
  [[ -n "$env_file" ]] || env_file="$deploy_path/shared/.env"

  if sudo -n test -e "$env_file"; then
    echo "[onboard] env_file_exists=$env_file"
    return 0
  fi

  sudo -n mkdir -p "$(dirname "$env_file")"
  sudo -n cp "$ROOT_DIR/config/app.env.example" "$env_file"
  echo "[onboard] created_env_file=$env_file"
  echo "[onboard] ACTION: edit $env_file before using production secrets or service-specific settings."
}

default_artifact_candidates() {
  local source_base
  source_base="$(basename "$SOURCE_DIR")"
  printf '%s\n' \
    "$SOURCE_DIR/dist" \
    "$SOURCE_DIR/build" \
    "$SOURCE_DIR/bin/$source_base" \
    "$SOURCE_DIR/bin/$SERVICE_NAME" \
    "$SOURCE_DIR/$source_base" \
    "$SOURCE_DIR/$SERVICE_NAME" \
    "$SOURCE_DIR/app"
}

resolve_artifact_source() {
  if [[ -n "$ARTIFACT_SOURCE" ]]; then
    ARTIFACT_SOURCE="$(resolve_path_from_source "$ARTIFACT_SOURCE")"
    [[ -e "$ARTIFACT_SOURCE" ]] || fail "artifact source does not exist: $ARTIFACT_SOURCE"
    return 0
  fi

  while IFS= read -r candidate; do
    if [[ -e "$candidate" ]]; then
      ARTIFACT_SOURCE="$candidate"
      echo "[onboard] inferred_artifact=$ARTIFACT_SOURCE"
      return 0
    fi
  done < <(default_artifact_candidates)

  fail "could not infer artifact. Re-run with --artifact <file-or-directory>."
}

build_application() {
  if [[ "${#BUILD_COMMANDS[@]}" -eq 0 ]]; then
    if [[ -f "$SOURCE_DIR/Makefile" || -f "$SOURCE_DIR/makefile" ]]; then
      BUILD_COMMANDS=("make test" "make build")
    else
      fail "no build commands supplied and no Makefile found. Use --build-command."
    fi
  fi

  local command
  for command in "${BUILD_COMMANDS[@]}"; do
    echo "[onboard] build_command=$command"
    (cd "$SOURCE_DIR" && bash -c "$command")
  done

  resolve_artifact_source
}

install_systemd_units_if_needed() {
  local runtime generated_file unit_name installed_file timestamp differences installed_count match_count

  runtime="$(runtime_resolve_runtime "$SERVICE_NAME" "$SERVICE_CONFIG_FILE")"
  [[ "$runtime" == "systemd" ]] || {
    echo "[onboard] runtime=$runtime; skipping systemd unit installation"
    return 0
  }

  "$ROOT_DIR/scripts/init-service.sh" "$SERVICE_NAME" --generate-systemd --systemd-output "$SYSTEMD_BUILD_DIR"

  differences="no"
  installed_count=0
  match_count=0
  for generated_file in "$SYSTEMD_BUILD_DIR/$SERVICE_NAME"-blue.service "$SYSTEMD_BUILD_DIR/$SERVICE_NAME"-green.service; do
    unit_name="$(basename "$generated_file")"
    installed_file="/etc/systemd/system/$unit_name"
    if sudo -n test -e "$installed_file"; then
      installed_count=$(( installed_count + 1 ))
      if sudo -n cmp -s "$generated_file" "$installed_file"; then
        match_count=$(( match_count + 1 ))
        echo "[onboard] Existing service matches generated configuration: $unit_name"
      else
        differences="yes"
        echo "[onboard] Existing systemd service differs from generated version: $unit_name"
      fi
    else
      echo "[onboard] systemd_unit_missing=$installed_file"
    fi
  done

  if [[ "$installed_count" -eq 2 && "$match_count" -eq 2 ]]; then
    echo "[onboard] Existing services already match generated configuration."
  fi

  if [[ "$differences" == "yes" && "$FORCE" != "yes" ]]; then
    fail "Existing systemd service differs from generated version. Re-run with --force to backup and replace units."
  fi

  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  for generated_file in "$SYSTEMD_BUILD_DIR/$SERVICE_NAME"-blue.service "$SYSTEMD_BUILD_DIR/$SERVICE_NAME"-green.service; do
    unit_name="$(basename "$generated_file")"
    installed_file="/etc/systemd/system/$unit_name"
    if sudo -n test -e "$installed_file" && ! sudo -n cmp -s "$generated_file" "$installed_file"; then
      sudo -n cp "$installed_file" "$installed_file.bak.$timestamp"
      echo "[onboard] backed_up=$installed_file.bak.$timestamp"
    fi
    if ! sudo -n test -e "$installed_file" || ! sudo -n cmp -s "$generated_file" "$installed_file"; then
      sudo -n cp "$generated_file" "$installed_file"
      echo "[onboard] installed=$installed_file"
    fi
  done

  sudo -n systemctl daemon-reload
  sudo -n systemctl enable "$SERVICE_NAME-blue.service" "$SERVICE_NAME-green.service" >/dev/null
  echo "[onboard] systemd_units_enabled=$SERVICE_NAME-blue.service,$SERVICE_NAME-green.service"
}

deploy_application() {
  local previous_color active_color
  previous_color="$(state_read_active_color "$SERVICE_NAME" "$SERVICE_CONFIG_FILE")"

  "$ROOT_DIR/scripts/deploy.sh" "$SERVICE_NAME" "$ARTIFACT_SOURCE"

  active_color="$(state_read_active_color "$SERVICE_NAME" "$SERVICE_CONFIG_FILE")"
  if [[ "$previous_color" != "$active_color" ]]; then
    "$ROOT_DIR/scripts/stop-color.sh" "$SERVICE_NAME" "$previous_color"
  fi
}

verify_deployment() {
  local public_port path url
  public_port="$(service_field public_port)"
  for path in "${VERIFY_PATHS[@]}"; do
    url="http://127.0.0.1:$public_port$path"
    echo "[onboard] verify_url=$url"
    "$ROOT_DIR/scripts/healthcheck.sh" "$url"
  done
}

print_summary() {
  local deploy_path active_color current_release
  deploy_path="$(state_resolve_service_deploy_path "$SERVICE_NAME" "$SERVICE_CONFIG_FILE")"
  active_color="$(state_read_active_color "$SERVICE_NAME" "$SERVICE_CONFIG_FILE")"
  current_release="$(readlink "$deploy_path/current" 2>/dev/null || true)"

  cat <<SUMMARY
[onboard] SUMMARY
[onboard] environment=$ENVIRONMENT
[onboard] service=$SERVICE_NAME
[onboard] source=$SOURCE_DIR
[onboard] artifact=$ARTIFACT_SOURCE
[onboard] deploy_path=$deploy_path
[onboard] active_color=$active_color
[onboard] current=${current_release:-unknown}
SUMMARY
}

main() {
  parse_args "$@"
  run_step "validate_environment" validate_environment
  run_step "validate_configuration" validate_configuration
  run_step "prepare_deployment_directories" prepare_deployment_directories
  run_step "prepare_runtime_env" prepare_env_file
  run_step "build_application" build_application
  run_step "prepare_systemd_services" install_systemd_units_if_needed
  run_step "deploy" deploy_application
  run_step "verify" verify_deployment
  print_summary
}

main "$@"
