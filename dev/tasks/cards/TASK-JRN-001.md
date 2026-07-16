## TASK-JRN-001: Eliminate the code-injection hole in bin/ww's python heredocs

Goal:                 `ww journal write --journal <name>` interpolates the user's value straight
                      into Python SOURCE via an unquoted heredoc. Arbitrary Python then executes
                      as the user. Close it, and close every instance of the pattern.

                      REPRODUCED (harmless marker, 2026-07-13):
                        ww_journal='x"; open("PWNED","w").write("..."); y="'
                        python3 - <<PYEOF
                        journal_name = "${ww_journal}"
                        PYEOF
                      -> file written. Arbitrary code executed.

                      This is a shipped CLI. It outranks the Phase 0 board.

Depends on:           — (jumps the queue; see Risk notes)

Source:               dev/reports/journal-jrnl/audit-2026-07-13.md

The bug:              A heredoc with an UNQUOTED delimiter (`<<PYEOF`) is expanded by the shell
                      BEFORE python sees it. Any `${var}` inside becomes part of the program text.
                      A quoted delimiter (`<<'PYEOF'`) is not expanded and is safe.

                      5 unquoted sites in bin/ww; 4 interpolate a value:
                        ~3561  d = json.loads('''$result''')      <- journal CONTENT (user data)
                        ~3641  journal_name = "${ww_journal}"     <- --journal flag  (PROVEN)
                        ~3666  journal_key  = "${resolved_journal}"
                        ~3755  journal_name = "${jt_journal}"
                        ~4009  (no vars — but the delimiter is unquoted: a latent trap for the
                               next person to add one)

Acceptance criteria:  1. EVERY `python3 - <<DELIM` in bin/ww uses a QUOTED delimiter (`<<'DELIM'`).
                         Zero unquoted python heredocs remain. Grep-assert it.
                      2. Values reach python as DATA, never as source text:
                         - scalars via `sys.argv` (`python3 - "$val" <<'EOF'`)
                         - large/structured payloads via the ENVIRONMENT (`VAR=... python3 - <<'EOF'`)
                         Never by string interpolation into the program.
                      3. A journal name containing `"`, `'`, `;`, `$(...)`, backticks or a newline
                         is treated as a (probably invalid) NAME — never as code. Test each.
                      4. The exploit above no longer executes. Regression test with the exact
                         payload; it must fail closed.
                      5. Behaviour is otherwise UNCHANGED: existing journal write/list/task flows
                         still resolve the same target files. The 5 journal suites (88 tests) stay
                         green.
                      6. NOT IN SCOPE: the silent-fallback bugs in the same blocks
                         (a failed resolution silently redirects to default.txt). Those corrupt the
                         record without saying so and are real — but they are a BEHAVIOUR change,
                         not a security fix, and they get their own card (TASK-JRN-003) so this one
                         can land fast and be reasoned about narrowly.

Write scope:          bin/ww                              (SERIALIZED — no other task may hold it)
                      dev/tests/test-journal-injection.bats  (new)

Tests required:       bats dev/tests/test-journal-injection.bats
                      bats dev/tests/test-journal*.bats     (the 5 existing suites, 88 tests)
                      bash dev/scripts/check-regression.sh  (no new failures vs known-failures.txt)

Rollback:             git revert. Pure refactor of how values cross the shell/python boundary.

Fragility:            bin/ww is SERIALIZED. This must not run concurrently with any other task
                      touching it (LED-013 held it; LED-013 is now MERGED, so the file is free).

Risk notes:           (Orchestrator) This jumps Phase 0. A reproduced arbitrary-code-execution path
                      in a shipped CLI outranks version floors and actor axes. The audit's sharpest
                      finding is why it survived: the 5 dedicated journal suites are 88/88 GREEN
                      while the service has an injection hole — 88 tests protecting the paths nobody
                      was worried about. Green tests told us nothing, because nothing told us what
                      the tests COVER.
                      (Builder) Fix the PATTERN, not the 5 instances. Any new `python3 - <<EOF`
                      without quotes is the same bug again; criterion 1 is a grep gate so it cannot
                      silently return.

Resolution:
  Implemented 2026-07-13. All 5 heredocs now use quoted delimiters. Values cross the
  boundary as DATA: `--journal` and friends via sys.argv; the scanner's JSON payload via the
  environment. Added dev/tests/test-journal-injection.bats, which fires the exact proven
  payload (plus quote/semicolon/backtick/newline/command-substitution variants) and asserts
  no execution and no file written.
  Verified: injection suite green; the 5 journal suites still 88/88; check-regression.sh
  clean against the committed baseline.

Status:               complete
Taskwarrior:          (assign live TW id on dispatch)
