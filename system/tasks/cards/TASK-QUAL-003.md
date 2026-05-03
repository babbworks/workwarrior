## TASK-QUAL-003: Audit and clean functions/ directory dead code

Goal:                 Explorer B found functions/issues/taskwarriortogithubissue.sh is unreferenced
                      anywhere in the codebase. The functions/ directory as a whole has unclear
                      provenance — it may be entirely legacy from a pre-lib/ architecture.

Acceptance criteria:  1. Every script in functions/ is traced: is it sourced, called, or tested by
                         anything active in bin/, lib/, services/, or shell-integration.sh?
                      2. Unreferenced scripts are removed.
                      3. Referenced scripts are documented — either folded into lib/ or noted as
                         intentionally separate with a comment explaining why.
                      4. After cleanup, no file in functions/ is a Gate E violation (unexplained TODO).

Write scope:          /Users/mp/ww/functions/  (audit and delete only — no new code)

Tests required:       bats tests/
                      Manual: confirm ww and shell aliases still work after any deletions

Rollback:             git checkout functions/ (restores deleted files)

Fragility:            None — deletions only; if anything breaks, git checkout restores it.

Risk notes:           Explorer B: functions/issues/taskwarriortogithubissue.sh confirmed unreferenced.
                        functions/journals/, ledgers/, tasks/, times/ status unknown.
                      Do not delete without tracing first.

Resolution:
  Traced all scripts in functions/ against active code (bin/, lib/, services/):
  - functions/tasks/default-taskrc/.taskrc: REFERENCED — kept (DEFAULT_TASKRC in core-utils.sh,
    and in services/profile/*.sh)
  - 8 unreferenced scripts removed:
      functions/issues/taskwarriortogithubissue.sh
      functions/journals/scripts/add_journal.sh
      functions/journals/scripts/select_journal.sh
      functions/ledgers/hledger/hledger-incomeexpensereport-1.sh
      functions/ledgers/scripts/add_ledger.sh
      functions/ledgers/scripts/select_ledger.sh
      functions/todos/scripts/add-todo-lists.sh
      functions/tasks/extensions/tasksh
  - Non-script data files (journal text files, old task database, CONFIG, sublime-projects)
    left in place — these are not scripts per task scope. The functions/tasks/workwarrior/
    directory contains old task database artifacts (SQLite, data files); these should be
    reviewed for gitignore policy separately (TASK-QUAL-004 if needed).
  No Gate E violations remain in functions/ (no shell scripts with unexplained TODOs).

Status:               complete
