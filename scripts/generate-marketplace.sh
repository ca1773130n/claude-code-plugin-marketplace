#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MARKETPLACE_FILE="$REPO_ROOT/.claude-plugin/marketplace.json"
MARKETPLACE_SCHEMA="$REPO_ROOT/schemas/marketplace.schema.json"

# --- Usage ---
usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Generates .claude-plugin/marketplace.json from all plugin.json files found
under plugins/. Dynamically discovers plugins, extracts metadata, computes
enrichment fields (commands, agents, hooks counts), and validates the result
against the marketplace schema.

Options:
  --help    Show this help message

Exit codes:
  0  marketplace.json generated and validated successfully
  1  Generation or validation failed
  2  Missing dependencies or no plugins found
EOF
  exit 0
}

# --- Argument parsing ---
for arg in "$@"; do
  case "$arg" in
    --help|-h) usage ;;
    -*) echo "Error: Unknown option '$arg'" >&2; exit 2 ;;
  esac
done

# --- Dependency checks ---
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq not found. Install jq (brew install jq) to use this script." >&2
  exit 2
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "Error: npx not found. Install Node.js to use this script." >&2
  exit 2
fi

if [[ ! -f "$MARKETPLACE_SCHEMA" ]]; then
  echo "Error: Marketplace schema not found at $MARKETPLACE_SCHEMA" >&2
  exit 2
fi

# --- Discover all plugin.json files ---
plugin_files=()
while IFS= read -r f; do
  plugin_files+=("$f")
done < <(find "$REPO_ROOT/plugins" -path '*/.claude-plugin/plugin.json' -type f | sort)

if [[ ${#plugin_files[@]} -eq 0 ]]; then
  echo "Error: No plugin.json files found under plugins/. Nothing to generate." >&2
  exit 1
fi

# --- Build plugin entries ---
plugins_json="[]"

for pf in "${plugin_files[@]}"; do
  # plugin.json is at plugins/<name>/.claude-plugin/plugin.json
  # plugin_dir is plugins/<name>
  plugin_dir="$(dirname "$(dirname "$pf")")"

  # Compute relative source path without realpath --relative-to (macOS compat)
  local_source="./${plugin_dir#"$REPO_ROOT/"}"

  # Check for upstream remote URL (.upstream file contains git URL)
  upstream_file="$plugin_dir/.upstream"
  metadata_file="$pf"  # default: local plugin.json

  if [[ -f "$upstream_file" ]]; then
    upstream_url="$(head -1 "$upstream_file" | tr -d '[:space:]')"
    # Remote source: {"source": "url", "url": "https://..."}
    source_json=$(jq -n --arg url "$upstream_url" '{"source": "url", "url": $url}')
    # Homepage: strip .git suffix
    homepage="${upstream_url%.git}"
    echo "  $local_source -> remote: $upstream_url"

    # Fetch latest plugin.json from upstream repo for metadata (version, description, etc.)
    # Uses gh API for authentication (works with private repos)
    repo_path=""
    case "$upstream_url" in
      https://github.com/*)
        repo_path="${upstream_url#https://github.com/}"
        repo_path="${repo_path%.git}"
        ;;
    esac

    if [[ -n "$repo_path" ]] && command -v gh >/dev/null 2>&1; then
      upstream_metadata=$(gh api "repos/${repo_path}/contents/.claude-plugin/plugin.json" --jq '.content' 2>/dev/null | base64 -d 2>/dev/null || true)
      if [[ -n "$upstream_metadata" ]] && echo "$upstream_metadata" | jq -e '.name' >/dev/null 2>&1; then
        tmp_metadata=$(mktemp)
        echo "$upstream_metadata" > "$tmp_metadata"
        metadata_file="$tmp_metadata"
        upstream_version=$(echo "$upstream_metadata" | jq -r '.version // "unknown"')
        echo "    fetched upstream metadata (v${upstream_version})"
      else
        echo "    WARNING: could not fetch upstream plugin.json, using local copy" >&2
      fi
    fi
  elif [[ -f "$plugin_dir/.git" ]] && [[ -f "$REPO_ROOT/.gitmodules" ]]; then
    # Git submodule: extract URL from .gitmodules
    submodule_path="${plugin_dir#"$REPO_ROOT/"}"
    submodule_url=$(git -C "$REPO_ROOT" config -f .gitmodules --get "submodule.${submodule_path}.url" 2>/dev/null || true)
    if [[ -n "$submodule_url" ]]; then
      source_json=$(jq -n --arg url "$submodule_url" '{"source": "url", "url": $url}')
      homepage="${submodule_url%.git}"
      echo "  $local_source -> submodule: $submodule_url"
    else
      source_json=$(jq -n --arg s "$local_source" '$s')
      homepage=""
      echo "  $local_source: local (submodule URL not found)"
    fi
  else
    # Local source: relative path string
    source_json=$(jq -n --arg s "$local_source" '$s')
    homepage=""
    echo "  $local_source: local"
  fi

  # Determine category (default: development)
  category="development"

  # Compute quality score for display (always uses local copy)
  quality_score=0
  if [[ -x "$SCRIPT_DIR/score-plugin.sh" ]]; then
    quality_score=$("$SCRIPT_DIR/score-plugin.sh" "$plugin_dir" --json 2>/dev/null | jq '.total // 0')
    echo "    quality score $quality_score/100"
  fi

  # Extract plugin fields -- only Claude Code compatible fields
  # Normalize author: string -> {"name": string}, object -> pass through
  entry=$(jq \
    --argjson source "$source_json" \
    --arg category "$category" \
    --arg homepage "$homepage" \
    '{
      name: .name,
      description: (.description // null),
      version: (.version // null),
      author: (if (.author | type) == "string" then {name: .author} elif .author != null then .author else null end),
      source: $source,
      category: $category,
      homepage: (if $homepage != "" then $homepage else null end)
    } | with_entries(select(.value != null))' "$metadata_file")

  # Clean up temp file if created
  [[ "${tmp_metadata:-}" != "" ]] && rm -f "$tmp_metadata"

  plugins_json=$(echo "$plugins_json" | jq --argjson entry "$entry" '. + [$entry]')
done

# --- Assemble marketplace.json ---
jq -n \
  --arg schema "https://anthropic.com/claude-code/marketplace.schema.json" \
  --arg name "claude-plugin-marketplace" \
  --argjson plugins "$plugins_json" \
  '{
    "$schema": $schema,
    name: $name,
    version: "1.0.0",
    description: "Plugin marketplace for Claude Code",
    owner: { name: "edward-seo" },
    plugins: $plugins
  }' > "$MARKETPLACE_FILE"

echo "Generated $MARKETPLACE_FILE with ${#plugin_files[@]} plugins"

# --- Self-validate against schema ---
echo "Validating against $MARKETPLACE_SCHEMA ..."
npx ajv validate \
  -s "$MARKETPLACE_SCHEMA" \
  -d "$MARKETPLACE_FILE" \
  --spec=draft7 \
  --all-errors \
  --errors=text

echo "marketplace.json is valid."
