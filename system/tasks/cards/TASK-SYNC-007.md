## TASK-SYNC-007: Issue body YAML block for rich UDA ↔ GitHub sync

Goal:                 Rich TaskWarrior UDAs (goals, deliverables, scope description,
                      risks, stack, etc.) have no path to GitHub today. Encode a
                      selected subset as a fenced YAML block in the GitHub issue body,
                      enabling round-trip sync of structured metadata without requiring
                      the GitHub Projects API.

Acceptance criteria:  1. A UDA-to-body map is defined in system/config/body-uda-map.yaml
                         listing which UDAs participate in body sync and their display labels.
                         Only fields in this list are written; the rest of the issue body
                         is never touched.
                      2. serialize_udas_to_body_block() added to field-mapper.sh:
                         produces a fenced YAML block:
                           <!-- ww-metadata -->
                           ```yaml
                           goals: "..."
                           deliverables: "..."
                           stack: "..."
                           ```
                           <!-- /ww-metadata -->
                      3. parse_body_block_to_udas() added to field-mapper.sh:
                         extracts the ww-metadata block from issue body and returns
                         key:value pairs. Returns empty output if block absent (not an error).
                      4. sync-push.sh: on push, read current issue body, replace or append
                         the ww-metadata block, write back via github_update_issue_body().
                      5. sync-pull.sh: on pull, parse ww-metadata block from fetched body
                         and update participating UDAs. Non-participating body content ignored.
                      6. Round-trip fidelity: a push followed by a pull produces identical
                         UDA values. Existing issue body content outside the block is
                         preserved exactly.
                      7. If all participating UDAs are empty, block is omitted (not written
                         as an empty YAML block).
                      8. BATS tests cover: block serialised correctly, block parsed correctly,
                         missing block returns empty (not error), existing body content
                         preserved, empty UDAs omit block, round-trip fidelity.

Write scope:          /Users/mp/ww/system/config/body-uda-map.yaml  (new)
                      /Users/mp/ww/lib/field-mapper.sh
                      /Users/mp/ww/lib/github-api.sh  (add github_update_issue_body())
                      /Users/mp/ww/lib/sync-push.sh
                      /Users/mp/ww/lib/sync-pull.sh
                      /Users/mp/ww/tests/test-github-sync.bats

Tests required:       bats tests/test-github-sync.bats
                      bats tests/

Rollback:             git checkout /Users/mp/ww/lib/field-mapper.sh \
                        /Users/mp/ww/lib/github-api.sh \
                        /Users/mp/ww/lib/sync-push.sh \
                        /Users/mp/ww/lib/sync-pull.sh \
                        /Users/mp/ww/tests/test-github-sync.bats
                      rm /Users/mp/ww/system/config/body-uda-map.yaml

Fragility:            HIGH FRAGILITY: field-mapper.sh, github-api.sh, sync-push.sh,
                      sync-pull.sh. Writing to issue body is an irreversible side effect
                      on the remote — test on a private/test repo before running on
                      production repos.

Risk notes:           Issue body writes go to GitHub — cannot be rolled back automatically.
                      Use a test repo (babbworks/claude-tests) for initial validation.
                      The ww-metadata block must use HTML comment fences to survive
                      GitHub's markdown rendering pipeline without visual clutter.
                      Serialisation of multi-line UDA values needs careful YAML quoting.
                      Depends on TASK-SYNC-006 completing first (shared field-mapper changes).

Status:               complete
