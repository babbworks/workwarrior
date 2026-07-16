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

Status:               complete

Resolution addendum (2026-07-14):
  STRM-002 implementation is functionally complete (registry module works,
  23 tests pass) but two design issues surfaced post-verification:

  1. ACTOR ID FORMAT — the original `human:morgen` format is not collision-safe
     at scale. DESIGN DECISION (accepted):
     - Three tiers: solo (slug only), team (slug.nano4), enterprise (slug.nano6)
     - Slug: [a-z0-9][a-z0-9-]*, max 30 chars. Human-readable portion.
     - Nano: base36 (a-z0-9), 4 or 6 chars. Auto-assigned at registration.
     - id_scheme stored in config/actors.yaml, set on first stream init.
     - Federation prefix (instance_id/) deferred — added only when federating.
     - Examples: human:marta.k7x2, agent:claude-budget.p3n1, machine:haas-lathe.d4m8

  2. SHIPPING — config/actors.yaml must not contain personal data in the repo.
     FIX: ships with `id_scheme: null` and `actors: {}`. Setup prompted on
     first stream init. No personal data ever committed.

  REMAINING WORK to close this card:
  - Update lib/actor-registry.sh: actor_reg_add must auto-append nano suffix
    based on id_scheme (solo = no suffix, team = 4, enterprise = 6)
  - Update actor_validate in services/stream/lib/actor.sh to accept the
    slug.nano format (currently only validates `kind:local-id` as [a-z0-9_-]*)
  - Add id_scheme setup prompt to stream init path
  - Update tests for new format
Taskwarrior:          (assign live TW id on dispatch)
