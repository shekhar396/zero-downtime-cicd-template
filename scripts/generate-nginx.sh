#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_CONFIG_FILE="${SERVICE_CONFIG_FILE:-$ROOT_DIR/config/services.yml}"
output_dir="$ROOT_DIR/build/nginx"
service_name=""
source "$ROOT_DIR/scripts/lib/service-discovery.sh"
source "$ROOT_DIR/scripts/lib/nginx.sh"
usage() { cat <<'USAGE'
Usage: ./scripts/generate-nginx.sh [--service <service_name>] [--output <output_dir>]
USAGE
}
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --service) [[ "$#" -ge 2 ]] || { echo "[generate-nginx] ERROR: --service requires a value" >&2; exit 2; }; service_name="$2"; shift 2 ;;
    --output) [[ "$#" -ge 2 ]] || { echo "[generate-nginx] ERROR: --output requires a value" >&2; exit 2; }; output_dir="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[generate-nginx] ERROR: unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done
echo "[generate-nginx] step=validate_config"
"$ROOT_DIR/scripts/validate-config.sh" "$SERVICE_CONFIG_FILE" >/dev/null
mkdir -p "$output_dir"
if [[ -n "$service_name" ]]; then
  generated_file="$(nginx_generate_service_config "$service_name" "$output_dir" "$SERVICE_CONFIG_FILE")"
  echo "[generate-nginx] generated=$generated_file"
else
  while IFS= read -r generated_file; do echo "[generate-nginx] generated=$generated_file"; done < <(nginx_generate_all_configs "$output_dir" "$SERVICE_CONFIG_FILE")
fi
echo "[generate-nginx] output_dir=$output_dir"
echo "[generate-nginx] note=no /etc/nginx write, nginx reload, active_color change, rollback, or Jenkins action was performed"
