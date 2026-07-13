## TASK-JRN-003: Silent failures that corrupt the journal record without saying so

Goal:                 Two code paths swallow an exception and then LIE about it. Both put the
                      user's data somewhere other than where they asked, and both report success.
                      Replace them with typed, loud errors.

                      Scoped OUT of TASK-JRN-001 deliberately: that card was a SECURITY fix and
                      landed narrow and fast. These are BEHAVIOUR changes and deserve their own
                      review.

Depends on:           TASK-JRN-001 (merged — do not conflict on the same bin/ww blocks)

Source:               dev/reports/journal-jrnl/audit-2026-07-13.md

The two bugs:
  1. bin/ww — journal resolution. `except Exception: print(.../journals/default.txt)`.
     You run `ww journal write --journal work`, the resolution throws for ANY reason (bad
     jrnl.yaml, missing key, typo'd name), and your entry is silently filed into default.txt.
     No warning. You believe it is in `work`. It is not. **The record is now wrong and nothing
     said so.**

  2. services/browser/server.py:2003 — `except Exception: pass`, then falls through to a
     LOSSIER parser that drops every annotation, while still answering `200 {"ok": true}`.
     The browser renders a journal that looks complete and has quietly lost data. That
     endpoint is currently FAILING in the suite, which is how it was found.

Acceptance criteria:  1. A journal name that does not resolve is a USER ERROR (exit 1) with a
                         message naming the journal and listing the valid ones. It MUST NOT
                         silently redirect to default.txt.
                      2. A malformed jrnl.yaml is a SYSTEM ERROR (exit 2), not a fallback.
                      3. server.py's parse failure returns a non-2xx with a typed error body.
                         It must never answer `ok: true` after losing data.
                      4. If a lossy fallback parser is genuinely wanted, it must be OPT-IN and
                         must report what it dropped. Silently dropping annotations is not a
                         degraded mode, it is data loss.
                      5. Tests: each failure mode asserts the exit code AND that no entry was
                         written to the wrong file.
                      6. Grep gate: no bare `except Exception: pass` and no `except Exception:`
                         followed by a silent default in the journal paths.

Write scope:          bin/ww                                  (SERIALIZED)
                      services/browser/server.py
                      dev/tests/test-journal-errors.bats      (new)

Tests required:       bats dev/tests/test-journal-errors.bats
                      bats dev/tests/test-journal-*.bats
                      bash dev/scripts/check-regression.sh

Rollback:             git revert. Note this CHANGES BEHAVIOUR — commands that used to "succeed"
                      by writing to the wrong file will now fail. That is the point.

Fragility:            MEDIUM. bin/ww is SERIALIZED. Changing success into failure is
                      user-visible; the errors must be excellent, not merely correct.

Risk notes:           (Orchestrator) The audit's framing is right and worth keeping: a system
                      that silently files your entry in the wrong journal has corrupted the
                      record, and the whole value of a plain-text journal is that it is
                      trustworthy. This is the same discipline the ledger enforces — corrections
                      are entries, never erasures; and nothing fabricates a result to look tidy.

Status:               pending
Taskwarrior:          (assign live TW id on dispatch)
