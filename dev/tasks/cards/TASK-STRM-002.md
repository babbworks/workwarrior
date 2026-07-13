## TASK-STRM-002: Actor registry (config/actors.yaml) + owning module

Goal:                 Make actor identity real: the instance roster, the profile membership
                      overlay, and a SINGLE owning module that reads them. Mirrors the
                      lib/ledger-config.sh pattern — one owner of the file contract, so we
                      do not repeat the ledgers.yaml five-parsers fiasco (F2).

Depends on:           TASK-STRM-001 (actor.sh — ID validation and kind parsing)

Contract:             dev/schemas/actors-v1.md
Design:               dev/specs/2026-07-12-stream-actor-axis-design.md §3.2

Acceptance criteria:  1. NEW `config/actors.yaml` — instance roster, schema v1. Ships (runtime
                         data -> config/, per the placement rule). Seeded with the current
                         user as `human:<name>` and nothing else.
                      2. NEW `lib/actor-registry.sh` — the SINGLE reader/writer, python/
                         yaml.safe_load-backed (consistent with lib/instance-registry.sh and
                         lib/ledger-config.sh). Sourced-lib rules: no `set -euo pipefail`,
                         return codes only.
                         Readers:  actor_reg_{list,get,exists,kind,display,members,weight}
                         Writers:  actor_reg_{add,set_status,set_field}
                      3. Resolution order profile -> instance for PARTICIPATION fields
                         (role, weight). IDENTITY resolves at instance tier only: a profile
                         MUST NOT be able to define an actor the instance does not know —
                         attempting it is a user error (exit 1) with a clear message.
                      4. `actor_reg_add` REFUSES to write a row whose `source` is not `local`
                         (schema §4 — mirrored rows are reverted by the next sync).
                      5. Delete is NOT implemented. `actor_reg_set_status <id> inactive` is
                         the only removal path (schema §3 — actors are never deleted; the log
                         references them forever).
                      6. Unknown YAML fields are PRESERVED on rewrite (reserved-but-inert).
                      7. Optional `profiles/<name>/actors.yaml` overlay is read when present
                         and absent-safe when not.

Write scope:          config/actors.yaml                    (new)
                      lib/actor-registry.sh                 (new)
                      resources/                            (profile actors.yaml template)
                      dev/tests/test-actor-registry.bats    (new)

Tests required:       bats dev/tests/test-smoke.bats
                      bats dev/tests/test-actor-registry.bats
                      bats dev/tests/            (full suite — at/above baseline)
                      Manual: profile overlay resolution (weight from profile, display from
                              instance); profile-defines-unknown-actor -> exit 1.

Rollback:             git revert + rm config/actors.yaml. No consumer depends on it until
                      STRM-003; the registry is inert on its own.

Fragility:            LOW. New files only; no existing code path reads them yet.

Risk notes:           (Orchestrator) The one-owning-module rule is the whole point. The
                      ledgers.yaml audit found FIVE independent YAML parsers for one file and
                      a schema forked three ways (decisions 2026-07-11). Any card that greps
                      or awks actors.yaml directly is a Gate B failure.
                      (Builder) IDs are IMMUTABLE (schema §5) — they appear in the append-only
                      log. There must be no rename path. Forward-compat: an unqualified ID
                      reads as local-instance, so a future registry tier does not break IDs.

Status:               pending
Taskwarrior:          (assign live TW id on dispatch)
