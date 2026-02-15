#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/templates/plugin-template"

# --- Usage ---
usage() {
  cat <<EOF
Usage: $(basename "$0") <plugin-name> [--description "..."] [--author "..."]

Scaffolds a new Claude Code plugin from the template.

Arguments:
  plugin-name         Plugin identifier (lowercase, hyphens allowed, must start with letter)

Options:
  --description "..."   Plugin description (default: "A Claude Code plugin")
  --author "..."        Author name (default: git config user.name or "Your Name")
  --help                Show this help message

Examples:
  $(basename "$0") my-plugin
  $(basename "$0") my-plugin --description "Does useful things" --author "Jane Doe"

Exit codes:
  0  Plugin scaffolded successfully
  1  Scaffold error (collision, template missing)
  2  Usage error (invalid name, missing args)
EOF
  exit 0
}

# --- Input validation ---
validate_plugin_name() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "Error: Plugin name is required." >&2
    echo "Usage: $(basename "$0") <plugin-name> [--description \"...\"] [--author \"...\"]" >&2
    exit 2
  fi

  if ! echo "$name" | grep -qE '^[a-z][a-z0-9-]*$'; then
    echo "Error: Invalid plugin name '$name'." >&2
    echo "  Plugin names must start with a lowercase letter and contain only lowercase letters, digits, and hyphens." >&2
    echo "  Pattern: ^[a-z][a-z0-9-]*$" >&2
    exit 2
  fi

  local name_len
  name_len=$(printf '%s' "$name" | wc -c | tr -d ' ')
  if [ "$name_len" -gt 64 ]; then
    echo "Error: Plugin name '$name' is too long ($name_len characters, maximum 64)." >&2
    exit 2
  fi

  if [ -d "$REPO_ROOT/plugins/$name" ]; then
    echo "Error: Plugin '$name' already exists at plugins/$name/" >&2
    exit 1
  fi
}

# --- Argument parsing ---
PLUGIN_NAME=""
DESCRIPTION="A Claude Code plugin"
AUTHOR=""

if [ $# -eq 0 ]; then
  echo "Error: No arguments provided." >&2
  echo "Usage: $(basename "$0") <plugin-name> [--description \"...\"] [--author \"...\"]" >&2
  exit 2
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h)
      usage
      ;;
    --description)
      if [ $# -lt 2 ]; then
        echo "Error: --description requires a value." >&2
        exit 2
      fi
      DESCRIPTION="$2"
      shift 2
      ;;
    --author)
      if [ $# -lt 2 ]; then
        echo "Error: --author requires a value." >&2
        exit 2
      fi
      AUTHOR="$2"
      shift 2
      ;;
    -*)
      echo "Error: Unknown option '$1'" >&2
      exit 2
      ;;
    *)
      if [ -z "$PLUGIN_NAME" ]; then
        PLUGIN_NAME="$1"
      else
        echo "Error: Unexpected argument '$1'" >&2
        exit 2
      fi
      shift
      ;;
  esac
done

# Resolve author default
if [ -z "$AUTHOR" ]; then
  AUTHOR=$(git config user.name 2>/dev/null || echo "Your Name")
fi

# Validate plugin name
validate_plugin_name "$PLUGIN_NAME"

# Verify template directory exists
if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "Error: Template directory not found at $TEMPLATE_DIR" >&2
  echo "  Run from the repository root or ensure the template has been created." >&2
  exit 1
fi

# --- Directory creation ---
DEST="$REPO_ROOT/plugins/$PLUGIN_NAME"

echo "Scaffolding plugin '$PLUGIN_NAME'..."

mkdir -p "$DEST/.claude-plugin"
mkdir -p "$DEST/agents"
mkdir -p "$DEST/commands"

# --- JSON generation via jq ---
jq -n \
  --arg name "$PLUGIN_NAME" \
  --arg desc "$DESCRIPTION" \
  --arg author "$AUTHOR" \
  '{
    name: $name,
    version: "1.0.0",
    description: $desc,
    author: { name: $author },
    homepage: ("https://github.com/YOUR-USERNAME/" + $name),
    repository: ("https://github.com/YOUR-USERNAME/" + $name),
    license: "MIT",
    keywords: ["claude-code", "plugin"],
    commands: ["./commands/example.md"],
    agents: [("./agents/" + $name + "-example-agent.md")]
  }' > "$DEST/.claude-plugin/plugin.json"

# --- Text file substitution (sed without -i, BSD-portable) ---

# README.md
sed -e "s/{{PLUGIN_NAME}}/$PLUGIN_NAME/g" \
    -e "s/{{PLUGIN_DESCRIPTION}}/$DESCRIPTION/g" \
    "$TEMPLATE_DIR/README.md" > "$DEST/README.md"

# CLAUDE.md
sed -e "s/{{PLUGIN_NAME}}/$PLUGIN_NAME/g" \
    -e "s/{{PLUGIN_DESCRIPTION}}/$DESCRIPTION/g" \
    "$TEMPLATE_DIR/CLAUDE.md" > "$DEST/CLAUDE.md"

# CHANGELOG.md
sed -e "s/{{PLUGIN_NAME}}/$PLUGIN_NAME/g" \
    -e "s/{{PLUGIN_DESCRIPTION}}/$DESCRIPTION/g" \
    "$TEMPLATE_DIR/CHANGELOG.md" > "$DEST/CHANGELOG.md"

# Agent file: rename with plugin-name prefix
sed -e "s/example-plugin/$PLUGIN_NAME/g" \
    -e "s/{{PLUGIN_NAME}}/$PLUGIN_NAME/g" \
    "$TEMPLATE_DIR/agents/example-plugin-example-agent.md" > "$DEST/agents/${PLUGIN_NAME}-example-agent.md"

# --- Static files (copy without substitution) ---
cp "$TEMPLATE_DIR/commands/example.md" "$DEST/commands/example.md"
cp "$TEMPLATE_DIR/VERSION" "$DEST/VERSION"

# --- Post-scaffold validation ---
echo ""
echo "Validating scaffold..."
if "$SCRIPT_DIR/validate-plugin.sh" "$DEST"; then
  echo ""
  echo "Plugin '$PLUGIN_NAME' scaffolded successfully at plugins/$PLUGIN_NAME/"
else
  echo "FAIL: Scaffold has validation errors -- this is a bug, please report it." >&2
  exit 1
fi

# --- Final output ---
echo ""
echo "Next steps:"
echo "  1. Edit plugins/$PLUGIN_NAME/.claude-plugin/plugin.json with your details"
echo "  2. Add your commands in plugins/$PLUGIN_NAME/commands/"
echo "  3. Add your agents in plugins/$PLUGIN_NAME/agents/"
echo "  4. Run: ./scripts/validate-local.sh plugins/$PLUGIN_NAME"
echo "  5. Submit a PR using the plugin submission template"
