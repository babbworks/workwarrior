## TASK-STRUCT-3: Relocate 9 empty service stubs to dev/specs/service-designs/

Goal:                 Remove newcomer-facing clutter (empty service categories that look
                      unfinished) while KEEPING their design intent, by moving stub overview
                      docs into a consolidated design home and deleting the empty dirs.

Depends on:           TASK-STRUCT-1B (dev/ must exist as the relocation target)

Acceptance criteria:  1. For each of the 9 stub categories — base, diagnostic, help, kompare,
                         open, unique, verify, you, z-default — its service-overview.md (and
                         README.md content, merged if useful) is moved to
                         dev/specs/service-designs/<name>.md (content preserved, nothing lost).
                      2. The 9 now-empty services/<name>/ directories are removed.
                      3. services/scripts/ and services/cmd/ are UNTOUCHED (scripts/ has real
                         journals/ + tasks/ content; cmd/ backs the core `ww cmd` NL feature).
                      4. `bats tests/test-service-discovery.bats` and
                         `bash tests/test-service-discovery.sh` pass (discovery no longer lists
                         the 9 removed categories; no executable was lost — all 9 had zero).
                      5. `ww service list` output no longer shows the 9 empty categories.

Write scope:          dev/specs/service-designs/base.md          (new; from services/base/)
                      dev/specs/service-designs/diagnostic.md
                      dev/specs/service-designs/help.md
                      dev/specs/service-designs/kompare.md
                      dev/specs/service-designs/open.md
                      dev/specs/service-designs/unique.md
                      dev/specs/service-designs/verify.md
                      dev/specs/service-designs/you.md
                      dev/specs/service-designs/z-default.md
                      services/{base,diagnostic,help,kompare,open,unique,verify,you,z-default}/
                        (directory removals)

Tests required:       bats tests/test-service-discovery.bats
                      bash tests/test-service-discovery.sh
                      bats tests/
                      Manual: `ww service list` shows no empty categories

Rollback:             git mv the 9 design docs back to their services/<name>/ overview paths
                      and restore the dirs (git checkout of the removed paths).

Fragility:            None. Low risk. But CONFIRM before deleting each dir that it contains
                      zero executables and is referenced nowhere in bin/ww (grep per name).

Risk notes:           (Orchestrator) All 9 confirmed exec:0 in the restructure audit. z-default
                      "z-" prefix is only sort-ordering, not a coded discovery fallback
                      (verified: no z-default reference in bin/ww). scripts/ and cmd/ HELD OUT
                      deliberately. If a discovery test hardcodes a count of categories, update
                      the expected count in the same change.

Status:               pending
Taskwarrior:          (assign live TW id on dispatch) status:pending
