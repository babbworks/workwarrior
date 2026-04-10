# lib/delete-utils.sh

**Type:** Sourced bash library
**Used by:** `services/x-delete/x.sh`, `ww profile delete`

---

## Role

Safe profile and data deletion. Every destructive operation is preceded by a backup and a data count preview. The profile must not be currently active before deletion proceeds.

---

## Safety Checks

**`check_profile_active(profile_name)`** — Returns 0 if the profile is currently active (`WARRIOR_PROFILE` matches). Used to warn before deletion.

**`require_inactive_profile(profile_name)`** — Exits with error if the profile is active. Deletion of an active profile would leave dangling env vars pointing to deleted directories.

**`preview_profile_deletion(profile_name)`** — Shows counts of tasks, time entries, journal entries, and ledger entries before asking for confirmation. Gives the user a clear picture of what will be lost.

**`preview_tool_deletion(profile_name, tool)`** — Shows data counts for a specific tool within a profile.

---

## Backup Before Delete

**`backup_before_delete(profile_name)`** — Creates a timestamped `.tar.gz` backup in `$WW_BASE/backups/` before any deletion. Returns the backup path so the user can be shown where to find it. Deletion proceeds only after backup succeeds.

---

## Deletion Functions

**`delete_profile(profile_name)`** — Full profile deletion: backup → confirm → remove directory → remove aliases from rc files.

**`delete_profile_aliases(profile_name)`** — Removes `p-<name>` and bare `<name>` aliases from all rc files.

Per-tool deletion (used for selective data removal):
- **`delete_tasks_data(profile_base)`** — Removes `.task/` directory
- **`delete_time_data(profile_base)`** — Removes `.timewarrior/data/`
- **`delete_journal_data(profile_base, journal_name)`** — Removes specific journal file
- **`delete_ledger_data(profile_base, ledger_name)`** — Removes specific ledger file
- **`delete_task_config(profile_base)`** — Removes `.taskrc`
- **`delete_time_config(profile_base)`** — Removes `timewarrior.cfg`
- **`delete_journal_config(profile_base, journal_name)`** — Removes journal entry from `jrnl.yaml`
- **`delete_ledger_config(profile_base, ledger_name)`** — Removes ledger entry from `ledgers.yaml`
- **`delete_profile_exports(profile_base)`** — Removes any export files in the profile directory

---

## Data Count Functions

**`get_task_count(profile_base)`** — Counts pending tasks via `task export`.
**`get_time_count(profile_base)`** — Counts time entries via `timew export`.
**`get_journal_count(profile_base)`** — Counts journal entries by line count.
**`get_ledger_count(profile_base)`** — Counts ledger transactions.

## Changelog

- 2026-04-10 — Initial version
