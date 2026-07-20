#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_CONFIG_FILE="${SERVICE_CONFIG_FILE:-$ROOT_DIR/config/services.yml}"
generate_systemd="no"
install_systemd="no"
all_services="no"
assume_yes="no"
service_name=""
systemd_output_dir="$ROOT_DIR/build/systemd"

# shellcheck source=scripts/lib/service-discovery.sh
source "$ROOT_DIR/scripts/lib/service-discovery.sh"
# shellcheck source=scripts/lib/state.sh
source "$ROOT_DIR/scripts/lib/state.sh"
# shellcheck source=scripts/lib/runtime.sh
source "$ROOT_DIR/scripts/lib/runtime.sh"
# shellcheck source=scripts/lib/systemd.sh
source "$ROOT_DIR/scripts/lib/systemd.sh"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/init-service.sh [<service_name>] [options]
  ./scripts/init-service.sh --all [options]

Without a service name or --all, displays an interactive service selector.

Options:
  --all                    Initialize all registered services.
  --generate-systemd       Generate blue/green units for systemd services.
  --install-systemd        Generate, install, reload, and enable both units.
  --systemd-output <dir>   Write generated units to this directory.
  --yes                    Skip confirmation prompts (for example, in Jenkins).
  -h, --help               Show this help.

Systemd installation creates symlinks in /etc/systemd/system by default. It
enables both color units but never starts or restarts them. No deployment or
proxy traffic switch is performed.
USAGE
}

cli_error() {
  echo "[init-service] ERROR: $*" >&2
  usage >&2
  exit 2
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --all)
      all_services="yes"
      shift
      ;;
    --generate-systemd)
      generate_systemd="yes"
      shift
      ;;
    --install-systemd)
      install_systemd="yes"
      generate_systemd="yes"
      shift
      ;;
    --systemd-output)
      [[ "$#" -ge 2 ]] || cli_error "--systemd-output requires a value"
      [[ -n "$2" ]] || cli_error "--systemd-output requires a non-empty value"
      systemd_output_dir="$2"
      shift 2
      ;;
    --yes)
      assume_yes="yes"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      cli_error "unknown argument: $1"
      ;;
    *)
      if [[ -n "$service_name" ]]; then
        cli_error "only one service name may be supplied"
      fi
      service_name="$1"
      shift
      ;;
  esac
done

if [[ "$all_services" == "yes" && -n "$service_name" ]]; then
  cli_error "a service name and --all are mutually exclusive"
fi

echo "[init-service] Validating service configuration..."
"$ROOT_DIR/scripts/validate-config.sh" "$SERVICE_CONFIG_FILE" >/dev/null

services=()
while IFS= read -r discovered_service; do
  [[ -n "$discovered_service" ]] && services+=("$discovered_service")
done < <(service_discovery_list_services "$SERVICE_CONFIG_FILE")

if [[ "${#services[@]}" -eq 0 ]]; then
  echo "[init-service] ERROR: no registered services were found" >&2
  exit 1
fi

service_is_registered() {
  local candidate="$1" registered
  for registered in "${services[@]}"; do
    [[ "$candidate" == "$registered" ]] && return 0
  done
  return 1
}

select_service_interactively() {
  local selection index

  echo "[init-service] Registered services:"
  for index in "${!services[@]}"; do
    printf '  %d) %s\n' "$((index + 1))" "${services[$index]}"
  done
  printf 'Select a service [1-%d]: ' "${#services[@]}"
  if ! IFS= read -r selection; then
    echo "[init-service] ERROR: interactive service selection requires input" >&2
    return 1
  fi
  if [[ ! "$selection" =~ ^[0-9]+$ ]] || (( selection < 1 || selection > ${#services[@]} )); then
    echo "[init-service] ERROR: invalid service selection: $selection" >&2
    return 1
  fi
  service_name="${services[$((selection - 1))]}"
}

if [[ "$all_services" == "no" && -z "$service_name" ]]; then
  select_service_interactively
fi

if [[ "$all_services" == "no" ]] && ! service_is_registered "$service_name"; then
  echo "[init-service] ERROR: service is not registered: $service_name" >&2
  exit 1
fi

confirm_or_cancel() {
  local response
  if [[ "$assume_yes" == "yes" ]]; then
    return 0
  fi
  printf 'Continue? [Y/n]: '
  if ! IFS= read -r response; then
    response=""
  fi
  case "$response" in
    n|N|no|NO|No)
      echo "[init-service] Cancelled. No changes were made."
      exit 0
      ;;
  esac
}

print_single_plan() {
  local selected_service="$1" runtime deploy_path
  runtime="$(runtime_resolve_runtime "$selected_service" "$SERVICE_CONFIG_FILE")"
  deploy_path="$(state_resolve_service_deploy_path "$selected_service" "$SERVICE_CONFIG_FILE")"

  cat <<EOF
[init-service] Service initialization plan

Service: $selected_service
Runtime: $runtime
Deploy path: $deploy_path

Systemd services:
  - $(systemd_unit_name "$selected_service" blue)
  - $(systemd_unit_name "$selected_service" green)

EOF
}

print_all_plan() {
  local selected_service
  echo "[init-service] Services selected for initialization:"
  echo
  for selected_service in "${services[@]}"; do
    echo "  - $selected_service"
  done
  echo
}

print_systemd_conflict() {
  local selected_service="$1"
  shift
  local -a existing_units=("$@")
  local blue_unit green_unit existing
  blue_unit="$(systemd_unit_name "$selected_service" blue)"
  green_unit="$(systemd_unit_name "$selected_service" green)"

  if [[ "${#existing_units[@]}" -eq 2 ]]; then
    echo "[init-service] ERROR: systemd services already exist for: $selected_service" >&2
    echo >&2
    echo "Detected:" >&2
    printf '  - %s\n' "${existing_units[@]}" >&2
    echo >&2
    echo "No systemd files were installed or modified." >&2
    return
  fi

  existing="${existing_units[0]}"
  echo "[init-service] ERROR: incomplete blue/green systemd installation detected" >&2
  echo >&2
  echo "Existing:" >&2
  echo "  - $existing" >&2
  echo >&2
  echo "Missing:" >&2
  if [[ "$existing" == "$blue_unit" ]]; then
    echo "  - $green_unit" >&2
  else
    echo "  - $blue_unit" >&2
  fi
  echo >&2
  echo "Review the existing systemd configuration manually." >&2
  echo "No changes were made." >&2
}

initialize_service_state() {
  local selected_service="$1" deploy_path active_color_file history_file
  local active_existed="no" history_existed="no" active_color inactive_color

  deploy_path="$(state_resolve_service_deploy_path "$selected_service" "$SERVICE_CONFIG_FILE")"
  active_color_file="$(state_active_color_file "$selected_service" "$SERVICE_CONFIG_FILE")"
  history_file="$(state_history_file "$selected_service" "$SERVICE_CONFIG_FILE")"
  [[ -e "$active_color_file" ]] && active_existed="yes"
  [[ -e "$history_file" ]] && history_existed="yes"

  echo "[init-service] Initializing service: $selected_service"
  echo "[init-service] Deploy path: $deploy_path"
  if ! state_initialize_service_directories "$selected_service" "$SERVICE_CONFIG_FILE"; then
    return 1
  fi

  if ! active_color="$(state_read_active_color "$selected_service" "$SERVICE_CONFIG_FILE")"; then
    return 1
  fi
  if ! inactive_color="$(state_determine_inactive_color "$selected_service" "$SERVICE_CONFIG_FILE")"; then
    return 1
  fi
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
}

generate_units() {
  local selected_service="$1" generated_unit generated_units
  echo "[init-service] Generating systemd units..."
  if ! generated_units="$(systemd_generate_service_units "$selected_service" "$systemd_output_dir" "$SERVICE_CONFIG_FILE")"; then
    return 1
  fi
  while IFS= read -r generated_unit; do
    [[ -n "$generated_unit" ]] || continue
    echo "[init-service] generated=$generated_unit"
  done <<< "$generated_units"
  if ! systemd_validate_generated_units "$selected_service" "$systemd_output_dir"; then
    return 1
  fi
  echo "[init-service] systemd_output_dir=$systemd_output_dir"
}

PROCESS_RESULT_REASON=""
process_service() {
  local selected_service="$1" runtime
  local -a existing_units=()
  PROCESS_RESULT_REASON=""
  runtime="$(runtime_resolve_runtime "$selected_service" "$SERVICE_CONFIG_FILE")"

  if [[ "$generate_systemd" == "yes" && "$runtime" != "systemd" ]]; then
    if [[ "$all_services" == "no" ]]; then
      echo "[init-service] ERROR: systemd generation requires runtime: systemd" >&2
      return 1
    fi
    initialize_service_state "$selected_service"
    PROCESS_RESULT_REASON="Systemd portion skipped (runtime: $runtime)"
    return 0
  fi

  if [[ "$generate_systemd" == "yes" ]]; then
    while IFS= read -r existing_unit; do
      [[ -n "$existing_unit" ]] && existing_units+=("$existing_unit")
    done < <(systemd_existing_service_units "$selected_service")
    if [[ "${#existing_units[@]}" -gt 0 ]]; then
      print_systemd_conflict "$selected_service" "${existing_units[@]}"
      PROCESS_RESULT_REASON="Existing systemd services detected"
      return 3
    fi
  fi

  if [[ "$install_systemd" == "yes" ]]; then
    if ! systemd_validate_sudo_access "$assume_yes"; then
      echo "[init-service] ERROR: required sudo access is unavailable for: $selected_service" >&2
      PROCESS_RESULT_REASON="Required sudo access is unavailable"
      return 1
    fi
  fi

  if ! initialize_service_state "$selected_service"; then
    PROCESS_RESULT_REASON="Directory or state initialization failed"
    return 1
  fi

  if [[ "$generate_systemd" == "yes" ]]; then
    if ! generate_units "$selected_service"; then
      PROCESS_RESULT_REASON="Generated unit validation failed"
      return 1
    fi
  fi

  if [[ "$install_systemd" == "yes" ]]; then
    if ! systemd_install_service_units "$selected_service" "$systemd_output_dir"; then
      PROCESS_RESULT_REASON="Systemd installation failed and was rolled back"
      return 1
    fi
  fi
}

print_install_success() {
  local selected_service="$1" runtime deploy_path absolute_output_dir blue_unit green_unit
  runtime="$(runtime_resolve_runtime "$selected_service" "$SERVICE_CONFIG_FILE")"
  deploy_path="$(state_resolve_service_deploy_path "$selected_service" "$SERVICE_CONFIG_FILE")"
  absolute_output_dir="$(cd "$systemd_output_dir" && pwd -P)"
  blue_unit="$(systemd_unit_name "$selected_service" blue)"
  green_unit="$(systemd_unit_name "$selected_service" green)"

  cat <<EOF
[init-service] Initialization completed successfully

Service:
  $selected_service

Runtime:
  $runtime

Deploy path:
  $deploy_path

Directories:
  - $deploy_path/releases
  - $deploy_path/shared
  - $deploy_path/state

Generated units:
  - $absolute_output_dir/$blue_unit
  - $absolute_output_dir/$green_unit

Installed units:
  - $SYSTEMD_UNIT_DIR/$blue_unit
  - $SYSTEMD_UNIT_DIR/$green_unit

Systemd daemon reload:
  successful

Enablement:
  - $blue_unit: enabled
  - $green_unit: enabled

Services started:
  no

No deployment was performed.
EOF
}

if [[ "$all_services" == "yes" ]]; then
  print_all_plan
  confirm_or_cancel

  result_statuses=()
  result_reasons=()
  successful=0
  skipped=0
  failed=0
  for selected_service in "${services[@]}"; do
    echo "[init-service] Processing: $selected_service"
    if process_service "$selected_service"; then
      result_statuses+=("SUCCESS")
      result_reasons+=("$PROCESS_RESULT_REASON")
      successful=$((successful + 1))
    else
      result_code="$?"
      if [[ "$result_code" -eq 3 ]]; then
        result_statuses+=("SKIPPED")
        result_reasons+=("${PROCESS_RESULT_REASON:-Existing systemd services detected}")
        skipped=$((skipped + 1))
      else
        result_statuses+=("FAILED")
        result_reasons+=("${PROCESS_RESULT_REASON:-Initialization failed}")
        failed=$((failed + 1))
      fi
    fi
  done

  echo
  echo "[init-service] Results:"
  echo
  for index in "${!services[@]}"; do
    printf '[%s] %s\n' "${result_statuses[$index]}" "${services[$index]}"
    if [[ -n "${result_reasons[$index]}" ]]; then
      printf '          %s\n' "${result_reasons[$index]}"
    fi
  done
  echo
  echo "Summary:"
  echo "  Successful: $successful"
  echo "  Skipped: $skipped"
  echo "  Failed: $failed"
  echo
  echo "No deployment was performed."
  if (( skipped > 0 || failed > 0 )); then
    exit 1
  fi
  exit 0
fi

runtime="$(runtime_resolve_runtime "$service_name" "$SERVICE_CONFIG_FILE")"
if [[ "$install_systemd" == "yes" && "$runtime" != "systemd" ]]; then
  echo "[init-service] ERROR: --install-systemd requires runtime: systemd" >&2
  exit 1
fi
if [[ "$generate_systemd" == "yes" && "$runtime" != "systemd" ]]; then
  echo "[init-service] ERROR: --generate-systemd requires runtime: systemd" >&2
  exit 1
fi

print_single_plan "$service_name"
confirm_or_cancel

if ! process_service "$service_name"; then
  exit 1
fi

if [[ "$install_systemd" == "yes" ]]; then
  print_install_success "$service_name"
else
  echo "[init-service] Done. No deployment was performed."
fi
