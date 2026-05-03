# lib/core-utils.sh

**Type:** Sourced bash library  
**Sourced by:** `bin/ww-init.sh`, most service scripts  
**Guard:** `[[ -z "${CORE_UTILS_LOADED:-}" ]]` — safe to source multiple times

---

## Role

Foundation utilities: WW_BASE resolution, profile validation, directory management, service discovery. Everything else in the system depends on this file being sourced first.

---

## Key Variables Set

| Variable | Value | Notes |
|---|---|---|
| `WW_BASE` | `~/ww` (or `$WW_BASE` if already set) | Install root — never hardcoded |
| `PROFILES_DIR` | `$WW_BASE/profiles` | All profile directories live here |
| `CORE_UTILS_LOADED` | `1` | Re-source guard |

---

## Public Functions

### Profile validation

**`validate_profile_name(name)`**  
Returns 0 if name is valid (alphanumeric + hyphens/underscores, 1–50 chars). Returns 1 with error message if invalid. Called before any profile creation or activation.

**`profile_exists(name)`**  
Returns 0 if `$PROFILES_DIR/<name>` exists as a directory.

**`ensure_profile_exists(name)`**  
Calls `profile_exists()` and exits with error if not found.

**`require_active_profile()`**  
Exits with error if `WARRIOR_PROFILE` or `WORKWARRIOR_BASE` is not set. Used by services that require an active profile.

### Directory management

**`ensure_directory(path)`**  
Creates directory if it doesn't exist. Returns 1 on failure. Used throughout profile creation.

### Profile listing

**`list_profiles()`**  
Returns sorted list of profile names from `$PROFILES_DIR`. Used by `ww profile list` and shell completion.

### Service discovery

**`discover_services(category)`**  
Scans `$WW_BASE/services/<category>/` and (if active profile) `$WORKWARRIOR_BASE/services/<category>/` for executable files. Profile-level files shadow global ones. Returns newline-separated list of script paths.

**`get_service_path(category, name)`**  
Returns the resolved path for a specific service script, respecting profile override.

**`service_exists(category, name)`**  
Returns 0 if the service script exists (profile or global).

### State management

**`get_last_profile()`** / **`set_last_profile(name)`**  
Read/write `$WW_BASE/.state/last_profile`. Used by `resolve_scope_context()` in `bin/ww` to restore the last active profile when no profile is explicitly set.

### Utilities

**`file_readable(path)`** — Returns 0 if file exists and is readable.  
**`die(message)`** — Prints error and exits 1. For unrecoverable errors only.

---

## Design Notes

- No `set -euo pipefail` — sourced libs never set flags (would propagate to caller)
- Uses `${var:-}` defensive guards on all variable expansions
- `WW_BASE` is resolved once at source time via `${WW_BASE:-$HOME/ww}` — never `readonly`
- Log functions (`log_info` etc.) are defined here as thin wrappers; the full logging system is in `lib/logging.sh`

## Changelog

- 2026-04-10 — Initial version
