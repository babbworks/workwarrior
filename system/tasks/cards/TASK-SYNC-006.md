## TASK-SYNC-006: Extended label encoding for categorical UDA ↔ GitHub label sync

Goal:                 The current label sync only handles priority and generic tag pass-through.
                      Extend it to support namespaced labels (`key:value`) that map
                      bidirectionally to specific TaskWarrior UDAs, enabling categorical
                      fields like type, phase, scope, and stack to round-trip through GitHub.

Acceptance criteria:  1. A label-UDA map is defined in system/config/label-uda-map.yaml
                         specifying which UDAs participate in label encoding and their
                         GitHub label prefix (e.g. type:, phase:, scope:, stack:).
                      2. map_uda_to_labels() added to field-mapper.sh: serialises
                         participating UDA values as `<prefix>:<value>` labels on push.
                      3. map_labels_to_udas() added to field-mapper.sh: parses
                         `<prefix>:<value>` labels on pull and writes matching UDAs.
                      4. sync-push.sh calls map_uda_to_labels() and adds encoded labels
                         alongside the existing priority and tag labels.
                      5. sync-pull.sh calls map_labels_to_udas() after existing label
                         processing; does not overwrite UDAs already set locally unless
                         GitHub value differs.
                      6. Existing priority label behaviour is unchanged.
                      7. BATS tests cover: UDA serialised to label on push, label parsed
                         to UDA on pull, unknown prefix ignored gracefully, empty UDA
                         removes label.

Write scope:          /Users/mp/ww/system/config/label-uda-map.yaml  (new)
                      /Users/mp/ww/lib/field-mapper.sh
                      /Users/mp/ww/lib/sync-push.sh
                      /Users/mp/ww/lib/sync-pull.sh
                      /Users/mp/ww/tests/test-github-sync.bats

Tests required:       bats tests/test-github-sync.bats
                      bats tests/

Rollback:             git checkout /Users/mp/ww/lib/field-mapper.sh \
                        /Users/mp/ww/lib/sync-push.sh \
                        /Users/mp/ww/lib/sync-pull.sh \
                        /Users/mp/ww/tests/test-github-sync.bats
                      rm /Users/mp/ww/system/config/label-uda-map.yaml

Fragility:            HIGH FRAGILITY: field-mapper.sh, sync-push.sh, sync-pull.sh

Risk notes:           Labels are repo-global — every encoded label (`scope:large`) is
                      visible to all collaborators. Choose prefixes carefully; avoid
                      leaking internal project jargon into public repos.
                      Multi-value UDAs (e.g. stack:nodejs,python) need a clear
                      serialisation strategy — recommend one label per value.
                      Depends on TASK-QUAL-004 (filter_system_tags fix) completing first.

Status:               pending
