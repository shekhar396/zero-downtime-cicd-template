#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_CONFIG_FILE="${1:-$ROOT_DIR/config/services.yml}"

# shellcheck source=scripts/lib/service-discovery.sh
source "$ROOT_DIR/scripts/lib/service-discovery.sh"

is_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

validate_services_file() {
  local config_file="$1"

  service_discovery_load "$config_file"
  service_discovery_validate_required_fields "$config_file"

  local tmp_records
  tmp_records="$(mktemp)"
  trap 'rm -f "${VALIDATE_CONFIG_TMP_RECORDS:-}"' EXIT
  VALIDATE_CONFIG_TMP_RECORDS="$tmp_records"

  _service_records "$config_file" > "$tmp_records"

  awk '
    function reset_record() {
      service_name = ""
      runtime = ""
      public_port = ""
      blue_port = ""
      green_port = ""
      health_path = ""
      deploy_path = ""
      nginx_server_name = ""
    }
    function is_number(value) {
      return value ~ /^[0-9]+$/
    }
    function validate_port(service, field, value) {
      if (!is_number(value)) {
        printf "[validate-config] ERROR: %s for %s must be numeric: %s\n", field, service, value > "/dev/stderr"
        errors++
        return
      }
      if (value in ports) {
        printf "[validate-config] ERROR: duplicate port %s used by %s.%s and %s\n", value, service, field, ports[value] > "/dev/stderr"
        errors++
      } else {
        ports[value] = service "." field
      }
    }
    function validate_record() {
      if (service_name == "") {
        return
      }

      service_count++

      if (service_name in service_names) {
        printf "[validate-config] ERROR: duplicate service_name: %s\n", service_name > "/dev/stderr"
        errors++
      } else {
        service_names[service_name] = 1
      }

      validate_port(service_name, "public_port", public_port)
      validate_port(service_name, "blue_port", blue_port)
      validate_port(service_name, "green_port", green_port)

      if (blue_port == green_port) {
        printf "[validate-config] ERROR: blue_port and green_port must differ for %s\n", service_name > "/dev/stderr"
        errors++
      }

      if (health_path !~ /^\//) {
        printf "[validate-config] ERROR: health_path must begin with / for %s: %s\n", service_name, health_path > "/dev/stderr"
        errors++
      }

      if (deploy_path !~ /^\//) {
        printf "[validate-config] ERROR: deploy_path must be absolute for %s: %s\n", service_name, deploy_path > "/dev/stderr"
        errors++
      }
    }
    BEGIN { reset_record() }
    $0 == "---" {
      validate_record()
      reset_record()
      next
    }
    {
      split($0, parts, "=")
      key = parts[1]
      value = substr($0, length(key) + 2)
      if (key == "service_name") service_name = value
      else if (key == "runtime") runtime = value
      else if (key == "public_port") public_port = value
      else if (key == "blue_port") blue_port = value
      else if (key == "green_port") green_port = value
      else if (key == "health_path") health_path = value
      else if (key == "deploy_path") deploy_path = value
      else if (key == "nginx_server_name") nginx_server_name = value
    }
    END {
      validate_record()
      if (service_count == 0) {
        print "[validate-config] ERROR: no services registered" > "/dev/stderr"
        errors++
      }
      exit errors ? 1 : 0
    }
  ' "$tmp_records"

  echo "[validate-config] Configuration is valid: $config_file"
  echo "[validate-config] Registered services:"
  service_discovery_list_services "$config_file" | sed 's/^/  - /'
}

validate_services_file "$SERVICE_CONFIG_FILE"
