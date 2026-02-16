#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MARKETPLACE_FILE="$REPO_ROOT/.claude-plugin/marketplace.json"

# --- Usage ---
usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Syncs all git submodule plugins to their latest origin/main, resolves the
higher of plugin.json vs git tag version, updates the marketplace catalog,
commits, and pushes.

Steps performed:
  1. Ensure .gitmodules tracks branch = main for each submodule
  2. Fetch and checkout origin/main for each submodule in plugins/
  3. Resolve version: higher of plugin.json vs git tag on origin/main
  4. Update .claude-plugin/marketplace.json with synced versions
  5. Stage .gitmodules, submodule refs, and marketplace.json
  6. Commit and push to origin

Options:
  --dry-run   Show what would change without modifying anything
  --help      Show this help message

Exit codes:
  0  All submodules synced and marketplace updated
  1  Sync or update failed
  2  Missing dependencies or invalid arguments
EOF
  exit 0
}

# --- Argument parsing ---
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --help|-h) usage ;;
    --dry-run) DRY_RUN=true ;;
    -*) echo "Error: Unknown option '$arg'" >&2; exit 2 ;;
  esac
done

# --- Dependency checks ---
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq not found. Install jq (brew install jq)." >&2
  exit 2
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git not found." >&2
  exit 2
fi

if [[ ! -f "$MARKETPLACE_FILE" ]]; then
  echo "Error: Marketplace manifest not found at $MARKETPLACE_FILE" >&2
  exit 2
fi

# --- Semver comparison (bash 3.x compatible) ---
# Returns 0 if $1 > $2, 1 otherwise
semver_gt() {
  local IFS=.
  local a=($1) b=($2)
  local i
  for i in 0 1 2; do
    local av="${a[$i]:-0}" bv="${b[$i]:-0}"
    if [[ "$av" -gt "$bv" ]]; then return 0; fi
    if [[ "$av" -lt "$bv" ]]; then return 1; fi
  done
  return 1  # equal
}

# --- Discover submodules under plugins/ ---
submodules=()
while IFS= read -r path; do
  submodules+=("$path")
done < <(git -C "$REPO_ROOT" config -f .gitmodules --get-regexp '^submodule\.plugins/.*\.path$' | awk '{print $2}')

if [[ ${#submodules[@]} -eq 0 ]]; then
  echo "No git submodules found under plugins/. Nothing to deploy."
  exit 0
fi

echo "Found ${#submodules[@]} plugin submodule(s): ${submodules[*]}"
echo ""

# --- Track changes ---
updated_plugins=()

for sub_path in "${submodules[@]}"; do
  sub_dir="$REPO_ROOT/$sub_path"
  sub_name="$(basename "$sub_path")"

  echo "=== $sub_name ($sub_path) ==="

  if [[ ! -d "$sub_dir/.git" ]] && [[ ! -f "$sub_dir/.git" ]]; then
    echo "  Initializing submodule..."
    if [[ "$DRY_RUN" == false ]]; then
      git -C "$REPO_ROOT" submodule update --init "$sub_path"
    else
      echo "  [dry-run] would initialize submodule"
    fi
  fi

  # Step 1: Ensure .gitmodules tracks branch = main
  current_branch=$(git -C "$REPO_ROOT" config -f .gitmodules --get "submodule.${sub_path}.branch" 2>/dev/null || true)
  if [[ "$current_branch" != "main" ]]; then
    echo "  Setting .gitmodules branch = main (was: ${current_branch:-unset})"
    if [[ "$DRY_RUN" == false ]]; then
      git -C "$REPO_ROOT" config -f .gitmodules "submodule.${sub_path}.branch" main
    fi
  fi

  # Step 2: Fetch origin/main and tags (always, even in dry-run)
  old_hash=$(git -C "$sub_dir" rev-parse HEAD 2>/dev/null || echo "none")
  echo "  Current:  ${old_hash:0:12}"

  echo "  Fetching origin..."
  git -C "$sub_dir" fetch origin --tags --force --quiet

  remote_hash=$(git -C "$sub_dir" rev-parse origin/main 2>/dev/null || echo "none")
  echo "  Remote:   ${remote_hash:0:12}"

  if [[ "$DRY_RUN" == false ]]; then
    git -C "$sub_dir" checkout origin/main --quiet
    new_hash=$(git -C "$sub_dir" rev-parse HEAD 2>/dev/null || echo "none")
  else
    new_hash="$remote_hash"
  fi

  if [[ "$old_hash" != "$new_hash" ]]; then
    echo "  Will update: ${old_hash:0:12} -> ${new_hash:0:12}"
  else
    echo "  Already at latest"
  fi

  # Step 3: Resolve version — higher of plugin.json vs git tag on origin/main
  plugin_json_content=$(git -C "$sub_dir" show origin/main:.claude-plugin/plugin.json 2>/dev/null || true)
  head_tag=$(git -C "$sub_dir" tag --points-at origin/main --sort=-v:refname 2>/dev/null | head -1 || true)

  json_version="0.0.0"
  if [[ -n "$plugin_json_content" ]]; then
    json_version=$(echo "$plugin_json_content" | jq -r '.version // "0.0.0"')
  fi

  tag_ver="0.0.0"
  if [[ -n "$head_tag" ]]; then
    tag_ver="${head_tag#v}"
  fi

  if [[ "$json_version" == "$tag_ver" ]]; then
    tag_version="$json_version"
    echo "  Version:  $tag_version (plugin.json + tag agree)"
  elif semver_gt "$tag_ver" "$json_version"; then
    tag_version="$tag_ver"
    echo "  Version:  $tag_version (from tag $head_tag > plugin.json $json_version)"
  else
    tag_version="$json_version"
    if [[ "$tag_ver" == "0.0.0" ]]; then
      echo "  Version:  $tag_version (from plugin.json, no tag)"
    else
      echo "  Version:  $tag_version (from plugin.json > tag $head_tag)"
    fi
  fi

  # Step 4: Update marketplace.json with new version
  if [[ -n "$plugin_json_content" ]]; then
    catalog_name=$(echo "$plugin_json_content" | jq -r '.name')
  else
    catalog_name="$sub_name"
  fi

  # Check if plugin exists in marketplace
  existing_idx=$(jq --arg name "$catalog_name" '[.plugins[] | .name] | index($name) // -1' "$MARKETPLACE_FILE")

  if [[ "$existing_idx" -ge 0 ]]; then
    old_version=$(jq -r --arg name "$catalog_name" '.plugins[] | select(.name == $name) | .version // "unknown"' "$MARKETPLACE_FILE")
    if [[ "$old_version" != "$tag_version" ]]; then
      echo "  Catalog: $catalog_name $old_version -> $tag_version"
      if [[ "$DRY_RUN" == false ]]; then
        tmp=$(mktemp)
        jq --arg name "$catalog_name" --arg ver "$tag_version" \
          '(.plugins[] | select(.name == $name)).version = $ver' "$MARKETPLACE_FILE" > "$tmp"
        mv "$tmp" "$MARKETPLACE_FILE"
      fi
      updated_plugins+=("$catalog_name:$tag_version")
    else
      echo "  Catalog: $catalog_name already at $tag_version"
    fi
  else
    echo "  Catalog: $catalog_name not found in marketplace.json (skipping version sync)"
    echo "           Run generate-marketplace.sh to add it"
  fi

  echo ""
done

# --- Step 5: Stage changes ---
if [[ "$DRY_RUN" == false ]]; then
  echo "=== Staging changes ==="
  git -C "$REPO_ROOT" add .gitmodules
  for sub_path in "${submodules[@]}"; do
    git -C "$REPO_ROOT" add "$sub_path"
  done
  git -C "$REPO_ROOT" add .claude-plugin/marketplace.json
  echo "Staged: .gitmodules, submodule refs, marketplace.json"

  # Build commit message with version summary
  commit_msg="chore: deploy — sync plugin submodules to latest"
  if [[ ${#updated_plugins[@]} -gt 0 ]]; then
    commit_msg="$commit_msg"$'\n\n'"Updated versions:"
    for entry in "${updated_plugins[@]}"; do
      commit_msg="$commit_msg"$'\n'"  ${entry%%:*} -> ${entry#*:}"
    done
  fi

  echo ""
  echo "=== Committing ==="
  if git -C "$REPO_ROOT" diff --cached --quiet; then
    echo "Nothing to commit — already up to date."
  else
    git -C "$REPO_ROOT" commit -m "$commit_msg"
    echo ""
    echo "=== Pushing to origin ==="
    git -C "$REPO_ROOT" push
  fi
else
  echo "=== Dry run complete ==="
  echo "No changes were made."
fi

# --- Summary ---
if [[ ${#updated_plugins[@]} -gt 0 ]]; then
  echo ""
  echo "Updated versions:"
  for entry in "${updated_plugins[@]}"; do
    echo "  ${entry%%:*} -> ${entry#*:}"
  done
fi
