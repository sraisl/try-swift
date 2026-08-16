#!/usr/bin/env bash
# Black-box acceptance test runner, adapted from tobi/try's spec/tests/runner.sh.
# Usage: AcceptanceTests/runner.sh <path-to-try-binary>
set -uo pipefail

TRY_CMD="${1:?usage: runner.sh <path-to-try-binary>}"
case "$TRY_CMD" in
    /*) ;;
    *) TRY_CMD="$(pwd)/$TRY_CMD" ;;
esac
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export TRY_WIDTH=80
export TRY_HEIGHT=24
unset NO_COLOR NO_COLORS TRY_PROJECTS

TESTS_RUN=0
TESTS_FAILED=0
CURRENT_TEST=""

pass() {
    TESTS_RUN=$((TESTS_RUN + 1))
    echo "  ok - $CURRENT_TEST"
}

fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL - $CURRENT_TEST: $1"
}

try_run() {
    "$TRY_CMD" "$@" 2>&1
}

# For assertions against the generated shell script only (stdout), with TUI
# rendering (stderr) discarded - mirrors what the real shell wrapper sees on
# its stdout capture.
try_script() {
    "$TRY_CMD" "$@" 2>/dev/null
}

setup_fixture() {
    TEST_TRIES="$(mktemp -d)/tries"
    mkdir -p "$TEST_TRIES"
    mkdir -p "$TEST_TRIES/2026-08-15-alpha"
    mkdir -p "$TEST_TRIES/2026-08-14-beta"
    mkdir -p "$TEST_TRIES/2026-08-10-redis-server"
}

teardown_fixture() {
    rm -rf "$(dirname "$TEST_TRIES")"
}

for test_file in "$SCRIPT_DIR"/test_*.sh; do
    [ -e "$test_file" ] || continue
    setup_fixture
    # shellcheck source=/dev/null
    source "$test_file"
    teardown_fixture
done

echo ""
echo "$TESTS_RUN tests run, $TESTS_FAILED failed"
[ "$TESTS_FAILED" -eq 0 ]
