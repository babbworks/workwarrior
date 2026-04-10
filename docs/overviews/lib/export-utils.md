# lib/export-utils.sh

**Type:** Sourced bash library
**Used by:** `services/export/export.sh`

---

## Role

All data export logic for profile data. Exports tasks, time tracking, journals, and ledger data in JSON, CSV, and Markdown formats. Also handles profile backup archives.

---

## Export Functions by Data Type

### Tasks
**`export_tasks_json(profile_base, [filter])`** — `task export` output wrapped in a JSON envelope with profile metadata.
**`export_tasks_csv(profile_base, [filter])`** — Flattened task fields as CSV. Uses `csv_escape()` for safe quoting.
**`export_tasks_markdown(profile_base, [filter])`** — Task list as Markdown table with urgency, due date, project, tags.

### Time
**`export_time_json(profile_base, [range])`** — `timew export` output with profile metadata.
**`export_time_csv(profile_base, [range])`** — Time entries as CSV: start, end, duration, tags.
**`export_time_markdown(profile_base, [range])`** — Time summary as Markdown table grouped by tag.

### Journals
**`export_journal_json(profile_base, [journal_name])`** — Journal entries parsed from JRNL files into JSON array.
**`export_journal_csv(profile_base, [journal_name])`** — Journal entries as CSV: date, title, body.
**`export_journal_markdown(profile_base, [journal_name])`** — Journal entries as Markdown with date headers.

### Ledger
**`export_ledger_json(profile_base, [ledger_name])`** — Hledger balance/register output as JSON.
**`export_ledger_csv(profile_base, [ledger_name])`** — Hledger register as CSV.
**`export_ledger_markdown(profile_base, [ledger_name])`** — Hledger balance as Markdown table.

### Combined
**`export_all_json(profile_base)`** — All four data types in a single JSON document.
**`export_profile_backup(profile_base, dest_path)`** — Creates a `.tar.gz` archive of the full profile directory. Used by `ww profile backup` and `delete-utils.sh` pre-deletion backup.

---

## Utilities

**`get_profile_dir(profile_name)`** — Resolves profile base path from name.
**`get_export_path(profile_base, format, data_type)`** — Generates timestamped output filename.
**`csv_escape(value)`** — Wraps value in quotes and escapes internal quotes. Handles newlines in task descriptions.
**`json_wrapper(data, profile_name, data_type)`** — Wraps raw export data in a standard envelope: `{"profile": "...", "type": "...", "exported_at": "...", "data": [...]}`.

## Changelog

- 2026-04-10 — Initial version
