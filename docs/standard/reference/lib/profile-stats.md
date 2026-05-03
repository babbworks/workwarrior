# lib/profile-stats.sh

**Type:** Sourced bash library
**Used by:** `ww profile info`, `services/profile/profile-tool.sh`

---

## Role

Aggregates statistics across all four data types (tasks, time, journals, ledger) for a profile. Powers `ww profile info` display and any dashboard-style output.

---

## Per-Tool Stats

**`get_task_stats(profile_base)`** — Returns JSON: `{pending, completed, deleted, overdue, active}` counts.
**`get_task_recent(profile_base, n)`** — Returns the N most recently modified tasks.
**`get_task_last_modified(profile_base)`** — Returns ISO timestamp of the most recently modified task.

**`get_time_stats(profile_base)`** — Returns JSON: total tracked hours, entries count, most-tracked tag.
**`parse_time_summary(timew_output)`** — Parses `timew summary` output into structured data.
**`parse_time_to_hours(duration_string)`** — Converts `timew` duration strings (`1h 23min`) to decimal hours.
**`get_time_recent(profile_base, n)`** — Returns N most recent time entries.
**`get_time_last_entry(profile_base)`** — Returns timestamp of most recent time entry.

**`get_journal_stats(profile_base)`** — Returns JSON: entry count per journal, total word count.
**`get_journal_recent(profile_base, n)`** — Returns N most recent journal entries (title + date).
**`get_journal_last_entry(profile_base)`** — Returns date of most recent journal entry.

**`get_ledger_stats(profile_base)`** — Returns JSON: account count, transaction count, balance summary.
**`get_ledger_recent(profile_base, n)`** — Returns N most recent ledger transactions.
**`get_ledger_last_entry(profile_base)`** — Returns date of most recent transaction.

---

## Aggregate

**`get_profile_summary(profile_base)`** — Calls all four stat functions and returns a combined JSON object. Used by `ww profile info`.

**`get_last_activity(profile_base)`** — Returns the most recent activity timestamp across all four tools. Used to show "last active" in profile listings.

**`format_relative_time(timestamp)`** — Converts an ISO timestamp to a human-readable relative string: "2 hours ago", "yesterday", "3 days ago".

## Changelog

- 2026-04-10 — Initial version
