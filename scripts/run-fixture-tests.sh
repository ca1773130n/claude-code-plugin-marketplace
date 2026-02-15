#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATE="$SCRIPT_DIR/validate-plugin.sh"

# --- Usage ---
usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Runs the fixture test suite, validating all test fixtures under tests/fixtures/
and both real plugins. Expects specific exit codes from validate-plugin.sh.

Test coverage:
  - 4 valid fixtures (expect exit 0)
  - 4 invalid fixtures (expect exit 1)
  - 1 extra-fields fixture (expect exit 0 by design)
  - Real plugins with plugin.json (expect exit 0, dynamically discovered)

Options:
  --help    Show this help message

Exit codes:
  0  All tests passed
  1  One or more tests failed
  2  Usage error
EOF
  exit 0
}

# --- Argument parsing ---
for arg in "$@"; do
  case "$arg" in
    --help|-h) usage ;;
    *) echo "Error: Unknown argument '$arg'. This script takes no arguments." >&2
       echo "Run '$(basename "$0") --help' for usage information." >&2
       exit 2 ;;
  esac
done

passed=0
failed=0
errors=()

# Helper function that runs validation and checks expected exit code
run_test() {
  local fixture_path="$1"
  local expected_exit="$2"
  local test_name="$3"

  local actual_exit=0
  local output
  output=$("$VALIDATE" "$REPO_ROOT/$fixture_path" 2>&1) || actual_exit=$?

  if [[ "$actual_exit" -eq "$expected_exit" ]]; then
    echo "  PASS: $test_name (exit $actual_exit as expected)"
    passed=$((passed + 1))
  else
    echo "  FAIL: $test_name (expected exit $expected_exit, got $actual_exit)"
    echo "        Output: $output"
    errors+=("$test_name: expected exit $expected_exit, got $actual_exit")
    failed=$((failed + 1))
  fi
}

echo "Running fixture tests..."
echo ""

echo "Valid fixtures (expect exit 0):"
run_test "tests/fixtures/valid-minimal" 0 "valid-minimal"
run_test "tests/fixtures/valid-commands-only" 0 "valid-commands-only"
run_test "tests/fixtures/valid-hooks-only" 0 "valid-hooks-only"
run_test "tests/fixtures/valid-full" 0 "valid-full"

echo ""
echo "Invalid fixtures (expect exit 1):"
run_test "tests/fixtures/invalid-no-name" 1 "invalid-no-name"
run_test "tests/fixtures/invalid-bad-version" 1 "invalid-bad-version"
run_test "tests/fixtures/invalid-bad-paths" 1 "invalid-bad-paths"
run_test "tests/fixtures/invalid-missing-files" 1 "invalid-missing-files"

echo ""
echo "Extra fields fixture (expect exit 0 — additionalProperties allowed by design):"
# Design decision: top-level additionalProperties is intentionally not restricted
# to allow forward compatibility with new Claude Code fields.
run_test "tests/fixtures/invalid-extra-fields" 0 "extra-fields (pass by design)"

echo ""
echo "Real plugins (expect exit 0, skipped if no plugin.json):"
for plugin_dir in "$REPO_ROOT"/plugins/*/; do
  plugin_name="$(basename "$plugin_dir")"
  if [[ -f "$plugin_dir/.claude-plugin/plugin.json" ]]; then
    run_test "plugins/$plugin_name" 0 "real: $plugin_name"
  else
    echo "  SKIP: $plugin_name (no .claude-plugin/plugin.json)"
  fi
done

echo ""
echo "Results: $passed passed, $failed failed out of $((passed + failed)) tests"
if [[ $failed -gt 0 ]]; then
  echo "Failures:"
  for err in "${errors[@]}"; do
    echo "  - $err"
  done
  exit 1
fi
echo "All tests passed."
exit 0
