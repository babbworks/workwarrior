# lib/profile-manager.sh

**Type:** Sourced bash library  
**Size:** ~1817 lines — largest lib file  
**Fragility:** HIGH — writes to profile directories; bugs here corrupt user data

---

## Role

All profile lifecycle operations: creation, deletion, backup, import, restore, journal/ledger management. Every operation that modifies a profile directory goes through this file. Service scripts and `bin/ww` call these functions rather than writing to profile directories directly.

---

## Profile Creation

**`create_profile_directories(profile_base)`**  
Creates the full directory tree for a new profile:
- `.task/` (TaskWarrior data)
- `.task/hooks/` (hook scripts)
- `.timewarrior/` (TimeWarrior data)
- `.timewarrior/extensions/` (per-profile timew extensions)
- `.config/bugwarrior/` (bugwarrior config)
- `journals/` (JRNL files)
- `ledgers/` (Hledger files)

**`create_taskrc(profile_base, profile_name)`**  
Copies `resources/config-files/.taskrc` template to `profiles/<name>/.taskrc` and updates `data.location` to the profile's `.task/` path.

**`install_timewarrior_hook(profile_base)`**  
Copies `services/profile/on-modify.timewarrior` hook template to `profiles/<name>/.task/hooks/on-modify.timewarrior` and makes it executable. The hook reads `TIMEWARRIORDB` at runtime — no path hardcoding.

**`create_journal_config(profile_base, profile_name)`**  
Writes `jrnl.yaml` with a default journal entry pointing to `journals/<name>.txt`.

**`create_ledger_config(profile_base, profile_name)`**  
Writes `ledgers.yaml` with a default ledger entry.

---

## Journal Management

**`add_journal_to_profile(profile_name, journal_name)`**  
Appends a new journal entry to `jrnl.yaml`. Creates the journal file. Idempotent — warns if journal already exists.

**`remove_journal_from_profile(profile_name, journal_name)`**  
Removes journal entry from `jrnl.yaml`. Does not delete the journal file (data safety).

**`rename_journal_in_profile(profile_name, old_name, new_name)`**  
Updates `jrnl.yaml` entry. Does not rename the underlying file.

**`copy_journal_from_profile(source_profile, journal_name, dest_profile)`**  
Copies journal config entry and file between profiles.

---

## Ledger Management

Same pattern as journals: `add_ledger_to_profile`, `remove_ledger_from_profile`, `rename_ledger_in_profile`, `copy_ledger_from_profile`.

---

## Backup / Import / Restore

**`import_profile(archive_path, new_name)`**  
Creates a new profile from a `.tar.gz` backup archive. Errors if the profile name already exists — safe by design (cannot overwrite).

**`restore_profile(profile_name, archive_path)`**  
Replaces an existing profile from a backup archive. Uses two-phase commit:
1. Extract archive to a temp directory
2. Create a safety backup of the current profile
3. Only then replace — if the move fails, the original is preserved

This was a critical bug fix (TASK-SYNC-002): the original implementation deleted the profile before confirming the replacement succeeded.

---

## Design Constraints

- Never write to profile directories directly from service scripts — always call these functions
- All paths are absolute — no `cd` calls
- `.taskrc` writes use `task rc.confirmation=no config` to avoid interactive prompts
- Backup archives are `.tar.gz` with timestamp in filename
- `restore_profile` requires the profile to already exist (use `import_profile` for new profiles)

## Changelog

- 2026-04-10 — Initial version
