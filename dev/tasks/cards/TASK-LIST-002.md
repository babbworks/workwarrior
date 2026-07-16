## TASK-LIST-002: List service CLI — tags, notes visibility, and export

Goal:                 Add inline tag filtering, note display, cross-list discovery, and
                      clean export to the List CLI — making lists useful as knowledge
                      scratchpads, not just quick-capture todo boards.

Depends on:           TASK-LIST-001 (multi-list management must exist for cross-list ops)

Design context:       The browser already uses ` // ` (space-slash-slash-space) as the
                      inline note separator appended to item text. It also parses optional
                      leading `[YYYY-MM-DD HH:MM]` timestamps. Tags (`#word` in item text)
                      are new — neither CLI nor browser parse them yet. See
                      `dev/schemas/list-item-format-v1.md` for the format spec.

Acceptance criteria:  1. INLINE TAGS
                         a. Tags are `#word` tokens (alphanumeric + hyphen) anywhere in
                            the item text body (before the ` // ` note separator if present).
                            They are parsed on read, not stored as separate metadata.
                         b. `list #tag` filters items on the current list to those
                            containing `#tag` (shorthand for `list -g '#tag'`).
                         c. `lists #tag` searches across ALL lists in the profile,
                            printing matches grouped by list name with headers.

                      2. NOTES VISIBILITY
                         a. `list -n` / `list --notes` displays items with their inline
                            notes shown on a second line (indented, prefixed with `↳`).
                            Items without notes display normally.
                         b. `lists -n` / `lists --notes` shows ALL annotated items across
                            all lists in the profile, grouped by list name.
                         c. The ` // ` separator convention is respected exactly as the
                            browser uses it. No alternate format.

                      3. EXPORT
                         a. `list --json` outputs current list as JSON array of objects:
                            `[{id, prefix, text, body, tags:[], note, done:bool}]`
                            where `body` is the text without timestamp/note, `tags` are
                            extracted `#word` tokens, `note` is post-` // ` content.
                         b. `list --print` outputs clean text — no IDs, no metadata
                            suffix — one item per line, suitable for piping or printing.
                         c. `lists --export json` outputs all lists in the profile as a
                            JSON object keyed by list name, each value an array per 3a.

                      4. TIMESTAMP AWARENESS
                         a. Items with leading `[YYYY-MM-DD HH:MM]` or `[YYYY-MM-DD]`
                            timestamps: the timestamp is parsed and available in JSON
                            output as an `added` field. Display is unchanged (timestamp
                            remains part of the visible text in normal mode).

                      5. FORMAT INTEGRITY
                         a. All features read/write the same flat-file format the browser
                            uses. `dev/schemas/list-item-format-v1.md` is normative.
                         b. Items added via CLI are correctly displayed in browser and
                            vice versa.
                         c. `cat <listfile>` remains human-readable.

Write scope:          tools/list/list.py                         (extend)
                      dev/tests/test-list-service.bats           (extend, new cases)

Tests required:       bats dev/tests/test-smoke.bats
                      bats dev/tests/test-list-service.bats
                      bats dev/tests/
                      Manual: add item with note in browser, verify `list -n` shows it
                      Manual: add item with #tag via CLI, verify browser renders it

Rollback:             git checkout tools/list/list.py
                      (test file additions are safe to leave)

Fragility:            None. tools/list/list.py is the only production file touched.

Risk notes:           (Orchestrator) The ` // ` separator lives INSIDE the `text` field
                      of the existing format (`text | id:hash`). The note is part of the
                      text as far as list.py's parser is concerned. The split is purely a
                      display/query concern — it does NOT alter how items are stored.
                      Tags similarly live in the text body — no format change needed.
                      The --json flag must NOT conflict with ww's own --json convention
                      at the passthrough layer. Verify cmd_list_passthrough passes it
                      through to list.py cleanly.
                      Browser implications (rendering #tags, etc.) are OUT OF SCOPE —
                      separate card.

Status:               pending
Taskwarrior:          (assign live TW id on dispatch)
