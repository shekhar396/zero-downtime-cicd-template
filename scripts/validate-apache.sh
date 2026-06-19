#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_dir="${1:-}"
source "$ROOT_DIR/scripts/lib/apache.sh"
usage() { cat <<'USAGE'
Usage: ./scripts/validate-apache.sh <generated_config_dir>
USAGE
}
if [[ "$#" -ne 1 ]]; then usage; exit 2; fi
echo "[validate-apache] config_dir=$config_dir"
apache_validate_generated_dir "$config_dir"
echo "[validate-apache] status=valid"
echo "[validate-apache] note=no Apache system path write, Apache reload, traffic switch, rollback, or Jenkins action was performed"
