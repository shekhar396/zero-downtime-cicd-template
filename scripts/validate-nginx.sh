#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_dir="${1:-}"
source "$ROOT_DIR/scripts/lib/nginx.sh"
usage() { cat <<'USAGE'
Usage: ./scripts/validate-nginx.sh <generated_config_dir>
USAGE
}
if [[ "$#" -ne 1 ]]; then usage; exit 2; fi
echo "[validate-nginx] config_dir=$config_dir"
nginx_validate_generated_dir "$config_dir"
echo "[validate-nginx] status=valid"
echo "[validate-nginx] note=no /etc/nginx write, nginx reload, traffic switch, rollback, or Jenkins action was performed"
