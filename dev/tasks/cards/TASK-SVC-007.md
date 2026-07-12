# TASK-SVC-007 — Profile removal service (`ww remove`)

**Status:** complete
**Priority:** HIGH
**Created:** 2026-04-12
**Completed:** 2026-04-12

## Goal

Build a `ww remove` service that cleanly removes profiles from the system, scrubbing all references across config, state, question templates, and shell aliases.

## Acceptance Criteria

- [x] `ww remove <profile> [profile2 ...]` — remove specific profiles
- [x] `ww remove --keep <profile> [profile2 ...]` — remove all EXCEPT listed
- [x] `ww remove --all` — remove all profiles (interactive)
- [x] `ww remove --list` — show removable profiles with active marker
- [x] Per-profile prompt: [a]rchive, [d]elete, or [s]kip
- [x] `--archive-all` / `--delete-all` — batch mode without per-profile prompt
- [x] `--dry-run` — show what would happen without doing it
- [x] `--force` — skip confirmation prompts
- [x] Archive moves to `profiles/.archive/<name>-<timestamp>/`
- [x] Scrubs profile from `config/groups.yaml`
- [x] Clears `.state/active_profile` and `.state/last_profile` if they match
- [x] Removes profile-specific question templates from `services/questions/`
- [x] Removes shell aliases (`p-<name>`, `j-<name>`, `l-<name>`) from RC files

## Files

- `services/remove/remove.sh` — main service script
- `bin/ww` — `remove)` case branch added
- `services/browser/server.py` — `remove` added to ALLOWED_SUBCOMMANDS

## Future Work (flagged, not implemented)

- **`--scramble` flag**: Before deletion, obfuscate profile data in multiple ways:
  - Scramble task descriptions (replace words with random words of same length)
  - Scramble journal content (replace text with lorem ipsum of same line count)
  - Scramble ledger amounts (randomize within ±50% of original values)
  - Scramble time tracking tags (replace with generic tags)
  - Zero out UDA string values, randomize numeric UDA values
  - Overwrite files with random data before unlinking (secure delete)
  - Multiple passes option: `--scramble=3` for 3-pass overwrite
  - Purpose: ensure deleted profile data cannot be recovered from disk or git history
