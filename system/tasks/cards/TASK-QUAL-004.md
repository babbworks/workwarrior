## TASK-QUAL-004: Fix filter_system_tags() jq iterator bug in field-mapper.sh

Goal:                 filter_system_tags() builds its jq filter using `. |` instead of
                      `.[] |`, so it operates on the whole input array rather than
                      its elements and never removes any system tags. Discovered during
                      TASK-SYNC-005; worked around inline in _sync_tags_to_task().

Acceptance criteria:  1. filter_system_tags() correctly removes SYSTEM_TAGS members and
                         sync:* tags from a JSON array input.
                      2. map_tags_to_labels() (the other caller) produces correct output —
                         system tags no longer leak into GitHub label pushes.
                      3. _sync_tags_to_task() in sync-pull.sh updated to call
                         filter_system_tags() instead of its inline workaround.
                      4. New BATS tests cover: system tag removed, non-system tag preserved,
                         empty input returns empty array, sync:* tag removed.
                      5. All currently passing tests remain passing (no regressions).

Write scope:          /Users/mp/ww/lib/field-mapper.sh
                      /Users/mp/ww/lib/sync-pull.sh
                      /Users/mp/ww/tests/test-github-sync.bats

Tests required:       bats tests/test-github-sync.bats
                      bats tests/

Rollback:             git checkout /Users/mp/ww/lib/field-mapper.sh /Users/mp/ww/lib/sync-pull.sh /Users/mp/ww/tests/test-github-sync.bats

Fragility:            HIGH FRAGILITY: field-mapper.sh (sync correctness layer), sync-pull.sh

Risk notes:           All callers of filter_system_tags() must be audited before changing it.
                      Current callers: map_tags_to_labels() in field-mapper.sh,
                      _sync_tags_to_task() in sync-pull.sh (inline workaround added SYNC-005).
                      The existing bug means system tags were also leaking into push label
                      sync via map_tags_to_labels() — verify push behaviour after fix.
                      Depends on SYNC-005 (complete).

Status:               complete
