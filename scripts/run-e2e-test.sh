#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Variable initialization ---
TEMP_PLUGIN_NAME=""

# --- Cleanup (guaranteed via EXIT trap) ---
cleanup() {
  if [[ -n "$TEMP_PLUGIN_NAME" && -d "$REPO_ROOT/plugins/$TEMP_PLUGIN_NAME" ]]; then
    rm -rf "$REPO_ROOT/plugins/$TEMP_PLUGIN_NAME"
  fi
  git -C "$REPO_ROOT" checkout -- .claude-plugin/marketplace.json 2>/dev/null || true
}
trap cleanup EXIT

# --- Usage ---
usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Runs end-to-end integration test of the full plugin pipeline:
  scaffold -> validate -> score -> generate marketplace -> verify -> cleanup

Options:
  --help    Show this help message

Exit codes:
  0  All E2E tests passed
  1  Test failure
  2  Usage error or missing dependencies
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

# =========================================
# Step 1: Scaffold a disposable plugin
# =========================================
TEMP_PLUGIN_NAME="e2e-test-$(date +%s)"
echo "=== E2E Test: Step 1 - Scaffolding plugin '$TEMP_PLUGIN_NAME' ==="
"$SCRIPT_DIR/new-plugin.sh" "$TEMP_PLUGIN_NAME" --description "E2E integration test plugin"
echo "  OK: Plugin scaffolded at plugins/$TEMP_PLUGIN_NAME"

# =========================================
# Step 2: Validate the scaffolded plugin
# =========================================
echo ""
echo "=== E2E Test: Step 2 - Validating plugin ==="
"$SCRIPT_DIR/validate-plugin.sh" "$REPO_ROOT/plugins/$TEMP_PLUGIN_NAME"
echo "  OK: Validation passed"

# =========================================
# Step 3: Score the scaffolded plugin (must be >= 80)
# =========================================
echo ""
echo "=== E2E Test: Step 3 - Scoring plugin ==="
SCORE_JSON=$("$SCRIPT_DIR/score-plugin.sh" "$REPO_ROOT/plugins/$TEMP_PLUGIN_NAME" --json)
TOTAL=$(echo "$SCORE_JSON" | jq '.total')
echo "  Score: $TOTAL/100"
if [[ "$TOTAL" -lt 80 ]]; then
  echo "  FAIL: Scaffolded plugin scored $TOTAL (expected >= 80)" >&2
  exit 1
fi
echo "  OK: Score meets threshold (>= 80)"

# =========================================
# Step 4: Generate marketplace.json
# =========================================
echo ""
echo "=== E2E Test: Step 4 - Generating marketplace.json ==="
"$SCRIPT_DIR/generate-marketplace.sh"
echo "  OK: marketplace.json generated"

# =========================================
# Step 5: Verify plugin appears in marketplace.json
# =========================================
echo ""
echo "=== E2E Test: Step 5 - Verifying marketplace entry ==="
if ! jq -e ".plugins[] | select(.name == \"$TEMP_PLUGIN_NAME\")" \
    "$REPO_ROOT/.claude-plugin/marketplace.json" >/dev/null 2>&1; then
  echo "  FAIL: '$TEMP_PLUGIN_NAME' not found in marketplace.json" >&2
  exit 1
fi
echo "  OK: Plugin found in marketplace.json"

# =========================================
# Success
# =========================================
echo ""
echo "=== E2E Test: ALL PASSED ==="
echo "  Pipeline: scaffold -> validate -> score -> generate -> verify"
echo "  Plugin: $TEMP_PLUGIN_NAME (score: $TOTAL/100)"
echo "  Cleanup: automatic via EXIT trap"
