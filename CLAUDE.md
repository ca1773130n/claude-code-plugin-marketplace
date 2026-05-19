# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A Claude Code plugin marketplace — hosts plugins under `plugins/` (as git submodules) and provides infrastructure for validation, quality scoring, and automated publishing via CI. The marketplace manifest at `.claude-plugin/marketplace.json` is auto-generated; never edit it by hand.

## Plugins

Two plugins are registered:
- **grd** (GetResearchDone) — R&D workflow automation, git submodule
- **HarnessSync** — Multi-backend config sync (Claude Code → Codex/Gemini/OpenCode), git submodule

## Commands

```bash
# Install dependencies (required before any script)
npm ci

# Validate a single plugin
./scripts/validate-plugin.sh plugins/foobar

# Score a plugin (human-readable)
./scripts/score-plugin.sh plugins/foobar

# Score a plugin (JSON)
./scripts/score-plugin.sh plugins/foobar --json

# Run all fixture tests (validates real plugins + 9 test fixtures)
./scripts/run-fixture-tests.sh

# Regenerate marketplace.json from all plugins
./scripts/generate-marketplace.sh

# Scaffold a new plugin
./scripts/new-plugin.sh my-plugin

# Deploy: sync submodule plugins to latest origin/main + update versions
./scripts/deploy.sh
./scripts/deploy.sh --dry-run
```

## Architecture

**Toolchain:** Bash + jq + ajv-cli (JSON Schema Draft-07). No build step. All scripts are standalone bash.

**Validation pipeline (two layers):**
1. `validate-plugin.sh` Layer 1: Schema validation via ajv-cli against `schemas/plugin.schema.json`
2. `validate-plugin.sh` Layer 2: Structural checks (file existence, hook permissions, directory structure)

**Quality scoring** (`score-plugin.sh`): 5 categories x 20 pts each = 100 total. Subtractive model (start at 20, deduct per failed rule). 28 rules across: Manifest Completeness, Documentation, Structure Integrity, Naming Conventions, Version Hygiene. See `docs/QUALITY.md` for the full rubric.

**Deploy workflow** (`deploy.sh`): Fetches origin/main for all plugin submodules, resolves version as the higher of plugin.json vs git tag on origin/main HEAD, updates marketplace.json, ensures .gitmodules tracks `branch = main`, commits, and pushes.

**CI workflows:**
- `validate-plugins.yml` — PR trigger. Detects changed plugins via `dorny/paths-filter`, runs validation + scoring per plugin, posts quality score as PR comment.
- `publish-marketplace.yml` — Push-to-main trigger. Regenerates `marketplace.json` and auto-commits.
- `self-test.yml` — Tests validation/scoring scripts against fixtures. Does not checkout submodules (private repos).

**marketplace.json format:** Auto-generated. Plugin entries use `source` as either a relative path (local plugins) or `{"source": "url", "url": "..."}` object (submodule plugins). See `schemas/marketplace.schema.json` for the full spec.

## Key Constraints

- **macOS bash 3.x compatibility** — No associative arrays (`declare -A`), no GNU-specific sed/find flags. Use `jq` for all JSON manipulation.
- **Plugin schema allows additionalProperties** — Top-level `plugin.json` intentionally allows unknown fields for forward compatibility with new Claude Code features.
- **Scoring is informational, not a merge gate** — The scoring step uses `if: always()` and does not block validation.
- **Submodule plugins are private repos** — CI workflows use `submodules: false` since GitHub Actions default token cannot access private submodule repos.
- **Version resolution** — Deploy uses the higher of `plugin.json` version vs git tag on origin/main HEAD. If tag > plugin.json, the script auto-fixes the submodule upstream (bumps plugin.json, deletes wrong tag, commits, pushes, re-tags).

## Project Structure

```
.
├── plugins/           # Plugin directories (submodules + local)
├── schemas/           # JSON Schema for plugin + marketplace manifests
├── scripts/           # Validation, scoring, deploy, scaffolding scripts
├── templates/         # Plugin scaffold template
├── tests/fixtures/    # 9 test fixtures (4 valid, 5 invalid)
├── docs/              # CONTRIBUTING.md, QUALITY.md
├── .github/workflows/ # CI/CD workflows
├── .claude-plugin/    # Auto-generated marketplace manifest
└── .planning/         # Planning docs (v0.0.x pre-release history)
```

## Test Fixtures

Located at `tests/fixtures/`. 4 valid + 5 invalid fixtures covering: minimal manifest, full manifest, commands-only, hooks-only, missing name, bad version, bad paths, missing files, extra fields.

# context-mode — MANDATORY routing rules

You have context-mode MCP tools available. These rules are NOT optional — they protect your context window from flooding. A single unrouted command can dump 56 KB into context and waste the entire session.

## BLOCKED commands — do NOT attempt these

### curl / wget — BLOCKED
Any Bash command containing `curl` or `wget` is intercepted and replaced with an error message. Do NOT retry.
Instead use:
- `ctx_fetch_and_index(url, source)` to fetch and index web pages
- `ctx_execute(language: "javascript", code: "const r = await fetch(...)")` to run HTTP calls in sandbox

### Inline HTTP — BLOCKED
Any Bash command containing `fetch('http`, `requests.get(`, `requests.post(`, `http.get(`, or `http.request(` is intercepted and replaced with an error message. Do NOT retry with Bash.
Instead use:
- `ctx_execute(language, code)` to run HTTP calls in sandbox — only stdout enters context

### WebFetch — BLOCKED
WebFetch calls are denied entirely. The URL is extracted and you are told to use `ctx_fetch_and_index` instead.
Instead use:
- `ctx_fetch_and_index(url, source)` then `ctx_search(queries)` to query the indexed content

## REDIRECTED tools — use sandbox equivalents

### Bash (>20 lines output)
Bash is ONLY for: `git`, `mkdir`, `rm`, `mv`, `cd`, `ls`, `npm install`, `pip install`, and other short-output commands.
For everything else, use:
- `ctx_batch_execute(commands, queries)` — run multiple commands + search in ONE call
- `ctx_execute(language: "shell", code: "...")` — run in sandbox, only stdout enters context

### Read (for analysis)
If you are reading a file to **Edit** it → Read is correct (Edit needs content in context).
If you are reading to **analyze, explore, or summarize** → use `ctx_execute_file(path, language, code)` instead. Only your printed summary enters context. The raw file content stays in the sandbox.

### Grep (large results)
Grep results can flood context. Use `ctx_execute(language: "shell", code: "grep ...")` to run searches in sandbox. Only your printed summary enters context.

## Tool selection hierarchy

1. **GATHER**: `ctx_batch_execute(commands, queries)` — Primary tool. Runs all commands, auto-indexes output, returns search results. ONE call replaces 30+ individual calls.
2. **FOLLOW-UP**: `ctx_search(queries: ["q1", "q2", ...])` — Query indexed content. Pass ALL questions as array in ONE call.
3. **PROCESSING**: `ctx_execute(language, code)` | `ctx_execute_file(path, language, code)` — Sandbox execution. Only stdout enters context.
4. **WEB**: `ctx_fetch_and_index(url, source)` then `ctx_search(queries)` — Fetch, chunk, index, query. Raw HTML never enters context.
5. **INDEX**: `ctx_index(content, source)` — Store content in FTS5 knowledge base for later search.

## Subagent routing

When spawning subagents (Agent/Task tool), the routing block is automatically injected into their prompt. Bash-type subagents are upgraded to general-purpose so they have access to MCP tools. You do NOT need to manually instruct subagents about context-mode.

## Output constraints

- Keep responses under 500 words.
- Write artifacts (code, configs, PRDs) to FILES — never return them as inline text. Return only: file path + 1-line description.
- When indexing content, use descriptive source labels so others can `ctx_search(source: "label")` later.

## ctx commands

| Command | Action |
|---------|--------|
| `ctx stats` | Call the `ctx_stats` MCP tool and display the full output verbatim |
| `ctx doctor` | Call the `ctx_doctor` MCP tool, run the returned shell command, display as checklist |
| `ctx upgrade` | Call the `ctx_upgrade` MCP tool, run the returned shell command, display as checklist |
