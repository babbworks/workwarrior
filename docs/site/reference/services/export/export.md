# services/export/export.sh

**Type:** Executed service script
**Invoked by:** `ww export`
**Subservient to:** Export service (`services/export/`)

---

## Role

User-facing export interface. Parses arguments, validates format and data type selections, then delegates to `lib/export-utils.sh` for the actual export logic. Supports interactive mode (prompts for options) and non-interactive mode (all options via flags).

---

## Command Surface

```
ww export                         Interactive export wizard
ww export tasks --format json     Export tasks as JSON
ww export tasks --format csv      Export tasks as CSV
ww export tasks --format markdown Export tasks as Markdown
ww export time --format json      Export time entries
ww export journal --format markdown
ww export ledger --format csv
ww export all --format json       All data types in one JSON document
ww export backup                  Create profile backup archive
ww export --profile <name>        Export from a specific profile
ww export --since <date>          Filter by date range
ww export --output <path>         Write to file instead of stdout
```

---

## Functions

**`parse_arguments()`** — Parses all flags and positional args. Sets: `DATA_TYPE`, `FORMAT`, `PROFILE`, `SINCE`, `OUTPUT_PATH`.

**`require_profile()`** — Exits with error if no profile is active and `--profile` was not specified.

**`validate_format(format)`** — Returns 1 if format is not `json`, `csv`, or `markdown`.

**`get_date_filter(since)`** — Converts `--since` value to tool-specific filter syntax (e.g. `task` filter, `timew` range).

**`do_export_tasks/time/journal/ledger()`** — Calls the corresponding `lib/export-utils.sh` function with resolved profile base and format.

**`do_export_all()`** — Calls `export_all_json()` from `lib/export-utils.sh`. Only supports JSON format.

**`do_export_backup()`** — Calls `export_profile_backup()`. Creates `.tar.gz` in `$WW_BASE/backups/` or `--output` path.

**`interactive_export()`** — Prompts for data type, format, date range, and output path. Used when `ww export` is called with no arguments.

---

## Output

Without `--output`: writes to stdout (pipeable).
With `--output <path>`: writes to file, prints confirmation with file size.

JSON output is always wrapped in the standard envelope:
```json
{"profile": "work", "type": "tasks", "exported_at": "...", "data": [...]}
```

## Changelog

- 2026-04-10 — Initial version
