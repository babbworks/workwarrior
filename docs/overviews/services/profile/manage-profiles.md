# services/profile/manage-profiles.sh

**Type:** Executed service script
**Invoked by:** `ww profile list|info|delete|backup|import|restore`
**Subservient to:** Profile service (`services/profile/`)

---

## Role

Profile lifecycle management beyond creation: listing, info display, deletion, backup, import, restore. Delegates to `lib/profile-manager.sh` for all operations that modify profile directories.

---

## Actions

**`list`** — Lists all profiles in `$WW_BASE/profiles/` sorted alphabetically. With `--json`: outputs JSON array of profile names. With `--compact`: one name per line.

**`info <name>`** — Displays profile details: path, creation date, task count, time entries, journal count, last activity. Calls `lib/profile-stats.sh` functions.

**`delete <name>`** — Calls `lib/delete-utils.sh`:
1. `require_inactive_profile()` — blocks if profile is active
2. `preview_profile_deletion()` — shows data counts
3. Prompts for confirmation
4. `backup_before_delete()` — creates safety backup
5. `delete_profile()` — removes directory and aliases

**`backup <name> [dest]`** — Creates `.tar.gz` archive. Default destination: `$WW_BASE/backups/`. Filename: `<name>-<YYYYMMDDHHMMSS>.tar.gz`.

**`import <archive> [new-name]`** — Creates a new profile from a backup archive. Errors if the profile name already exists. Calls `lib/profile-manager.sh:import_profile()`.

**`restore <name> <archive>`** — Replaces an existing profile from a backup archive. Requires the profile to already exist. Creates a safety backup before replacing. Calls `lib/profile-manager.sh:restore_profile()`.

---

## Import vs Restore

| Operation | Profile must exist? | Overwrites? | Safety backup? |
|---|---|---|---|
| `import` | No (creates new) | Never | N/A |
| `restore` | Yes | Yes | Always |

This distinction prevents accidental overwrites. `import` is safe by default; `restore` is explicit about its danger.
