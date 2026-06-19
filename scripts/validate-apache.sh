#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_path="${1:-}"
source "$ROOT_DIR/scripts/lib/apache.sh"
usage() { cat <<'USAGE'
Usage: ./scripts/validate-apache.sh <generated_config_dir_or_conf_file>
USAGE
}
if [[ "$#" -ne 1 ]]; then usage; exit 2; fi
echo "[validate-apache] config_path=$config_path"
apache_validate_generated_path "$config_path"
echo "[validate-apache] status=valid"
echo "[validate-apache] note=no Apache system path write, Apache reload, traffic switch, rollback, or Jenkins action was performed"
