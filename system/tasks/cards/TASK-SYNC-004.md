## TASK-SYNC-004: Resolve tag sync TODO (Gate E)

Goal:                 lib/sync-pull.sh:100 contains `# TODO: Implement proper tag sync` with no
                      corresponding TASKS.md card. Gate E violation. Decide and act.

Acceptance criteria:  Either:
                      A. Implement tag sync — pull GitHub labels into TaskWarrior tags:
                         1. Label → tag mapping logic in sync-pull.sh
                         2. Tests covering label sync in test-github-sync.bats
                         3. TODO comment removed
                      Or:
                      B. Explicitly defer — remove the TODO comment, add deferred note in
                         TASKS.md backlog, document why it's out of scope.

Write scope:          /Users/mp/ww/lib/sync-pull.sh
                      (if option A: /Users/mp/ww/tests/test-github-sync.bats)

Tests required:       bats tests/
                      (if option A: bats tests/test-github-sync.bats)

Rollback:             git checkout /Users/mp/ww/lib/sync-pull.sh

Fragility:            HIGH FRAGILITY: lib/sync-pull.sh

Risk notes:           Gate E: every TODO in production code needs a TASKS.md card or must be removed.
                      Explorer A source: lib/sync-pull.sh:100.
                      Recommend option B unless tag sync is in active roadmap.

Resolution:           Option B — explicit defer.
  Removed TODO comment from lib/sync-pull.sh:100.
  Replaced with: "Tag sync: explicitly deferred (TASK-SYNC-005)."
  TASK-SYNC-005 card created and added to TASKS.md backlog.
  Gate E violation cleared.

Status:               complete
