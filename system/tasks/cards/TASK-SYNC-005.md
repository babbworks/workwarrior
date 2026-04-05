## TASK-SYNC-005: Implement GitHub label → TaskWarrior tag sync in sync-pull

Goal:                 sync-pull.sh currently skips tag sync during pull. GitHub labels are not
                      mapped to TaskWarrior tags. This limits round-trip fidelity for label-heavy
                      GitHub workflows.

Acceptance criteria:  1. Labels from GitHub issue are mapped to TaskWarrior tags on pull.
                      2. Non-system TaskWarrior tags (not in SYSTEM_TAGS from field-mapper.sh)
                         are removed and replaced with the GitHub label set.
                      3. System tags (ACTIVE, READY, PENDING, etc.) are never modified by sync.
                      4. Tests in tests/test-github-sync.bats cover: label-to-tag mapping,
                         system tag preservation, empty label set (clears non-system tags),
                         tag deduplication.
                      5. TODO comment at sync-pull.sh is replaced with the implementation.

Write scope:          /Users/mp/ww/lib/sync-pull.sh
                      /Users/mp/ww/tests/test-github-sync.bats

Tests required:       bats tests/test-github-sync.bats
                      bats tests/

Rollback:             git checkout /Users/mp/ww/lib/sync-pull.sh

Fragility:            HIGH FRAGILITY: lib/sync-pull.sh

Risk notes:           Must not modify system tags. Consult SYSTEM_TAGS in field-mapper.sh.
                      Non-destructive pull: only update tags if they differ from current state.
                      Requires mocked tw_update_task / task CLI in tests.

Status:               pending
