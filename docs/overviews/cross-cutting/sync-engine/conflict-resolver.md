# lib/conflict-resolver.sh

**Type:** Sourced bash library
**Part of:** GitHub Sync Engine — see `cross-cutting/sync-engine/overview.md`
**Fragility:** HIGH — wrong resolution direction causes permanent data loss

---

## Role

Resolves conflicts when both the TaskWarrior task and the GitHub issue have changed since the last sync. Uses last-write-wins strategy: whichever side was modified more recently wins.

---

## Functions

**`compare_timestamps(ts1, ts2)`**
Compares two ISO 8601 timestamps. Returns 0 if ts1 is newer, 1 if ts2 is newer, 2 if equal.

**`resolve_conflict_last_write_wins(task_uuid)`**
Main resolution function. Reads sync state to get last-known timestamps for both sides. Compares current task `modified` field against GitHub issue `updatedAt`. Whichever is newer determines the sync direction:
- Task newer → push (TaskWarrior wins)
- GitHub newer → pull (GitHub wins)
- Equal → no action

Logs the resolution decision to `sync.log` via `log_conflict_resolution()`.

**`log_conflict_resolution(task_uuid, resolution, details)`**
Writes a structured conflict resolution entry to the sync log. Includes: timestamp, task UUID, which side won, the timestamps compared, and the resulting action.

---

## Conflict Window

The conflict window is the period between when the last sync state was saved and when the next sync runs. Any changes on either side during this window are candidates for conflict. The window is minimised by syncing frequently — but never eliminated entirely.

---

## Limitations

Last-write-wins is simple and predictable but lossy: the losing side's changes are discarded without merge. For text fields (description, body), this means one side's edits are lost. For status fields (open/closed), it means the more recent state wins regardless of intent.

A future improvement (not yet planned) would be field-level merge for text fields.
