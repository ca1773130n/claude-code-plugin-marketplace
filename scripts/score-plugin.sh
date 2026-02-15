#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Usage ---
usage() {
  cat <<EOF
Usage: $(basename "$0") <plugin-dir> [--json]

Scores a Claude Code plugin across 5 quality categories (0-100).
Each category starts at 20 points; deductions are subtracted per failed check.

Categories:
  1. Manifest Completeness (20 pts)
  2. Documentation (20 pts)
  3. Structure Integrity (20 pts)
  4. Naming Conventions (20 pts)
  5. Version Hygiene (20 pts)

Options:
  --json    Output machine-readable JSON to stdout
  --help    Show this help message

Exit codes:
  0  Scoring completed successfully
  1  Scoring failed (internal error)
  2  Missing dependencies or usage error
EOF
  exit 0
}

# --- Argument parsing ---
PLUGIN_DIR=""
JSON_OUTPUT=false

for arg in "$@"; do
  case "$arg" in
    --help|-h) usage ;;
    --json) JSON_OUTPUT=true ;;
    -*) echo "Error: Unknown option '$arg'" >&2; exit 2 ;;
    *) PLUGIN_DIR="$arg" ;;
  esac
done

if [[ -z "$PLUGIN_DIR" ]]; then
  echo "Error: Plugin directory argument required." >&2
  echo "Usage: $(basename "$0") <plugin-dir> [--json]" >&2
  exit 2
fi

# Resolve to absolute path
if [[ "$PLUGIN_DIR" != /* ]]; then
  PLUGIN_DIR="$(cd "$PLUGIN_DIR" 2>/dev/null && pwd)" || {
    echo "Error: Plugin directory '$1' not found." >&2
    exit 2
  }
fi

# --- Dependency checks ---
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq not found. Install jq (brew install jq) to use this script." >&2
  exit 2
fi

MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"

if [[ ! -f "$MANIFEST" ]]; then
  echo "Error: Plugin manifest not found at $MANIFEST" >&2
  exit 1
fi

plugin_name=$(jq -r '.name // "unknown"' "$MANIFEST" 2>/dev/null)

# =========================================
# Helper: add deduction to a JSON array
# =========================================
add_deduction() {
  local deductions_json="$1"
  local msg="$2"
  echo "$deductions_json" | jq -c --arg d "$msg" '. + [$d]'
}

# =========================================
# Category 1: Manifest Completeness (20 pts)
# 8 rules
# =========================================
score_manifest_completeness() {
  local score=20
  local deductions="[]"

  # Rule 1: Missing description (-4)
  local desc
  desc=$(jq -r '.description // empty' "$MANIFEST")
  if [[ -z "$desc" ]]; then
    score=$((score - 4))
    deductions=$(add_deduction "$deductions" "-4 missing description")
  fi

  # Rule 2: Missing version (-3)
  local ver
  ver=$(jq -r '.version // empty' "$MANIFEST")
  if [[ -z "$ver" ]]; then
    score=$((score - 3))
    deductions=$(add_deduction "$deductions" "-3 missing version")
  fi

  # Rule 3: Missing author (-3)
  local author_type
  author_type=$(jq -r '.author | type' "$MANIFEST" 2>/dev/null)
  if [[ "$author_type" == "null" ]]; then
    score=$((score - 3))
    deductions=$(add_deduction "$deductions" "-3 missing author")
  fi

  # Rule 4: Missing homepage (-2)
  local homepage
  homepage=$(jq -r '.homepage // empty' "$MANIFEST")
  if [[ -z "$homepage" ]]; then
    score=$((score - 2))
    deductions=$(add_deduction "$deductions" "-2 missing homepage")
  fi

  # Rule 5: Missing repository (-2)
  local repo
  repo=$(jq -r '.repository // empty' "$MANIFEST")
  if [[ -z "$repo" ]]; then
    score=$((score - 2))
    deductions=$(add_deduction "$deductions" "-2 missing repository")
  fi

  # Rule 6: Missing license (-2)
  local license
  license=$(jq -r '.license // empty' "$MANIFEST")
  if [[ -z "$license" ]]; then
    score=$((score - 2))
    deductions=$(add_deduction "$deductions" "-2 missing license")
  fi

  # Rule 7: Missing keywords (-2)
  local kw_type
  kw_type=$(jq -r '.keywords | type' "$MANIFEST" 2>/dev/null)
  if [[ "$kw_type" == "null" ]]; then
    score=$((score - 2))
    deductions=$(add_deduction "$deductions" "-2 missing keywords")
  fi

  # Rule 8: Undeclared artifacts (-2)
  # Check if agents/, commands/, or skills/ directories exist but are not declared in manifest
  local undeclared=false
  for artifact_dir in agents commands skills; do
    if [[ -d "$PLUGIN_DIR/$artifact_dir" ]]; then
      local field_type
      field_type=$(jq -r ".$artifact_dir | type" "$MANIFEST" 2>/dev/null)
      if [[ "$field_type" == "null" ]]; then
        undeclared=true
      fi
    fi
    # Also check non-standard dirs like workflows/ that contain command-like files
    if [[ "$artifact_dir" == "commands" && -d "$PLUGIN_DIR/workflows" ]]; then
      local cmd_type
      cmd_type=$(jq -r '.commands | type' "$MANIFEST" 2>/dev/null)
      # If commands are declared (even from workflows/), that's fine
      if [[ "$cmd_type" == "null" ]]; then
        undeclared=true
      fi
    fi
  done
  if [[ "$undeclared" == true ]]; then
    score=$((score - 2))
    deductions=$(add_deduction "$deductions" "-2 undeclared artifact directories")
  fi

  # Floor at 0
  if [[ $score -lt 0 ]]; then score=0; fi

  jq -n -c --argjson s "$score" --argjson d "$deductions" \
    '{score: $s, max: 20, deductions: $d}'
}

# =========================================
# Category 2: Documentation (20 pts)
# 5 rules
# =========================================
score_documentation() {
  local score=20
  local deductions="[]"

  # Rule 9: Missing README (-6)
  local has_readme=false
  for f in "$PLUGIN_DIR"/README.md "$PLUGIN_DIR"/*README*.md; do
    if [[ -f "$f" ]]; then
      has_readme=true
      break
    fi
  done
  if [[ "$has_readme" == false ]]; then
    score=$((score - 6))
    deductions=$(add_deduction "$deductions" "-6 missing README")
  fi

  # Rule 10: Missing CLAUDE.md (-6)
  if [[ ! -f "$PLUGIN_DIR/CLAUDE.md" ]]; then
    score=$((score - 6))
    deductions=$(add_deduction "$deductions" "-6 missing CLAUDE.md")
  fi

  # Rule 11: README too short (-3)
  if [[ "$has_readme" == true ]]; then
    local readme_file=""
    if [[ -f "$PLUGIN_DIR/README.md" ]]; then
      readme_file="$PLUGIN_DIR/README.md"
    else
      for f in "$PLUGIN_DIR"/*README*.md; do
        if [[ -f "$f" ]]; then
          readme_file="$f"
          break
        fi
      done
    fi
    if [[ -n "$readme_file" ]]; then
      local line_count
      line_count=$(wc -l < "$readme_file" | tr -d ' ')
      if [[ "$line_count" -lt 50 ]]; then
        score=$((score - 3))
        deductions=$(add_deduction "$deductions" "-3 README too short (<50 lines)")
      fi
    fi
  fi

  # Rule 12: Description too short (-3)
  local desc
  desc=$(jq -r '.description // ""' "$MANIFEST")
  if [[ -n "$desc" && ${#desc} -lt 20 ]]; then
    score=$((score - 3))
    deductions=$(add_deduction "$deductions" "-3 description too short (<20 chars)")
  fi

  # Rule 13: Missing keywords for discovery (-2)
  local kw_type
  kw_type=$(jq -r '.keywords | type' "$MANIFEST" 2>/dev/null)
  if [[ "$kw_type" == "null" ]]; then
    score=$((score - 2))
    deductions=$(add_deduction "$deductions" "-2 missing keywords for discovery")
  fi

  # Floor at 0
  if [[ $score -lt 0 ]]; then score=0; fi

  jq -n -c --argjson s "$score" --argjson d "$deductions" \
    '{score: $s, max: 20, deductions: $d}'
}

# =========================================
# Category 3: Structure Integrity (20 pts)
# 5 rules
# =========================================
score_structure_integrity() {
  local score=20
  local deductions="[]"

  # Rule 14: Missing .claude-plugin directory (-6)
  if [[ ! -d "$PLUGIN_DIR/.claude-plugin" ]]; then
    score=$((score - 6))
    deductions=$(add_deduction "$deductions" "-6 missing .claude-plugin directory")
  fi

  # Rule 15: Declared file not found (-4 each, max -12)
  local missing_penalty=0
  # Check commands
  local cmd_type
  cmd_type=$(jq -r '.commands | type' "$MANIFEST" 2>/dev/null)
  if [[ "$cmd_type" == "array" ]]; then
    local count
    count=$(jq -r '.commands | length' "$MANIFEST")
    local i=0
    while [[ $i -lt $count ]]; do
      local path_val
      path_val=$(jq -r ".commands[$i]" "$MANIFEST")
      local resolved="${path_val#./}"
      if [[ ! -e "$PLUGIN_DIR/$resolved" ]]; then
        missing_penalty=$((missing_penalty + 4))
      fi
      i=$((i + 1))
    done
  elif [[ "$cmd_type" == "string" ]]; then
    local path_val
    path_val=$(jq -r '.commands' "$MANIFEST")
    local resolved="${path_val#./}"
    if [[ ! -e "$PLUGIN_DIR/$resolved" ]]; then
      missing_penalty=$((missing_penalty + 4))
    fi
  fi
  # Check agents
  local agent_type
  agent_type=$(jq -r '.agents | type' "$MANIFEST" 2>/dev/null)
  if [[ "$agent_type" == "array" ]]; then
    local count
    count=$(jq -r '.agents | length' "$MANIFEST")
    local i=0
    while [[ $i -lt $count ]]; do
      local path_val
      path_val=$(jq -r ".agents[$i]" "$MANIFEST")
      local resolved="${path_val#./}"
      if [[ ! -e "$PLUGIN_DIR/$resolved" ]]; then
        missing_penalty=$((missing_penalty + 4))
      fi
      i=$((i + 1))
    done
  elif [[ "$agent_type" == "string" ]]; then
    local path_val
    path_val=$(jq -r '.agents' "$MANIFEST")
    local resolved="${path_val#./}"
    if [[ ! -e "$PLUGIN_DIR/$resolved" ]]; then
      missing_penalty=$((missing_penalty + 4))
    fi
  fi
  # Check skills
  local skills_type
  skills_type=$(jq -r '.skills | type' "$MANIFEST" 2>/dev/null)
  if [[ "$skills_type" == "array" ]]; then
    local count
    count=$(jq -r '.skills | length' "$MANIFEST")
    local i=0
    while [[ $i -lt $count ]]; do
      local path_val
      path_val=$(jq -r ".skills[$i]" "$MANIFEST")
      local resolved="${path_val#./}"
      if [[ ! -e "$PLUGIN_DIR/$resolved" ]]; then
        missing_penalty=$((missing_penalty + 4))
      fi
      i=$((i + 1))
    done
  elif [[ "$skills_type" == "string" ]]; then
    local path_val
    path_val=$(jq -r '.skills' "$MANIFEST")
    local resolved="${path_val#./}"
    if [[ ! -e "$PLUGIN_DIR/$resolved" ]]; then
      missing_penalty=$((missing_penalty + 4))
    fi
  fi
  # Cap at 12
  if [[ $missing_penalty -gt 12 ]]; then missing_penalty=12; fi
  if [[ $missing_penalty -gt 0 ]]; then
    score=$((score - missing_penalty))
    deductions=$(add_deduction "$deductions" "-$missing_penalty declared file(s) not found")
  fi

  # Rule 16: Undeclared artifact files (-2)
  local has_undeclared=false
  for artifact_dir in agents commands skills; do
    if [[ -d "$PLUGIN_DIR/$artifact_dir" ]]; then
      local field_type
      field_type=$(jq -r ".$artifact_dir | type" "$MANIFEST" 2>/dev/null)
      if [[ "$field_type" == "null" ]]; then
        has_undeclared=true
      fi
    fi
  done
  if [[ "$has_undeclared" == true ]]; then
    score=$((score - 2))
    deductions=$(add_deduction "$deductions" "-2 undeclared artifact files in directories")
  fi

  # Rule 17: Hook script not executable (-3)
  local hooks_type
  hooks_type=$(jq -r '.hooks | type' "$MANIFEST" 2>/dev/null)
  if [[ "$hooks_type" == "object" ]]; then
    local hook_cmds
    hook_cmds=$(jq -r '.. | .command? // empty' "$MANIFEST" 2>/dev/null)
    while IFS= read -r cmd; do
      [[ -z "$cmd" ]] && continue
      if [[ "$cmd" == *'${CLAUDE_PLUGIN_ROOT}'* ]]; then
        local local_path
        local_path=$(echo "$cmd" | sed 's/.*\${CLAUDE_PLUGIN_ROOT}\///' | sed 's/".*//' | sed "s/'.*//")
        if [[ "$local_path" == *.sh && -e "$PLUGIN_DIR/$local_path" && ! -x "$PLUGIN_DIR/$local_path" ]]; then
          score=$((score - 3))
          deductions=$(add_deduction "$deductions" "-3 hook script not executable: $local_path")
          break  # Only deduct once
        fi
      fi
    done <<< "$hook_cmds"
  fi

  # Rule 18: Empty artifact directory (-2)
  local has_empty=false
  for artifact_dir in agents commands skills workflows; do
    if [[ -d "$PLUGIN_DIR/$artifact_dir" ]]; then
      local file_count
      file_count=$(find "$PLUGIN_DIR/$artifact_dir" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
      if [[ "$file_count" -eq 0 ]]; then
        has_empty=true
      fi
    fi
  done
  if [[ "$has_empty" == true ]]; then
    score=$((score - 2))
    deductions=$(add_deduction "$deductions" "-2 empty artifact directory")
  fi

  # Floor at 0
  if [[ $score -lt 0 ]]; then score=0; fi

  jq -n -c --argjson s "$score" --argjson d "$deductions" \
    '{score: $s, max: 20, deductions: $d}'
}

# =========================================
# Category 4: Naming Conventions (20 pts)
# 6 rules
# =========================================
score_naming_conventions() {
  local score=20
  local deductions="[]"

  # Rule 19: Plugin name not lowercase-hyphenated (-4)
  local name
  name=$(jq -r '.name // ""' "$MANIFEST")
  if [[ -n "$name" ]] && ! echo "$name" | grep -qE '^[a-z][a-z0-9-]*$'; then
    score=$((score - 4))
    deductions=$(add_deduction "$deductions" "-4 plugin name not lowercase-hyphenated")
  fi

  # Rule 20: Inconsistent agent naming (-4)
  # Check naming CONSISTENCY not conformity (per Research Pitfall 1)
  if [[ -d "$PLUGIN_DIR/agents" ]]; then
    local agent_files=()
    while IFS= read -r f; do
      agent_files+=("$(basename "$f")")
    done < <(find "$PLUGIN_DIR/agents" -maxdepth 1 -name "*.md" -type f 2>/dev/null)

    if [[ ${#agent_files[@]} -ge 2 ]]; then
      # Check if >50% share a common prefix (first word before - or first 3+ chars)
      local total=${#agent_files[@]}
      local consistent=false

      # Strategy 1: Extract prefix before first hyphen, count most common using sort/uniq
      local max_prefix_count
      max_prefix_count=$(for af in "${agent_files[@]}"; do echo "$af" | sed 's/-.*//'; done | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')

      if [[ $max_prefix_count -gt $((total / 2)) ]]; then
        consistent=true
      fi

      # Strategy 2: Check if all files are single-word (no hyphen before .md)
      if [[ "$consistent" == false ]]; then
        local single_word_count=0
        for af in "${agent_files[@]}"; do
          local name_no_ext="${af%.md}"
          if ! echo "$name_no_ext" | grep -q '-'; then
            single_word_count=$((single_word_count + 1))
          fi
        done
        if [[ $single_word_count -gt $((total / 2)) ]]; then
          consistent=true
        fi
      fi

      if [[ "$consistent" == false ]]; then
        score=$((score - 4))
        deductions=$(add_deduction "$deductions" "-4 inconsistent agent naming")
      fi
    fi
  fi

  # Rule 21: Command dir nonstandard name (-2)
  # If plugin has commands but they're in a directory named other than commands/
  local cmd_type
  cmd_type=$(jq -r '.commands | type' "$MANIFEST" 2>/dev/null)
  if [[ "$cmd_type" == "array" || "$cmd_type" == "string" ]]; then
    # Check if any command path uses a nonstandard directory
    local first_cmd
    if [[ "$cmd_type" == "array" ]]; then
      first_cmd=$(jq -r '.commands[0] // ""' "$MANIFEST")
    else
      first_cmd=$(jq -r '.commands // ""' "$MANIFEST")
    fi
    if [[ -n "$first_cmd" ]]; then
      local cmd_dir
      cmd_dir=$(echo "$first_cmd" | sed 's|^\./||' | cut -d'/' -f1)
      if [[ "$cmd_dir" != "commands" && -n "$cmd_dir" ]]; then
        score=$((score - 2))
        deductions=$(add_deduction "$deductions" "-2 commands in non-standard directory: $cmd_dir/")
      fi
    fi
  fi

  # Rule 22: Agent file extension wrong (-3)
  local agents_type
  agents_type=$(jq -r '.agents | type' "$MANIFEST" 2>/dev/null)
  if [[ "$agents_type" == "array" ]]; then
    local has_wrong_ext=false
    local count
    count=$(jq -r '.agents | length' "$MANIFEST")
    local i=0
    while [[ $i -lt $count ]]; do
      local path_val
      path_val=$(jq -r ".agents[$i]" "$MANIFEST")
      if [[ "$path_val" != *.md ]]; then
        has_wrong_ext=true
      fi
      i=$((i + 1))
    done
    if [[ "$has_wrong_ext" == true ]]; then
      score=$((score - 3))
      deductions=$(add_deduction "$deductions" "-3 agent files not .md")
    fi
  elif [[ "$agents_type" == "string" ]]; then
    local path_val
    path_val=$(jq -r '.agents' "$MANIFEST")
    if [[ "$path_val" != *.md ]]; then
      score=$((score - 3))
      deductions=$(add_deduction "$deductions" "-3 agent file not .md")
    fi
  fi

  # Rule 23: Version string format invalid (-3)
  local ver
  ver=$(jq -r '.version // empty' "$MANIFEST")
  if [[ -n "$ver" ]] && ! echo "$ver" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+'; then
    score=$((score - 3))
    deductions=$(add_deduction "$deductions" "-3 version format invalid (not semver)")
  fi

  # Rule 24: Manifest field naming non-standard (-2)
  # Check for unexpected top-level keys that aren't in the known schema
  local known_fields='["name","version","description","author","homepage","repository","license","keywords","commands","agents","skills","hooks","mcpServers","outputStyles","lspServers"]'
  local unexpected
  unexpected=$(jq -r --argjson known "$known_fields" 'keys - $known | length' "$MANIFEST" 2>/dev/null)
  if [[ "$unexpected" -gt 0 ]]; then
    score=$((score - 2))
    deductions=$(add_deduction "$deductions" "-2 unexpected manifest fields")
  fi

  # Floor at 0
  if [[ $score -lt 0 ]]; then score=0; fi

  jq -n -c --argjson s "$score" --argjson d "$deductions" \
    '{score: $s, max: 20, deductions: $d}'
}

# =========================================
# Category 5: Version Hygiene (20 pts)
# 6 rules
# =========================================
score_version_hygiene() {
  local score=20
  local deductions="[]"

  local ver
  ver=$(jq -r '.version // empty' "$MANIFEST")

  # Rule 25: No version in manifest (-6)
  if [[ -z "$ver" ]]; then
    score=$((score - 6))
    deductions=$(add_deduction "$deductions" "-6 no version in manifest")
  fi

  # Rule 26: Invalid semver format (-4)
  if [[ -n "$ver" ]] && ! echo "$ver" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+'; then
    score=$((score - 4))
    deductions=$(add_deduction "$deductions" "-4 invalid semver format")
  fi

  # Rule 27: Pre-1.0 version (-2)
  if [[ -n "$ver" ]]; then
    local major
    major=$(echo "$ver" | cut -d'.' -f1)
    if [[ "$major" == "0" ]]; then
      score=$((score - 2))
      deductions=$(add_deduction "$deductions" "-2 pre-1.0 version")
    fi
  fi

  # Rule 28: VERSION file mismatch (-3)
  if [[ -f "$PLUGIN_DIR/VERSION" ]]; then
    local file_ver
    file_ver=$(tr -d '[:space:]' < "$PLUGIN_DIR/VERSION")
    if [[ -n "$ver" && "$file_ver" != "$ver" ]]; then
      score=$((score - 3))
      deductions=$(add_deduction "$deductions" "-3 VERSION file mismatch ($file_ver vs $ver)")
    fi
  fi

  # Rule 29: No changelog or version history (-3)
  if [[ ! -f "$PLUGIN_DIR/CHANGELOG.md" ]]; then
    score=$((score - 3))
    deductions=$(add_deduction "$deductions" "-3 no CHANGELOG.md")
  fi

  # Rule 30: Version contains build metadata (-2)
  if [[ -n "$ver" ]] && echo "$ver" | grep -qE '\+'; then
    score=$((score - 2))
    deductions=$(add_deduction "$deductions" "-2 version contains build metadata")
  fi

  # Floor at 0
  if [[ $score -lt 0 ]]; then score=0; fi

  jq -n -c --argjson s "$score" --argjson d "$deductions" \
    '{score: $s, max: 20, deductions: $d}'
}

# =========================================
# Main: Aggregate all category scores
# =========================================
main() {
  local mc_result
  mc_result=$(score_manifest_completeness)
  local doc_result
  doc_result=$(score_documentation)
  local si_result
  si_result=$(score_structure_integrity)
  local nc_result
  nc_result=$(score_naming_conventions)
  local vh_result
  vh_result=$(score_version_hygiene)

  # Extract scores
  local mc_score doc_score si_score nc_score vh_score
  mc_score=$(echo "$mc_result" | jq '.score')
  doc_score=$(echo "$doc_result" | jq '.score')
  si_score=$(echo "$si_result" | jq '.score')
  nc_score=$(echo "$nc_result" | jq '.score')
  vh_score=$(echo "$vh_result" | jq '.score')

  local total=$((mc_score + doc_score + si_score + nc_score + vh_score))

  if [[ "$JSON_OUTPUT" == true ]]; then
    # Machine-readable JSON output
    jq -n \
      --arg plugin "$plugin_name" \
      --argjson total "$total" \
      --argjson mc "$mc_result" \
      --argjson doc "$doc_result" \
      --argjson si "$si_result" \
      --argjson nc "$nc_result" \
      --argjson vh "$vh_result" \
      '{
        plugin: $plugin,
        total: $total,
        categories: {
          manifest_completeness: $mc,
          documentation: $doc,
          structure_integrity: $si,
          naming_conventions: $nc,
          version_hygiene: $vh
        }
      }'
  else
    # Human-readable output
    echo "Quality Score: $plugin_name -- $total/100"
    echo ""

    # Helper to format deduction details
    format_details() {
      local result="$1"
      local deds
      deds=$(echo "$result" | jq -r '.deductions | if length > 0 then join(", ") else "--" end')
      echo "$deds"
    }

    printf "  %-24s %2d/20  %s\n" "Manifest Completeness" "$mc_score" "$(format_details "$mc_result")"
    printf "  %-24s %2d/20  %s\n" "Documentation" "$doc_score" "$(format_details "$doc_result")"
    printf "  %-24s %2d/20  %s\n" "Structure Integrity" "$si_score" "$(format_details "$si_result")"
    printf "  %-24s %2d/20  %s\n" "Naming Conventions" "$nc_score" "$(format_details "$nc_result")"
    printf "  %-24s %2d/20  %s\n" "Version Hygiene" "$vh_score" "$(format_details "$vh_result")"
  fi
}

main
