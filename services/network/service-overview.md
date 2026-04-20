# Service overview: `network`

**Source:** TASK-DESIGN-001 (design-only.)

## Purpose

Centralize optional connectivity checks and latency-sensitive operations used by browser UI, AI routes, and sync—without each feature reimplementing `curl` probes.

## Target user

Browser and CTRL services; integration tests that need consistent “can reach X?” semantics.

## Command surface (sketch)

- `ww network probe [--json]` — Ollama, GitHub API, configured model base URLs (read-only, no secrets printed).
- `ww network policy show` — display effective timeouts and proxy env usage.

## Data / integrations

- Reads: `config/ai.yaml`, `config/models.yaml`, environment (`https_proxy`, `OLLAMA_HOST`).
- Writes: optional cache file under `$WW_BASE/.state/` with TTL (future).

## Open questions

- Relationship to `ww ctrl` status vs a dedicated network domain.
- Sandboxed/CI behavior (skip vs fail).
- Rate-limit handling shared with GitHub sync tooling.
