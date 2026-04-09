# Release checklist — ww vX.Y.Z

Fill in the version, date, and role before checking any item.
Save the completed checklist to `system/reports/releases/vX.Y.Z-checklist.md` before tagging.

Criteria source: `system/reports/production-readiness-rubric.md`

---

Version: _______________
Date: _______________
Checked by: _______________

---

## Criterion 1 — `ww help` clean output

[ ] `ww help` produces no errors, no garbled output, no "command not found" messages | Evidence: ___ | Checked by: Verifier on ___

## Criterion 2 — Every help-listed command responds correctly

[ ] Every command token listed in `ww help` (Commands section) routes to a working handler that exits 0 on `--help` and does not produce an unhandled error | Evidence: ___ | Checked by: Verifier on ___

## Criterion 3 — `ww deps install` succeeds on clean macOS (brew baseline)

[ ] On a macOS system with Homebrew installed, `ww deps install` installs all core tools without error | Evidence: ___ | Checked by: Orchestrator on ___

## Criterion 4 — Extension installs give platform-appropriate guidance on Linux

[ ] On Linux (no brew), `ww tui install` and `ww mcp install` detect the platform, emit the correct install hint, and exit with a non-zero code — no silent failure, no generic "brew not found" message | Evidence: ___ | Checked by: Verifier on ___

## Criterion 5 — Core profile round-trip works

[ ] The sequence `ww profile create <name>` → activate profile → `task add "test task"` → `timew start "test task"` completes without error and data appears in the correct profile directory | Evidence: ___ | Checked by: Verifier on ___

---

## Sign-Off

All five criteria satisfied (evidence gathered + code correct): **YES / NO**

If NO — list blocking items, assign task cards, do not tag:
1.
2.
3.

Orchestrator sign-off: _______________ Date: _______________

---

Completed checklists are saved to system/reports/releases/vX.Y.Z-checklist.md before tagging
