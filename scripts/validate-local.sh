#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Usage ---
usage() {
  cat <<EOF
Usage: $(basename "$0") <plugin-dir>

Runs validation and quality scoring on a Claude Code plugin directory.
This is a convenience wrapper around validate-plugin.sh and score-plugin.sh.

Steps:
  1. Validates plugin structure and manifest (validate-plugin.sh)
  2. Scores plugin quality across 5 categories (score-plugin.sh)

Exit codes:
  0  Validation passed (scoring is informational)
  1  Validation failed
  2  Usage error or missing directory
EOF
  exit 0
}

# --- Argument parsing ---
if [[ $# -eq 0 ]]; then
  echo "Error: Missing required argument <plugin-dir>" >&2
  echo "Run '$(basename "$0") --help' for usage information." >&2
  exit 2
fi

PLUGIN_DIR=""

for arg in "$@"; do
  case "$arg" in
    --help|-h) usage ;;
    -*) echo "Error: Unknown option '$arg'" >&2; exit 2 ;;
    *) PLUGIN_DIR="$arg" ;;
  esac
done

if [[ -z "$PLUGIN_DIR" ]]; then
  usage
fi

# Resolve relative paths to absolute
if [[ "$PLUGIN_DIR" != /* ]]; then
  PLUGIN_DIR="$(cd "$PLUGIN_DIR" 2>/dev/null && pwd)" || {
    echo "Error: Plugin directory '$1' not found." >&2
    exit 2
  }
fi

# Check that the directory exists
if [[ ! -d "$PLUGIN_DIR" ]]; then
  echo "Error: Directory not found: $PLUGIN_DIR" >&2
  exit 2
fi

# --- Step 1: Validation ---
echo "=== Validation ==="
if ! "$SCRIPT_DIR/validate-plugin.sh" "$PLUGIN_DIR"; then
  echo ""
  echo "VALIDATION FAILED"
  exit 1
fi

# --- Step 2: Quality Scoring (informational) ---
echo ""
echo "=== Quality Score ==="
"$SCRIPT_DIR/score-plugin.sh" "$PLUGIN_DIR" || true

echo ""
echo "Local validation complete."
