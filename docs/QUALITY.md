# Quality Scoring Rubric

Every plugin in the marketplace receives an automated quality score from 0 to 100.
The score is computed by `scripts/score-plugin.sh` across **5 categories**, each worth
**20 points**. The model is subtractive: every plugin starts at 100 and loses points
for each failed check.

## Categories

### 1. Manifest Completeness (20 pts) -- 8 rules

| # | Check | Deduction | Condition |
|---|-------|-----------|-----------|
| 1 | Missing `description` | -4 | `description` absent or empty |
| 2 | Missing `version` | -3 | `version` absent or empty |
| 3 | Missing `author` | -3 | `author` field is null |
| 4 | Missing `homepage` | -2 | `homepage` absent or empty |
| 5 | Missing `repository` | -2 | `repository` absent or empty |
| 6 | Missing `license` | -2 | `license` absent or empty |
| 7 | Missing `keywords` | -2 | `keywords` array is null |
| 8 | Undeclared artifact directories | -2 | `agents/`, `commands/`, or `skills/` directory exists but is not declared in manifest |

### 2. Documentation (20 pts) -- 5 rules

| # | Check | Deduction | Condition |
|---|-------|-----------|-----------|
| 9 | Missing README | -6 | No `README.md` (or `*README*.md`) in plugin root |
| 10 | Missing CLAUDE.md | -6 | No `CLAUDE.md` in plugin root |
| 11 | README too short | -3 | README exists but has fewer than 50 lines |
| 12 | Description too short | -3 | `description` exists but is fewer than 20 characters |
| 13 | Missing keywords for discovery | -2 | `keywords` array is null |

### 3. Structure Integrity (20 pts) -- 5 rules

| # | Check | Deduction | Condition |
|---|-------|-----------|-----------|
| 14 | Missing `.claude-plugin` directory | -6 | `.claude-plugin/` directory does not exist |
| 15 | Declared file not found | -4 each (max -12) | A path listed in `commands`, `agents`, or `skills` does not resolve to a file |
| 16 | Undeclared artifact files | -2 | `agents/`, `commands/`, or `skills/` directory exists without a matching manifest declaration |
| 17 | Hook script not executable | -3 | A hook references a `.sh` script that exists but lacks the execute bit |
| 18 | Empty artifact directory | -2 | An `agents/`, `commands/`, `skills/`, or `workflows/` directory contains zero files |

### 4. Naming Conventions (20 pts) -- 6 rules

| # | Check | Deduction | Condition |
|---|-------|-----------|-----------|
| 19 | Plugin name not lowercase-hyphenated | -4 | `name` does not match `^[a-z][a-z0-9-]*$` |
| 20 | Inconsistent agent naming | -4 | Agent `.md` filenames lack a shared prefix pattern (checks majority prefix consistency) |
| 21 | Commands in non-standard directory | -2 | Commands declared but first command path resolves outside `commands/` |
| 22 | Agent file extension wrong | -3 | An agent path declared in manifest does not end with `.md` |
| 23 | Version format invalid | -3 | `version` exists but does not match semver `X.Y.Z` |
| 24 | Unexpected manifest fields | -2 | Top-level keys not in the known schema field list |

### 5. Version Hygiene (20 pts) -- 6 rules

| # | Check | Deduction | Condition |
|---|-------|-----------|-----------|
| 25 | No version in manifest | -6 | `version` field absent or empty |
| 26 | Invalid semver format | -4 | `version` exists but does not match `X.Y.Z` |
| 27 | Pre-1.0 version | -2 | Major version is `0` |
| 28 | VERSION file mismatch | -3 | `VERSION` file exists and its content differs from manifest `version` |
| 29 | No CHANGELOG.md | -3 | `CHANGELOG.md` not found in plugin root |
| 30 | Version contains build metadata | -2 | `version` string contains a `+` character |

## How Scoring Works

Scoring uses a **subtractive model**. Every plugin begins with a perfect 100
(20 per category) and loses points only when a check fails. This means a
well-structured plugin scores 100 by default -- you never have to "earn" points,
only avoid losing them.

During Phase 3 the score is **informational**. It appears in PR comments and in
`marketplace.json`, but it does not gate merges. A future phase may introduce
minimum-score thresholds for merge protection.

## Improving Your Score

**Manifest Completeness** -- Fill in every optional field (`description`,
`version`, `author`, `homepage`, `repository`, `license`, `keywords`). Declare
any artifact directories that exist.

**Documentation** -- Add a `README.md` with at least 50 lines covering purpose,
installation, and usage. Add a `CLAUDE.md` for Claude Code integration notes.
Write a description of at least 20 characters.

**Structure Integrity** -- Ensure every path declared in `commands`, `agents`,
or `skills` actually exists on disk. Mark hook scripts as executable
(`chmod +x`). Remove empty artifact directories or populate them.

**Naming Conventions** -- Use lowercase-hyphenated plugin names. Keep agent
filenames consistent (shared prefix or shared pattern). Use `.md` extensions for
agents. Follow semver for the version string.

**Version Hygiene** -- Set a `version` field in semver format. If you include a
`VERSION` file, make sure it matches. Add a `CHANGELOG.md`. Target version 1.0+
when your plugin is production-ready.

## Running Locally

Human-readable output:

```bash
./scripts/score-plugin.sh plugins/<name>
```

Machine-readable JSON:

```bash
./scripts/score-plugin.sh plugins/<name> --json
```

Example output (human):

```
Quality Score: grd -- 79/100

  Manifest Completeness    16/20  -2 missing homepage, -2 missing repository
  Documentation            20/20  --
  ...
```

## Branch Protection (Recommended)

To surface quality scores during code review, configure the following GitHub
branch protection settings on `main`:

1. **Require status checks** -- add the `validate-plugins` check so PRs cannot
   merge without passing schema validation.
2. **Require pull request reviews** -- at least one approval from a CODEOWNERS
   member.
3. **Restrict direct pushes** -- all changes go through PRs for visibility.

The CI pipeline (`validate-plugins.yml`) already posts quality scores as PR
comments. Branch protection ensures those comments are visible before merge.

## Score in CI

The `validate-plugins.yml` workflow runs `score-plugin.sh` on every changed
plugin during PR validation. The score is posted as a PR comment for reviewer
visibility. On merge, `publish-marketplace.yml` regenerates `marketplace.json`
with the latest `qualityScore` field for each plugin.
