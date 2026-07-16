## TASK-STRUCT-1B: Rename system/ -> dev/, move tests/ -> dev/tests/, stop shipping dev/

Goal:                 Establish the product-vs-meta boundary: rename the dev control plane
                      system/ -> dev/, relocate tests/ -> dev/tests/, repoint every
                      reference, and remove dev/ from the installer (safe now that 1A moved
                      runtime config into config/).

Depends on:           TASK-STRUCT-1A (runtime config must be decoupled first)

Acceptance criteria:  1. `git mv system dev` and `git mv tests dev/tests` (history preserved).
                      2. bin/ww-init.sh PATH inject points at dev/bin (was system/bin), with
                         the `[[ -d ]]` guard retained.
                      3. install.sh no longer copies system/ or tests/ (line ~340 step removed);
                         install summary text (line ~750) updated to drop the "system/" line.
                      4. All 29 external references to `system/` (root CLAUDE.md, .gitignore,
                         .claude/ww/ww-agent-guidance.md, lib/CLAUDE.md, weapons/gun/README.md,
                         the 4 service-overview stubs, non-site doc refs) now say `dev/`.
                      5. Internal self-references inside dev/ updated system/ -> dev/.
                      6. `git grep -nE '(^|[^a-z/])system/'` returns only intentional
                         historical/archive prose (no live path references outside dev/).
                      7. dev/scripts/select-tests.sh and .claude/settings.local.json reference
                         dev/tests (not tests/).
                      8. Fresh scratch install (`WW_INSTALL_DIR=/tmp/ww-scratch ./install.sh
                         --force`) runs WITHOUT dev/ present: `ww help`, `ww profile list`,
                         `ww profile uda list`, and a github-sync dry-run all succeed.
                      9. `dev/bin/wwctl status` runs from the repo.
                      10. Full suite `bats dev/tests/` at/above baseline.

Write scope:          (rename) system/ -> dev/     [git mv, all files]
                      (rename) tests/ -> dev/tests/ [git mv, all files]
                      bin/ww-init.sh
                      install.sh
                      CLAUDE.md
                      .gitignore
                      .claude/ww/ww-agent-guidance.md
                      .claude/settings.local.json
                      lib/CLAUDE.md
                      weapons/gun/README.md
                      services/base/service-overview.md
                      services/diagnostic/service-overview.md
                      services/help/service-overview.md
                      services/verify/service-overview.md
                      (+ dev/-internal self-references — mechanical, within the renamed tree)

Tests required:       bats dev/tests/                       (full suite, post-rename path)
                      bash dev/tests/run-integration-tests.sh
                      Manual: fresh scratch install per criterion 8
                      Manual: `dev/bin/wwctl status`

Rollback:             git mv dev system && git mv dev/tests tests, then
                      `git checkout .` on the edited reference files. History-preserving and
                      fully reversible before merge.

Fragility:            None HIGH FRAGILITY, but LARGE COORDINATED DIFF (>200 lines across the
                      rename + reference rewrite) -> standalone Simplifier + independent
                      Verifier REQUIRED per Agent Execution Model. Run SOLO: no parallel task
                      may touch dev/, dev/tests/, install.sh, or bin/ww-init.sh concurrently.

Risk notes:           (Orchestrator) The task cards themselves live under dev/tasks/cards/
                      and WILL relocate to dev/tasks/cards/ during this rename — expected;
                      git mv handles it. Verify install still works with config/ carrying the
                      5 runtime YAMLs from 1A. docs/site/ mirror references to dev/ are
                      OUT OF SCOPE (handled in Part 4). Confirm no runtime code path other
                      than bin/ww-init.sh PATH inject depends on dev/ existing at runtime
                      (1A cleared field-mapper + profile-uda).
                      (Builder) fill pre-flight brief; enumerate the exact grep-verified
                      reference set before editing.

Resolution:
  Implemented on branch agent/builder/struct-1b (commit 160e725). git mv system->dev +
  tests->dev/tests (285 renames); protected system/->dev/ + tests/->dev/tests/ rewrite;
  install.sh stops shipping dev/; ww-init.sh -> dev/bin with -d guard.
  REGRESSION caught+fixed in-pass: test files' relative root derivation
  (${BATS_TEST_DIRNAME}/.., dirname, SCRIPT_DIR/../) assumed depth-1; moving deeper broke
  652/665 tests. Added one traversal level everywhere. Logged in decisions.md (2026-07-10).
  Verified: full bats dev/tests/ 605/60 IDENTICAL to master; scratch install ships config/
  not dev/, runtime resolves without dev/; wwctl runs from dev/bin.
  Sign-off: dev/reports/verifier-TASK-STRUCT-1B.md.
  PRE-MERGE CONDITIONS: N1 (integration in installed env), N2 (docs/ refs -> Part 4).

Status:               complete
Taskwarrior:          (assign live TW id on dispatch) status:in-review
