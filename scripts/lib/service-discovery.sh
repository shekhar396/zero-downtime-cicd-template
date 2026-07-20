#!/usr/bin/env bash
# Service discovery helpers for the v1.0.0 configuration foundation.
# The parser intentionally supports the flat YAML service format used by
# config/services.yml and avoids external dependencies such as yq.

set -euo pipefail

SERVICE_CONFIG_FILE="${SERVICE_CONFIG_FILE:-config/services.yml}"
SERVICE_REQUIRED_FIELDS=(
  service_name
  runtime
  public_port
  blue_port
  green_port
  health_path
  deploy_path
  nginx_server_name
)

service_discovery_load() {
  local config_file="${1:-$SERVICE_CONFIG_FILE}"

  if [[ ! -f "$config_file" ]]; then
    echo "[service-discovery] ERROR: service config not found: $config_file" >&2
    return 1
  fi

  if [[ ! -r "$config_file" ]]; then
    echo "[service-discovery] ERROR: service config is not readable: $config_file" >&2
    return 1
  fi

  SERVICE_CONFIG_FILE="$config_file"
}

_service_records() {
  local config_file="${1:-$SERVICE_CONFIG_FILE}"

  awk '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^"|"$/, "", value)
      gsub(/^'\''|'\''$/, "", value)
      return value
    }
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    /^[[:space:]]*-[[:space:]]*service_name:[[:space:]]*/ {
      if (in_record) {
        print "---"
      }
      in_record = 1
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*service_name:[[:space:]]*/, "", line)
      print "service_name=" trim(line)
      next
    }
    in_record && /^[[:space:]]+[A-Za-z_][A-Za-z0-9_]*:[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      key = line
      sub(/:.*/, "", key)
      value = line
      sub(/^[^:]+:[[:space:]]*/, "", value)
      print key "=" trim(value)
      next
    }
  ' "$config_file"
}

service_discovery_list_services() {
  local config_file="${1:-$SERVICE_CONFIG_FILE}"
  service_discovery_load "$config_file" >/dev/null

  _service_records "$config_file" | awk -F= '$1 == "service_name" { print $2 }'
}

service_discovery_get_service() {
  local service_name="${1:?service name is required}"
  local config_file="${2:-$SERVICE_CONFIG_FILE}"

  service_discovery_load "$config_file" >/dev/null

  _service_records "$config_file" | awk -v target="$service_name" '
    $0 == "---" {
      if (match_record) {
        print buffer
        found = 1
        exit
      }
      buffer = ""
      match_record = 0
      next
    }
    {
      if ($0 == "service_name=" target) {
        match_record = 1
      }
      buffer = buffer $0 "\n"
    }
    END {
      if (!found && match_record) {
        printf "%s", buffer
      }
    }
  '
}

service_discovery_validate_required_fields() {
  local config_file="${1:-$SERVICE_CONFIG_FILE}"
  service_discovery_load "$config_file" >/dev/null

  _service_records "$config_file" | awk '
    function reset_record() {
      service = ""
      delete seen
      record_number++
    }
    function validate_record() {
      if (record_number == 0) {
        return
      }
      split("service_name runtime public_port blue_port green_port health_path deploy_path nginx_server_name", required, " ")
      for (i in required) {
        field = required[i]
        if (!(field in seen) || seen[field] == "") {
          label = service == "" ? "record " record_number : service
          printf "[service-discovery] ERROR: missing required field %s for %s\n", field, label > "/dev/stderr"
          errors++
        }
      }
    }
    BEGIN { record_number = 0 }
    $0 == "---" {
      validate_record()
      reset_record()
      next
    }
    record_number == 0 { reset_record() }
    {
      split($0, parts, "=")
      key = parts[1]
      value = substr($0, length(key) + 2)
      seen[key] = value
      if (key == "service_name") {
        service = value
      }
    }
    END {
      validate_record()
      exit errors ? 1 : 0
    }
  '
}

_service_discovery_usage() {
  cat <<'USAGE'
Usage: scripts/lib/service-discovery.sh <command> [args]

Commands:
  list [config-file]                 List registered service names.
  get <service-name> [config-file]   Print one service definition as key=value lines.
  validate [config-file]             Validate required fields exist.
USAGE
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  command="${1:-}"
  case "$command" in
    list)
      shift
      service_discovery_list_services "${1:-$SERVICE_CONFIG_FILE}"
      ;;
    get)
      shift
      if [[ "$#" -lt 1 ]]; then
        _service_discovery_usage
        exit 1
      fi
      service_discovery_get_service "$1" "${2:-$SERVICE_CONFIG_FILE}"
      ;;
    validate)
      shift
      service_discovery_validate_required_fields "${1:-$SERVICE_CONFIG_FILE}"
      ;;
    -h|--help|help|"")
      _service_discovery_usage
      ;;
    *)
      echo "[service-discovery] ERROR: unknown command: $command" >&2
      _service_discovery_usage
      exit 1
      ;;
  esac
fi
