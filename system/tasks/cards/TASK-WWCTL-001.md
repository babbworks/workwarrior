## TASK-WWCTL-001: Expand wwctl — Tier 1, 2, and 3 management commands

Goal:                 Transform wwctl from a 6-command task-lifecycle tool into a
                      full instance management CLI covering documentation staleness,
                      codebase health, Gate automation, profile diagnostics, and
                      agent session orientation.

Acceptance criteria:
  Tier 1 — Natural extensions:
  1. wwctl docs-check
       Reads docs/overviews/source-map.yaml. For each overview doc, compares
       last git commit date of listed source files against last git commit date
       of the doc itself. Reports STALE / CURRENT / UNMAPPED per doc.
       Exit non-zero if any STALE docs found.

  2. wwctl select-tests <type> [--run]
       Thin wrapper around system/scripts/select-tests.sh. Surfaces it as a
       first-class wwctl command. All existing behaviour preserved.

  3. wwctl task-status
       Focused task board view: pending/in-progress/blocked/in-review cards
       with write scope and fragility flags. Separate from wwctl status output.

  4. wwctl decisions [--last <n>]
       Prints last N entries from system/logs/decisions.md (default: 5).
       Each entry: date header + decision line only (not full body).

  Tier 2 — New capability:
  5. wwctl health
       Composite health check:
       - BATS test baseline (pass count vs known baseline in config/test-baseline.yaml)
       - Gate E scan (untracked TODOs in production paths via git diff HEAD)
       - Artifact hygiene (.DS_Store, .sqlite3 tracked in git)
       - wwctl docs-check summary (stale doc count)
       - Active worktrees with age in days
       Single PASS/WARN/FAIL per section. Overall status line at end.

  6. wwctl log "<message>"
       Appends a timestamped entry to system/logs/decisions.md in standard format:
       ## <YYYY-MM-DD> — <message>
       **Decision:** (blank — for agent to fill)
       Prints confirmation of append.

  7. wwctl worktrees [clean]
       Bare: lists active worktrees with role, topic, age (days since creation),
       and whether they have uncommitted changes.
       clean: removes worktrees whose branches have been merged into master.

  8. wwctl todo-scan
       Scans lib/, services/, bin/ for TODO/FIXME/HACK/XXX/PLACEHOLDER.
       Cross-references each against TASKS.md task cards.
       Reports: tracked (has card ID in comment), untracked (Gate E violation),
       orphaned (card exists but is complete). Exit non-zero if any untracked.

  Tier 3 — Significant new capability:
  9. wwctl profile-health [<profile>]
       Checks health of a ww profile (data integrity, not codebase):
       - TaskWarrior: pending count, overdue count, sync state file integrity
       - TimeWarrior: last entry date, any open tracking sessions
       - GitHub sync: last sync time, orphaned state entries, pending changes
       - Journals: last entry date
       - Ledger: last transaction date
       Defaults to active profile if none specified.

  10. wwctl release-check
       Automates Gate D. Checks:
       - All tasks in dispatch queue are complete
       - No untracked TODOs (calls todo-scan)
       - No stale overview docs (calls docs-check)
       - BATS baseline passes
       - .gitignore covers all artifact patterns
       Produces a signed checklist output. Exit non-zero if any criterion fails.

  11. wwctl diff-summary [<git-range>]
       Given a git range (default: last merge commit to HEAD), produces:
       - Source files changed
       - Task cards affected (by write scope cross-reference)
       - Overview docs potentially stale (from source-map.yaml)
       - Required test suite (from select-tests.sh change type detection)
       Useful for understanding what another agent session did.

  Supporting artifact:
  12. docs/overviews/source-map.yaml
       Mapping of overview doc path → source files it covers.
       Used by docs-check and diff-summary.

  13. Changelog section added to all existing overview docs
       Each doc gets ## Changelog with initial entry dated today.
       docs-check uses the last changelog date as the doc's "last updated" signal.

  14. wwctl usage updated with all new commands and examples.

Write scope:          /Users/mp/ww/system/bin/wwctl
                      /Users/mp/ww/system/scripts/docs-check.sh       (new)
                      /Users/mp/ww/system/scripts/health.sh            (new)
                      /Users/mp/ww/system/scripts/todo-scan.sh         (new)
                      /Users/mp/ww/system/scripts/profile-health.sh    (new)
                      /Users/mp/ww/system/scripts/release-check.sh     (new)
                      /Users/mp/ww/system/scripts/diff-summary.sh      (new)
                      /Users/mp/ww/docs/overviews/source-map.yaml      (new)
                      /Users/mp/ww/docs/overviews/INDEX.md             (changelog)
                      /Users/mp/ww/docs/overviews/bin/*.md             (changelogs)
                      /Users/mp/ww/docs/overviews/lib/*.md             (changelogs)
                      /Users/mp/ww/docs/overviews/services/**/*.md     (changelogs)
                      /Users/mp/ww/docs/overviews/cross-cutting/**/*.md (changelogs)

Tests required:       bats tests/
                      Manual: wwctl health; wwctl docs-check; wwctl todo-scan
                      Manual: wwctl profile-health; wwctl release-check
                      Manual: wwctl diff-summary; wwctl worktrees

Rollback:             git checkout /Users/mp/ww/system/bin/wwctl
                      git rm system/scripts/docs-check.sh health.sh todo-scan.sh
                      git rm system/scripts/profile-health.sh release-check.sh diff-summary.sh
                      git checkout docs/overviews/

Fragility:            None — system/ only, no production code touched

Risk notes:           All new scripts are additive. wwctl is in system/ not bin/ww
                      (not SERIALIZED). No lib/ or services/ files touched.
                      profile-health reads profile data read-only — no writes.
                      todo-scan and docs-check are read-only git operations.

Status:               pending
