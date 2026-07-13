## TASK-LED-004: Build lib/ledger-config.sh — single owner of the ledgers.yaml contract

Goal:                 Create one python-backed reader/writer module that fully implements the
                      frozen jrnl-style hybrid ledgers.yaml schema (see decisions.md
                      2026-07-11), so every ledger consumer can stop hand-rolling its own
                      YAML parse. This card builds and unit-tests the module only — no
                      consumers are repointed yet (that is TASK-LED-005).

Acceptance criteria:  1. New file lib/ledger-config.sh sources cleanly with no
                         `set -euo pipefail` and no top-level `exit` (sourced-lib rules).
                      2. Reader functions implemented and covered by tests:
                         - ledger_cfg_path                → echoes $WORKWARRIOR_BASE/ledgers.yaml
                         - ledger_cfg_names [--include-hidden] → names excluding reserved
                           `default`; excludes hidden:true entries unless flag given
                         - ledger_cfg_resolve <name>      → abs path; handles string form,
                           map `journal:` form, AND legacy map `path:` form (the last with a
                           deprecation warning to stderr); returns 2 if name absent
                         - ledger_cfg_default_path         → resolves the reserved `default` key
                         - ledger_cfg_get_field <name> <field> → echoes commodity/hidden/role/
                           description or empty
                         - ledger_cfg_exists <name>       → return 0/1
                      3. Writer functions implemented, atomic (tmp+mv), validating before commit:
                         - ledger_cfg_add <name> <path> [--commodity X|--hidden|--role R|--desc D]
                           emits STRING form when no metadata flags given, MAP form otherwise
                         - ledger_cfg_remove <name>       → refuses reserved `default`; refuses
                           an entry whose resolved path equals default's path
                         - ledger_cfg_rename <old> <new>  → refuses `default`; keeps default's
                           path in sync when the renamed ledger was the default
                         - ledger_cfg_set_default <name>  → points `default` at name's path
                         - ledger_cfg_set_field <name> <field> <value> → upgrades a string entry
                           to map form as needed
                      4. Validation: names match ^[a-zA-Z0-9_-]+$; `hidden` must be boolean;
                         `role` in {standalone,include}; unknown map keys warn (not error);
                         duplicate resolved paths warn (not error).
                      5. Writer NEVER emits the legacy `path:` key — only `journal:`.
                      6. Graceful, single error path if PyYAML is unavailable (return 2 +
                         one clear log_error), not a python traceback.
                      7. bats tests/test-ledger-config.bats passes, exercising: string entry,
                         map entry, legacy path: read + warning, default resolution by key
                         (not position), add-with/without-metadata emit forms, remove/rename
                         guards, set-default, hidden filtering, bad-name rejection.

Write scope:          lib/ledger-config.sh
                      tests/test-ledger-config.bats

Tests required:       bats tests/test-ledger-config.bats
                      bats tests/test-smoke.bats
                      bats tests/            (full suite — lib/ change; expect only the known
                                             ~29 baseline failures, no new ones)

Rollback:             git rm lib/ledger-config.sh tests/test-ledger-config.bats
                      (No consumer is wired to the module in this card, so removal is
                      side-effect-free — nothing else imports it yet.)

Fragility:            None. New file; no existing consumer depends on it yet.
                      NOT serialized: lib/shell-integration.sh is untouched by this card
                      (its repointing happens in TASK-LED-005).

Risk notes:           (Orchestrator) PyYAML is already a de-facto dependency — cmd_ledger task
                      and services/questions/handlers/ledger_handler.sh both `import yaml`
                      today; this module centralizes that assumption behind one guarded entry.
                      Parsing MUST be python/yaml.safe_load — line-oriented awk/grep cannot
                      survive the string-or-map ambiguity (a map entry spans multiple lines).
                      Precedent for python-backed lib parsing: lib/instance-registry.sh.
                      (Builder) fill in pre-flight before touching files.

Resolution:
  Implemented on agent/builder/ledger-schema; PORTED onto the dev/ layout and MERGED by
  TASK-LED-012 (2026-07-13). Code is live: lib/ledger-config.sh + lib/ledger-dispatch.sh.
  Ledger + alias suites 92/92; check-regression.sh clean.
  NOT self-approved: no Verifier sign-off exists for LED-004..011. One pass over the
  merged result is owed.

Status:               in-review
Taskwarrior:          wwdev task <id> (<uuid>) status:pending
