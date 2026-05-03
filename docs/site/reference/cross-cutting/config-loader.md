# lib/config-loader.sh — Cross-Cutting: GitHub Sync Config

**Type:** Sourced bash library
**Used by:** `services/custom/github-sync.sh`, `lib/sync-pull.sh`, `lib/sync-push.sh`
**Classification:** Cross-cutting — sync config loading used across the entire sync engine

---

## Role

Loads and validates the GitHub sync configuration from the active profile's bugwarrior config file. Exports config values as environment variables for use by the sync engine. Also provides tag/label exclusion filtering.

---

## Config Source

GitHub sync config is stored in the bugwarrior config file at:
```
$WORKWARRIOR_BASE/.config/bugwarrior/bugwarriorrc
```
or
```
$WORKWARRIOR_BASE/.config/bugwarrior/bugwarrior.toml
```

The sync engine reads the `[github]` section for: `login`, `username`, `token` (or `@oracle:eval:gh auth token`), `project_template`, and any exclusion lists.

---

## Functions

**`init_github_sync_config()`**
Main entry point. Locates the config file, calls `load_github_sync_config()`, then `validate_github_sync_config()`. Returns 1 with error if config is missing or invalid. Called by `github-sync.sh main()` before any sync operation.

**`load_github_sync_config(config_path)`**
Parses the bugwarrior config file and exports:
- `GITHUB_LOGIN` — authenticated GitHub user
- `GITHUB_USERNAME` — namespace/org to sync from
- `GITHUB_TOKEN` — token value (or oracle directive)
- `GITHUB_PROJECT_TEMPLATE` — project label template

**`validate_github_sync_config()`**
Checks that required fields are set. Returns 1 with specific error if `GITHUB_LOGIN` or `GITHUB_USERNAME` is missing.

**`get_config_value(config_path, section, key)`**
Reads a single key from an INI-style config file. Used for targeted config reads without loading the full config.

**`export_github_sync_config()`**
Re-exports all config values to the environment. Called when spawning subprocesses that need the config.

---

## Tag/Label Exclusion

**`is_tag_excluded(tag)`** — Returns 0 if the tag is in the configured exclusion list. Exclusions are defined in the bugwarrior config as `only_if_assigned` or custom exclusion lists.

**`is_label_excluded(label)`** — Same for GitHub labels.

---

## Oracle Token Pattern

When `gh` CLI is present and authenticated, the bugwarrior config stores:
```
github.token = @oracle:eval:gh auth token
```
The oracle directive is evaluated at pull time — the token is never written to the config file. `load_github_sync_config()` detects this pattern and evaluates it via `gh auth token` to get the actual token value for API calls.

## Changelog

- 2026-04-10 — Initial version
