# Service Concept: Dumps

## Purpose

Profile data snapshot service. Creates full or partial point-in-time snapshots of a
profile's data for backup, migration, inspection, or handoff. Distinct from `export`
(which produces tool-specific raw data exports) and `reports` (which produces human-readable
summaries) — dumps are restorable machine-readable archives.

The core problem it solves: there is no single command to snapshot everything in a profile
at once, verify its integrity, and restore from it cleanly.

---

## CLI Shape (rough)

```
ww dumps create  [--name <label>] [--scope <scope>] [--print]    — create snapshot archive
ww dumps list    [--profile <name>]                               — list available snapshots
ww dumps show    <id>                                             — inspect snapshot manifest
ww dumps restore <id>  [--as <new-profile-name>]                 — restore into current or new profile
ww dumps verify  <id>                                            — verify snapshot integrity
ww dumps delete  <id>                                            — remove snapshot (prompts confirm)
```

`--scope`: comma-separated subset or `all` (default):
`tasks`, `time`, `journals`, `ledgers`, `decisions`, `plans`, `tests`, `config`

`--name`: if omitted, interactive prompt asks whether to use the profile name, the date,
or a combined `<profile>-<date>` label (combined offered as default).

`--as <new-profile-name>`: restore dump into a differently-named profile. If target profile
does not exist it is created. If it exists, a pre-restore safety backup is taken first.

`--print` on `create`: print manifest to stdout, do not write archive.

---

## Data Model

Snapshots stored at `profiles/<name>/dumps/YYYY-MM-DD-HH-MM-<scope>.tar.gz` (or `.tar` for
inspection-friendly uncompressed dumps — TBD).

Each snapshot includes a `manifest.json` at archive root:
```json
{
  "profile": "work",
  "created": "2026-04-04T10:00:00Z",
  "scope": ["tasks", "time", "journals"],
  "files": ["..."],
  "checksum": "sha256:..."
}
```

`verify` checks the manifest checksum against current archive contents.
`restore` extracts into profile directory with a pre-restore safety backup.

---

## Dependencies (Tier 1 — no new lib files required)

| Lib | Usage |
|---|---|
| `lib/logging.sh` | All user-facing messages |
| `lib/core-utils.sh` | `ensure_profile_active()` guard |
| `lib/profile-manager.sh` | Profile path resolution for source and restore |

Archive creation via `tar`. Checksum via `sha256sum` / `shasum -a 256` (platform-detected).
Manifest written as JSON via inline `printf` — no `jq` required for generation; `jq` used
for reading if available, `python3 -m json.tool` as fallback.

No new lib files needed at Tier 1.

---

## Relation to Existing Services

- Distinct from `export` service (raw tool data) — dumps are whole-profile archives
- Distinct from `reports` (human summaries) — dumps are restorable machine archives
- `restore` subcommand is separate from profile import/restore in `profile` service —
  dumps restore *data within* a profile, not the profile configuration itself

---

## Open Questions

1. Compressed (`.tar.gz`) vs uncompressed (`.tar`) — default to compressed?

---

## Deferred — Format Review

Additional dump file formats (e.g. zip, sqlite export, JSON bundle) need a separate
review pass before Tier 2. `tar.gz` is the Tier 1 default. Format review should consider
portability, inspectability, and what restore tooling each format requires.

---

## Tier Estimate

Tier 1: create (with `--name` prompt), list, show, restore (with `--as`), verify, delete,
scope selection, manifest + checksum, `.tar.gz` format.
Tier 2: scheduled/automated dumps, dump diffing, additional format support post-review.

---

## Status

ratified — ready for task card when pipeline slot opens
