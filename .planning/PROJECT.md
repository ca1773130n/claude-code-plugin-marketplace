# Claude Code Plugin Marketplace

> **Repo renamed:** `claude-plugin-marketplace` → `claude-code-plugin-marketplace`
> **Version reset:** Pre-release work preserved as v0.0.1–v0.0.5. Fresh start at **v0.1.0**.

## Vision

Build a self-service marketplace infrastructure for Claude Code plugins that ensures every published plugin meets a consistent quality bar through automated validation, CI/CD pipelines, and quality gates — making it as easy to submit a plugin as opening a pull request, and as safe to install one as pulling from a curated registry.

## Primary Goal

Establish end-to-end automated validation and publishing so that any plugin submitted via PR is validated against a formal schema, tested for structural correctness, scored for quality, and published to the marketplace registry — all without manual intervention.

### Measurable Success Criteria

- 100% of PRs that add or modify plugins receive automated validation feedback within 3 minutes
- 0% of structurally invalid plugins can merge to main
- New plugin onboarding time drops from ~1 hour (manual) to <10 minutes (template + PR)

## Secondary Goals

- Plugin quality scoring system (0-100) visible to consumers
- Submission template and scaffolding so third-party authors can self-serve
- Formal plugin specification via JSON Schema as the contract
- Machine-readable marketplace index with quality metadata

## Non-Goals

- Plugin runtime sandboxing or security isolation
- Web-based marketplace UI or search frontend
- Plugin auto-update or version pinning for consumers
- Paid plugin distribution or licensing enforcement
- Supporting non-Claude-Code plugin formats (OpenCode/Gemini support is plugin-internal)

## Current State

- GitHub repo: ca1773130n/claude-code-plugin-marketplace (renamed from claude-plugin-marketplace)
- Pre-release (v0.0.1–v0.0.5): Schema validation, CI/CD, quality gates, onboarding, integration hardening — all complete
- Starting v0.1.0 development

## Technology Stack

- JSON Schema (Draft-07) for manifest validation
- ajv-cli for schema validation in CI
- GitHub Actions for CI/CD orchestration
- jq for JSON manipulation
- Bash scripts for validation and publishing logic
