# Standard-vs-Code Divergence Log

Tracks differences found between `ww-standard` (the normative spec) and the actual
codebase at `~/github/workwarrior`. Each entry notes what the standard says, what the
code does, and whether it's a doc fix, a code fix, or a design decision needed.

Generated during popup v2 planning. Feed into a documentation improvement backlog.

---

## Format

```
### [AREA] Short description
Standard says: ...
Code does: ...
Resolution: doc-fix | code-fix | design-decision-needed
Notes: ...
```

---

## Findings

### [TASKS] `task annotations` subcommand does not exist
Standard says: §16 implies annotations are accessible via task commands
Code does: `task <id> annotations` returns nothing (not a valid subcommand). The ONLY way to read annotations is `task <id> export` → parse JSON `annotations` array.
Resolution: doc-fix (standard should document that export is the read path for annotations)
Notes: Browser uses `task <id> export` + JSON parse. This is the proven approach.

### [JRNL] Output always contains ANSI escape codes
Standard says: §6 lists `j [name] "text"` as a shell function. §10 shows `ww journal add` commands.
Code does: `jrnl --short` and `jrnl --format text` both emit ANSI color codes regardless of TERM setting or --format flag. Piping to `cat` doesn't help. Must explicitly strip with `sed 's/\x1b\[[0-9;]*m//g'`.
Resolution: doc-fix (document the ANSI stripping requirement for any non-interactive consumer)
Notes: Browser bypasses jrnl CLI entirely for writes — appends directly to the journal file. This is more reliable for non-interactive contexts.

### [JRNL] Named journal argument position
Standard says: Not documented explicitly.
Code does: `jrnl <journal_name> --config-file <cfg> "text"` — name BEFORE --config-file. This is a jrnl library quirk, not a ww decision.
Resolution: doc-fix (document in ww-standard §10 or a gotchas section)
Notes: Getting this wrong silently creates entries in the wrong journal or errors.

### [JRNL] Browser uses direct file write, not jrnl CLI
Standard says: §10 implies jrnl CLI is the interface.
Code does: Browser's `journal_add` action writes `\n[timestamp] text\n` directly to the file (server.py line ~4717). It does NOT invoke the jrnl binary.
Resolution: design-decision-needed (should the standard document both paths? is direct write the preferred non-interactive approach?)
Notes: Direct write avoids all jrnl CLI quirks (ANSI, interactive prompts, config parsing delays). The popup now uses this approach.

### [LEDGER] `ww ledger` vs hledger direct
Standard says: §10 lists `ww ledger add, list, remove, rename` for named ledger management.
Code does: For actual accounting operations (balance, register, transactions), the browser calls `hledger -f <file>` directly — NOT through `ww ledger`. The `ww ledger` commands manage the *registry* (which ledgers exist), not the *content*.
Resolution: doc-fix (clarify that `ww ledger` manages the namespace while `hledger -f` does the accounting)
Notes: The popup correctly uses `hledger -f` for all read/write operations.

### [LEDGER] Transaction format — source account has no amount
Standard says: Not explicitly documented in the standard.
Code does: Browser's `ledger_add` writes: `\n{date} {desc}\n    {account}  {amount}\n    assets:checking\n` — the second posting has NO amount. hledger auto-balances.
Resolution: doc-fix (document the transaction format explicitly)
Notes: This IS valid double-entry. hledger infers the balancing amount.

### [TIMEW] Quoting behavior for multi-word tags
Standard says: §6 shows `timew [args]` shell function.
Code does: `timew start my activity` creates TWO tags: "my" and "activity". `timew start "my activity"` creates ONE tag: `"my activity"` (with literal quotes in the tag name unless shell strips them). The browser passes `tags.split()` which creates multiple tags.
Resolution: design-decision-needed (should the popup treat typed activity names as single tags or multiple?)
Notes: For the factory floor use case, a single activity name like "lathe-01 setup" should probably be one tag. Current implementation quotes to preserve as single concept.

### [LISTS] Standard doesn't document list.py at all
Standard says: §10 mentions `ww list` briefly in the service registry. No detail on format, subcommands, or data model.
Code does: Full list.py tool with add/finish/edit/remove/grep/new/switch/which/json/print, flat file format with `text | id:hash`, inline notes via ` // `, inline tags via `#word`, timestamps via `[YYYY-MM-DD HH:MM]`.
Resolution: doc-fix (ww-standard needs a full Lists section equivalent to what exists for tasks/time/journal/ledger)
Notes: We created `dev/schemas/list-item-format-v1.md` which documents the format. This should be promoted to ww-standard.

### [STREAM] Standard doesn't have a Stream section
Standard says: No section covers the stream service, lenses, or event format.
Code does: Full stream service exists at `services/stream/stream.sh` with 8 lenses, a 5-field event format (frozen at v1), actor resolution, and the `dev/schemas/stream-event-v1.md` contract.
Resolution: doc-fix (ww-standard needs a Stream section — probably §25 or inserted before Weapons)
Notes: Stream is central to THE PROGRAM (the capture→record→interpret pipeline). Its absence from the standard is a significant gap.

### [PROFILE] `ww profile list` output format varies by mode
Standard says: §5 shows `ww profile list` without specifying output.
Code does: Three modes — default (calls manage-profiles.sh with rich display), `--json` (JSON array of names), `--compact` (bare names one per line). The popup needs bare names.
Resolution: doc-fix (document the --compact/--json modes in standard)
Notes: For the popup, scanning PROFILES_DIR directly is faster and more reliable than parsing ww output.

### [BIN/WW] Standard says "approximately 709 lines"
Standard says: §7 "Approximately 709 lines."
Code does: bin/ww is 223,158 bytes / ~6,457+ lines (massively grown since standard was written).
Resolution: doc-fix (update line count, or remove it — it's not useful information)
Notes: The standard was written when ww was much smaller. Many sections may have stale size/scope claims.

### [HEURISTICS] Engine needs regeneration
Standard says: §12 "627 compiled regex rules across 19 command domains."
Code does: The rules in `config/cmd-heuristics.yaml` were compiled against an earlier CLI surface. New commands (list new/switch/which, stream, etc.) have no heuristic coverage.
Resolution: code-fix (TASK-HEUR-001 covers this)
Notes: Until regenerated, the browser CMD panel will not route natural language for new features.

### [COMMUNITY] Standard doesn't detail community features
Standard says: Not covered in the standard at all.
Code does: Full community system with SQLite database, 12 POST actions (add, create, archive, unarchive, describe, rename, modify_entry, refresh_entry, move_entry, remove_entry, comment_save, comment_copy_back). CLI: `ww community list/create/show/add`.
Resolution: doc-fix (needs its own section in ww-standard)
Notes: Community is a shipped feature with significant browser UI integration.

### [DEV-SYNC] Script excluded tools/ directory
Standard says: Not covered (dev-sync is a dev tool).
Code does: `dev/scripts/dev-sync.sh` excluded `tools/` from sync, treating it as "installed extensions." But `tools/list/list.py` is a program file that needs syncing.
Resolution: code-fix (already fixed this session — tools/ is now included in sync)
Notes: The exclusion was likely from when `tools/` also held user-installed extensions alongside the bundled list tool.

### [POPUP] Not in standard at all (new capability)
Standard says: No popup/launcher concept exists.
Code does: Full popup system at `scripts/ww-floor-popup.sh` + `scripts/ww-popup-screens/` with 14 screen modules.
Resolution: doc-fix (needs a new section in ww-standard when stabilized)
Notes: This is a new primary interface layer. Once v2.1 stabilizes, it warrants its own standard section.


### [SYNC] sync.sh rewritten — now uses instance registry and rsync
Standard says: Not covered (sync is a dev/ops tool).
Code does: `sync.sh` was a simple `cp -r` script. Now rewritten to use instance registry discovery (`~/.config/ww/registry/*.json`), rsync with `--delete`, hidden instance filtering, `--service` for per-service sync, and `--include-dev`/`--include-docs` opt-in flags. `dev/scripts/dev-sync.sh` also gained `--service` support.
Resolution: doc-fix (document sync.sh in ww-standard operations/admin section or in INSTALL.md)
Notes: sync.sh is now the canonical sync tool. dev-sync.sh remains for divergent dev workflows if needed. The instance registry integration means the sync tool respects visibility settings.

### [POPUP] Home screen changed from 3-page to single page
Standard says: `dev/specs/2026-07-14-popup-v2-design.md` specifies 3 pages with arrow navigation.
Code does: `ww-popup-screens/home.sh` now shows all 12 menu items on a single screen with separator-based visual grouping (daily / data / system). No page navigation.
Resolution: doc-fix (update popup-v2-design.md §2 to reflect single-page layout)
Notes: Simplification — pagination added complexity without clear UX benefit for 12 items.
