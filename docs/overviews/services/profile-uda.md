# services/profile/subservices/profile-uda.sh

**Type:** Executed service script  
**Invoked by:** `ww profile uda <subcommand>` via `bin/ww cmd_profile()`

---

## Role

Full UDA management surface for active profiles. Handles listing, adding, removing, grouping, color rules, indicators, and sync permissions. The canonical interface for all UDA operations — `uda-manager.sh` is the legacy interactive tool that still works but this is the primary surface.

---

## UDA Classification

UDAs are classified into three tiers:

**Service-managed** (`_is_service_uda()` returns true):
- `github_*`, `gitlab_*`, `jira_*`, `trello_*`, `bw_*` → `bugwarrior[*]`
- `sync_id`, `sync_repo`, `sync_state`, `sync_last`, `sync_url` → `github-sync`
- `density`, `densitywindow` → `extension:twdensity`
- `estimated`, `time_map` → `extension:taskcheck`

Service-managed UDAs are shown in a separate section in `ww profile uda list` with a warning not to rename or delete them. They cannot be removed via `ww profile uda remove` without `--force`.

**User-defined:** All other UDAs not in the above set.

**Uncategorized:** UDAs marked with `# uda:<name> uncategorized` in `.taskrc`. Hidden from default list output; shown with `--all`.

---

## Subcommands

**`list [--all]`**  
Displays UDAs grouped by: service-managed sections → named groups → ungrouped user UDAs → uncategorized (if `--all`). Each row shows: indicator char, name, type, label, values, group badges, permission badges.

**`add [name]`**  
Interactive wizard: name → type → label → values (with order confirmation) → group assignment → auto-assigns indicator and color rule based on group.

**`remove <name>`**  
Warns if service-managed. Warns if UDA has values on any task. Requires `--force` past either warning. Removes all `uda.<name>.*` lines from `.taskrc`.

**`group <name> [group]`**  
Assigns UDA to a group. Writes/updates `# === WW UDA GROUPS ===` block in `.taskrc`.

**`color <name> [spec]`**  
Show or set `color.uda.<name>=<spec>` in `.taskrc`. Manages `# === WW COLOR RULES ===` block.

**`perm <name> [tokens]`**  
Show or set sync permission tokens via `lib/sync-permissions.sh`. Tokens: `nosync`, `deny:<svc>`, `readonly`, `writeonly`, `private`, `noreport`, `noexport`, `noai`, `managed`, `locked`.

---

## .taskrc Managed Sections

This script manages three sentinel-delimited sections in `.taskrc`:

```
# === WW UDA GROUPS ===
# group:work udas:goals,phase,scope description:"..."
# === END WW UDA GROUPS ===

# === WW COLOR RULES ===
color.uda.goals=orange
color.uda.phase.review=bold green
# === END WW COLOR RULES ===
```

All writes to these sections use `sed -i.bak` with immediate `.bak` cleanup. Never use `task config` for these — it doesn't understand the section format.

---

## Indicator and Color Auto-assignment

When a UDA is added to a group, the indicator character and color rule are auto-assigned from:
- `system/config/uda-indicator-map.yaml` — group → unicode char
- `system/config/uda-color-map.yaml` — group → TW color spec, with per-UDA and per-value overrides

Both maps are parsed with POSIX `awk` (not `yq`) for portability.

## Changelog

- 2026-04-10 — Initial version
