#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/init-service.sh"
TEST_ROOT="$(mktemp -d)"
cleanup() {
  if [[ "${KEEP_TEST_ROOT:-no}" == "yes" ]]; then
    echo "Preserved test fixtures: $TEST_ROOT" >&2
  else
    rm -rf "$TEST_ROOT"
  fi
}
trap cleanup EXIT

passed=0
failed=0
command_output=""
command_status=0

pass() {
  echo "ok - $1"
  passed=$((passed + 1))
}

fail() {
  echo "not ok - $1" >&2
  echo "$command_output" >&2
  failed=$((failed + 1))
}

assert_contains() {
  [[ "$command_output" == *"$1"* ]]
}

assert_not_contains() {
  [[ "$command_output" != *"$1"* ]]
}

write_config() {
  cat > "$SERVICE_CONFIG_FILE" <<EOF
services:
  - service_name: alpha-api
    runtime: systemd
    public_port: 8080
    blue_port: 18080
    green_port: 18081
    health_path: /health
    deploy_path: $TEST_CASE_DIR/deploy/alpha
    nginx_server_name: _
    start_command: systemctl restart alpha-api-{color}
    stop_command: systemctl stop alpha-api-{color}
    status_command: systemctl is-active alpha-api-{color}
    env_file: $TEST_CASE_DIR/deploy/alpha/shared/.env
    executable: bin/alpha-api
    user: alpha
    group: alpha
  - service_name: beta-web
    runtime: container
    public_port: 8081
    blue_port: 18082
    green_port: 18083
    health_path: /health
    deploy_path: $TEST_CASE_DIR/deploy/beta
    nginx_server_name: _
EOF
}

write_mocks() {
  cat > "$TEST_CASE_DIR/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -u
echo "systemctl $*" >> "$MOCK_LOG"
command_name="${1:-}"
shift || true
case "$command_name" in
  cat)
    unit="${1:-}"
    [[ " ${MOCK_EXISTING:-} " == *" $unit "* ]] && exit 0
    exit 1
    ;;
  show)
    unit="${1:-}"
    if [[ " ${MOCK_EXISTING:-} " == *" $unit "* || -e "$SYSTEMD_UNIT_DIR/$unit" || -L "$SYSTEMD_UNIT_DIR/$unit" ]]; then
      echo "${MOCK_LOAD_STATE:-loaded}"
    else
      echo "not-found"
    fi
    ;;
  list-unit-files)
    unit="${1:-}"
    [[ " ${MOCK_EXISTING:-} " == *" $unit "* ]] && echo "$unit disabled"
    ;;
  daemon-reload)
    [[ "${MOCK_FAIL_RELOAD:-no}" == "yes" ]] && exit 1
    exit 0
    ;;
  enable)
    unit="${1:-}"
    [[ "${MOCK_FAIL_ENABLE:-}" == "$unit" ]] && exit 1
    : > "$MOCK_STATE_DIR/enabled-$unit"
    ;;
  disable)
    unit="${1:-}"
    rm -f "$MOCK_STATE_DIR/enabled-$unit"
    ;;
  is-enabled)
    unit="${1:-}"
    [[ -e "$MOCK_STATE_DIR/enabled-$unit" ]] && { echo enabled; exit 0; }
    echo disabled
    exit 1
    ;;
  start|restart)
    exit 99
    ;;
esac
EOF

  cat > "$TEST_CASE_DIR/bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -u
echo "sudo $*" >> "$MOCK_LOG"
if [[ "${1:-}" == "-n" && "${2:-}" == "true" ]]; then
  [[ "${MOCK_FAIL_SUDO:-no}" == "yes" ]] && exit 1
  exit 0
fi
if [[ "${1:-}" == "-v" ]]; then
  [[ "${MOCK_FAIL_SUDO:-no}" == "yes" ]] && exit 1
  exit 0
fi
if [[ "${1:-}" == "ln" && "${MOCK_FAIL_LINK_COLOR:-}" != "" ]]; then
  target="${4:-}"
  [[ "$target" == *"-${MOCK_FAIL_LINK_COLOR}.service" ]] && exit 1
fi
exec "$@"
EOF

  cat > "$TEST_CASE_DIR/bin/systemd-analyze" <<'EOF'
#!/usr/bin/env bash
set -u
echo "systemd-analyze $*" >> "$MOCK_LOG"
[[ "${MOCK_FAIL_ANALYZE:-no}" == "yes" ]] && exit 1
exit 0
EOF
  chmod +x "$TEST_CASE_DIR/bin/systemctl" "$TEST_CASE_DIR/bin/sudo" "$TEST_CASE_DIR/bin/systemd-analyze"
}

setup_case() {
  TEST_CASE_DIR="$TEST_ROOT/case-$((passed + failed + 1))-$RANDOM"
  SERVICE_CONFIG_FILE="$TEST_CASE_DIR/services.yml"
  SYSTEMD_UNIT_DIR="$TEST_CASE_DIR/units"
  SYSTEMD_OUTPUT_DIR="$TEST_CASE_DIR/generated units"
  MOCK_STATE_DIR="$TEST_CASE_DIR/state"
  MOCK_LOG="$TEST_CASE_DIR/commands.log"
  mkdir -p "$TEST_CASE_DIR/bin" "$SYSTEMD_UNIT_DIR" "$MOCK_STATE_DIR"
  : > "$MOCK_LOG"
  export TEST_CASE_DIR SERVICE_CONFIG_FILE SYSTEMD_UNIT_DIR SYSTEMD_OUTPUT_DIR
  export MOCK_STATE_DIR MOCK_LOG
  export MOCK_EXISTING="" MOCK_FAIL_RELOAD="no" MOCK_FAIL_ENABLE=""
  export MOCK_FAIL_LINK_COLOR="" MOCK_FAIL_ANALYZE="no" MOCK_FAIL_SUDO="no"
  write_config
  write_mocks
}

run_init() {
  set +e
  command_output="$(
    SERVICE_CONFIG_FILE="$SERVICE_CONFIG_FILE" \
    SYSTEMD_UNIT_DIR="$SYSTEMD_UNIT_DIR" \
    SYSTEMCTL_BIN="$TEST_CASE_DIR/bin/systemctl" \
    SUDO_BIN="$TEST_CASE_DIR/bin/sudo" \
    SYSTEMD_ANALYZE_BIN="$TEST_CASE_DIR/bin/systemd-analyze" \
      "$SCRIPT" "$@" 2>&1
  )"
  command_status=$?
  set -e
}

test_named_initialization_and_preservation() {
  setup_case
  run_init alpha-api --yes
  [[ "$command_status" -eq 0 && -d "$TEST_CASE_DIR/deploy/alpha/releases" && \
     -d "$TEST_CASE_DIR/deploy/alpha/shared" && -d "$TEST_CASE_DIR/deploy/alpha/state" ]] || return 1
  printf 'green\n' > "$TEST_CASE_DIR/deploy/alpha/state/active_color"
  printf 'existing history\n' > "$TEST_CASE_DIR/deploy/alpha/state/history.log"
  run_init alpha-api --yes
  [[ "$command_status" -eq 0 ]] || return 1
  [[ "$(< "$TEST_CASE_DIR/deploy/alpha/state/active_color")" == "green" ]] || return 1
  [[ "$(< "$TEST_CASE_DIR/deploy/alpha/state/history.log")" == "existing history" ]] || return 1
  assert_contains "Preserved existing active color: green" && assert_contains "Preserved existing history file"
}

test_generate_only() {
  setup_case
  run_init alpha-api --generate-systemd --systemd-output "$SYSTEMD_OUTPUT_DIR" --yes
  [[ "$command_status" -eq 0 && -s "$SYSTEMD_OUTPUT_DIR/alpha-api-blue.service" && \
     -s "$SYSTEMD_OUTPUT_DIR/alpha-api-green.service" ]] || return 1
  grep -q '^Environment=ZERO_DOWNTIME_EXECUTABLE=bin/alpha-api$' "$SYSTEMD_OUTPUT_DIR/alpha-api-blue.service" || return 1
  grep -q 'export RELEASE_ID=' "$SYSTEMD_OUTPUT_DIR/alpha-api-blue.service" || return 1
  grep -q '^User=alpha$' "$SYSTEMD_OUTPUT_DIR/alpha-api-blue.service" || return 1
  grep -q '^Group=alpha$' "$SYSTEMD_OUTPUT_DIR/alpha-api-blue.service" || return 1
  [[ ! -e "$SYSTEMD_UNIT_DIR/alpha-api-blue.service" && ! -L "$SYSTEMD_UNIT_DIR/alpha-api-blue.service" ]] || return 1
  ! grep -Eq 'daemon-reload| enable | start | restart ' "$MOCK_LOG"
}

test_successful_install() {
  setup_case
  run_init alpha-api --install-systemd --systemd-output "$SYSTEMD_OUTPUT_DIR" --yes
  [[ "$command_status" -eq 0 ]] || return 1
  [[ -L "$SYSTEMD_UNIT_DIR/alpha-api-blue.service" && -L "$SYSTEMD_UNIT_DIR/alpha-api-green.service" ]] || return 1
  [[ "$(readlink "$SYSTEMD_UNIT_DIR/alpha-api-blue.service")" == /* ]] || return 1
  grep -q 'enable alpha-api-blue.service' "$MOCK_LOG" && grep -q 'enable alpha-api-green.service' "$MOCK_LOG" || return 1
  ! grep -Eq 'systemctl (start|restart)' "$MOCK_LOG"
}

test_invalid_cli_combination() {
  setup_case
  run_init alpha-api --all --yes
  [[ "$command_status" -eq 2 ]] && assert_contains "mutually exclusive"
}

test_interactive_selection() {
  setup_case
  set +e
  command_output="$(printf '1\n\n' | SERVICE_CONFIG_FILE="$SERVICE_CONFIG_FILE" SYSTEMD_UNIT_DIR="$SYSTEMD_UNIT_DIR" \
    SYSTEMCTL_BIN="$TEST_CASE_DIR/bin/systemctl" SUDO_BIN="$TEST_CASE_DIR/bin/sudo" \
    SYSTEMD_ANALYZE_BIN="$TEST_CASE_DIR/bin/systemd-analyze" "$SCRIPT" 2>&1)"
  command_status=$?
  set -e
  [[ "$command_status" -eq 0 && -d "$TEST_CASE_DIR/deploy/alpha/state" ]] || return 1
  assert_contains "1) alpha-api" && assert_contains "Select a service"
}

test_all_discovers_services() {
  setup_case
  run_init --all --yes
  [[ "$command_status" -eq 0 && -d "$TEST_CASE_DIR/deploy/alpha/state" && -d "$TEST_CASE_DIR/deploy/beta/state" ]] || return 1
  assert_contains "[SUCCESS] alpha-api" && assert_contains "[SUCCESS] beta-web" && assert_contains "Successful: 2"
}

test_unregistered_service() {
  setup_case
  run_init missing-api --yes
  [[ "$command_status" -ne 0 ]] && assert_contains "service is not registered"
}

test_non_systemd_install_rejected() {
  setup_case
  run_init beta-web --install-systemd --yes
  [[ "$command_status" -ne 0 && ! -d "$TEST_CASE_DIR/deploy/beta" ]] && assert_contains "--install-systemd requires runtime: systemd"
}

test_conflicts() {
  local scenario existing expected
  for scenario in blue green pair; do
    setup_case
    case "$scenario" in
      blue) existing="alpha-api-blue.service"; expected="incomplete blue/green" ;;
      green) existing="alpha-api-green.service"; expected="incomplete blue/green" ;;
      pair) existing="alpha-api-blue.service alpha-api-green.service"; expected="systemd services already exist" ;;
    esac
    export MOCK_EXISTING="$existing"
    run_init alpha-api --install-systemd --systemd-output "$SYSTEMD_OUTPUT_DIR" --yes
    [[ "$command_status" -ne 0 && ! -d "$TEST_CASE_DIR/deploy/alpha" ]] || return 1
    assert_contains "$expected" || return 1
  done

  setup_case
  ln -s "$TEST_CASE_DIR/missing-target" "$SYSTEMD_UNIT_DIR/alpha-api-blue.service"
  run_init alpha-api --install-systemd --systemd-output "$SYSTEMD_OUTPUT_DIR" --yes
  [[ "$command_status" -ne 0 && -L "$SYSTEMD_UNIT_DIR/alpha-api-blue.service" ]] && assert_contains "incomplete blue/green"
}

test_validation_failure_prevents_install() {
  setup_case
  export MOCK_FAIL_ANALYZE="yes"
  run_init alpha-api --install-systemd --systemd-output "$SYSTEMD_OUTPUT_DIR" --yes
  [[ "$command_status" -ne 0 && ! -e "$SYSTEMD_UNIT_DIR/alpha-api-blue.service" ]] && assert_contains "generated unit validation failed"
}

test_link_failure_rolls_back() {
  setup_case
  export MOCK_FAIL_LINK_COLOR="green"
  run_init alpha-api --install-systemd --systemd-output "$SYSTEMD_OUTPUT_DIR" --yes
  [[ "$command_status" -ne 0 && ! -e "$SYSTEMD_UNIT_DIR/alpha-api-blue.service" && \
     ! -L "$SYSTEMD_UNIT_DIR/alpha-api-blue.service" ]] && assert_contains "Rolled back systemd changes"
}

test_reload_failure_rolls_back() {
  setup_case
  export MOCK_FAIL_RELOAD="yes"
  run_init alpha-api --install-systemd --systemd-output "$SYSTEMD_OUTPUT_DIR" --yes
  [[ "$command_status" -ne 0 && ! -L "$SYSTEMD_UNIT_DIR/alpha-api-blue.service" && \
     ! -L "$SYSTEMD_UNIT_DIR/alpha-api-green.service" ]] && assert_contains "Rolled back systemd changes"
}

test_enable_failure_rolls_back() {
  setup_case
  export MOCK_FAIL_ENABLE="alpha-api-green.service"
  run_init alpha-api --install-systemd --systemd-output "$SYSTEMD_OUTPUT_DIR" --yes
  [[ "$command_status" -ne 0 && ! -L "$SYSTEMD_UNIT_DIR/alpha-api-blue.service" && \
     ! -e "$MOCK_STATE_DIR/enabled-alpha-api-blue.service" ]] || return 1
  grep -q 'disable alpha-api-blue.service' "$MOCK_LOG" && assert_contains "Rolled back systemd changes"
}

test_all_continues_and_summarizes_conflict() {
  setup_case
  export MOCK_EXISTING="alpha-api-blue.service"
  run_init --all --install-systemd --systemd-output "$SYSTEMD_OUTPUT_DIR" --yes
  [[ "$command_status" -ne 0 && -d "$TEST_CASE_DIR/deploy/beta/state" ]] || return 1
  assert_contains "[SKIPPED] alpha-api" && assert_contains "[SUCCESS] beta-web" && \
    assert_contains "Successful: 1" && assert_contains "Skipped: 1" && assert_contains "Failed: 0"
}

test_all_summarizes_failure() {
  setup_case
  export MOCK_FAIL_ANALYZE="yes"
  run_init --all --generate-systemd --systemd-output "$SYSTEMD_OUTPUT_DIR" --yes
  [[ "$command_status" -ne 0 ]] || return 1
  assert_contains "[FAILED] alpha-api" && assert_contains "[SUCCESS] beta-web" && \
    assert_contains "Successful: 1" && assert_contains "Skipped: 0" && assert_contains "Failed: 1"
}

test_yes_skips_confirmation() {
  setup_case
  run_init alpha-api --yes
  [[ "$command_status" -eq 0 ]] && assert_not_contains "Continue?"
}

run_test() {
  local name="$1" function_name="$2"
  command_output=""
  if "$function_name"; then
    pass "$name"
  else
    fail "$name"
  fi
}

run_test "named initialization preserves active color and history" test_named_initialization_and_preservation
run_test "generate-systemd creates both units without installation" test_generate_only
run_test "install-systemd implies generation, enables, and does not start" test_successful_install
run_test "service name and --all are mutually exclusive" test_invalid_cli_combination
run_test "no arguments use interactive service selection" test_interactive_selection
run_test "--all discovers and initializes every service" test_all_discovers_services
run_test "unregistered service fails" test_unregistered_service
run_test "named non-systemd installation is rejected" test_non_systemd_install_rejected
run_test "blue, green, pair, and broken-symlink conflicts are blocked" test_conflicts
run_test "generated unit validation failure prevents installation" test_validation_failure_prevents_install
run_test "second symlink failure rolls back the first" test_link_failure_rolls_back
run_test "daemon reload failure rolls back symlinks" test_reload_failure_rolls_back
run_test "enable failure rolls back enablement and symlinks" test_enable_failure_rolls_back
run_test "--all continues after conflict and reports totals" test_all_continues_and_summarizes_conflict
run_test "--all reports failed totals and exits non-zero" test_all_summarizes_failure
run_test "--yes skips confirmation" test_yes_skips_confirmation

echo
echo "Tests: $passed passed, $failed failed"
[[ "$failed" -eq 0 ]]
