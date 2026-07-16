## TASK-UNIT-001: The unit registry — the system's shared vocabulary of quantity

Goal:                 Promote "what is being counted" out of the ledger and into a repo-wide
                      registry that the ledger, `stream`, `viz` and tasks all read.

                      THIS IS THE KEYSTONE. `dev/docs/ledger-systems-accounting.md` calls it axis A
                      and says almost everything is downstream of it — and it has had NO CARD, while
                      LED-014, LED-015 and LED-017 all quietly ASSUME units exist as a shared
                      vocabulary. This closes that gap before Phase 3 builds on sand.

Depends on:           —  (nothing blocks it; it blocks Phase 3)
Blocks:               TASK-LED-014, TASK-LED-015, TASK-LED-017

Why it matters:       The thesis is that double-entry is a conservation law and money is merely the
                      first commodity it was applied to. If that is true, the UNIT is the system's
                      most fundamental noun — hours, kWh, kg, machine-cycles, API dollars, defects —
                      and it cannot live inside one service. A unit declared by `stream` must mean
                      the same thing to the ledger, or the two cannot be reconciled and the whole
                      claim collapses.

                      The extension point already exists: `config/` already holds
                      `service-uda-registry.yaml`, `uda-color-map.yaml`, `body-uda-map.yaml` — a
                      central registry that many services read. This is that same shape.

DECISIONS:

  D1. NAME -> **`unit`**. DECIDED 2026-07-13 by the Orchestrator. `config/units.yaml`.
      Rationale: `commodity` is hledger's word and carries financial baggage into a system whose
      entire thesis is that units are GENERAL — it would adopt the vocabulary of the special case
      to describe the general case. `unit` is what the thing IS; `commodity` is what hledger calls
      it at the boundary. Map `unit -> hledger commodity` IN THE ADAPTER, never in the name.

  D2. AUTHORITY -> **authoritative, with a loud unknown.** DECIDED 2026-07-13. If `stream` emits a unit the
      registry has never seen, the EVENT IS STILL RECORDED (the log is truth; the registry is a
      lookup table — same rule as actors-v1 §7), but the unit is reported as `unregistered` and
      surfaces in a report. Never silently coerce; never silently drop. An unknown unit is a
      registry problem, not a data problem.

Acceptance criteria:  1. NEW `config/units.yaml` (schema v1). Ships (runtime data -> config/).
                         Per unit: `id`, `display`, `dimension` (time|energy|mass|count|money|...),
                         `symbol` (the hledger commodity string), `precision`, and optional
                         `equivalences` (e.g. kWh = 1000 Wh).
                      2. NEW `dev/schemas/units-v1.md` — the normative contract.
                      3. NEW `lib/unit-registry.sh` — the SINGLE owner (python/yaml.safe_load-backed,
                         sourced-lib rules). Do NOT let a second parser exist: the ledgers.yaml audit
                         found FIVE parsers for one file and a schema forked three ways.
                      4. `equivalences` GENERATE hledger `P` price directives. VERIFIED mechanism:
                         `P 2026-01-01 kWh 1000 Wh` + `-X Wh` converts 3 kWh -> 3000 Wh
                         (dev/reports/ledger-hledger/, Test 2). The price engine IS a unit-conversion
                         algebra — this is why ledger-cli is not needed.
                      5. An unregistered unit is REPORTED, never silently coerced or dropped (D2).
                      6. `ww unit list|show <id>` — read-only.
                      7. NOT IN SCOPE: attention COEFFICIENTS. A weight is per-profile/per-mode
                         (profiles/*/actors.yaml, and §6.5 "a mode is a price table"). The registry
                         says what a unit IS; a mode says what it is WORTH. Keep them apart.

Write scope:          config/units.yaml                (new)
                      dev/schemas/units-v1.md          (new)
                      lib/unit-registry.sh             (new)
                      bin/ww                           (SERIALIZED — `ww unit` verb)
                      dev/tests/test-unit-registry.bats (new)

Tests required:       bats dev/tests/test-unit-registry.bats
                      bash dev/scripts/check-regression.sh
                      Manual: an equivalence round-trips through hledger `-X` and matches
                      hand-calculation (criterion 4).

Rollback:             git revert + rm config/units.yaml. Nothing consumes it until LED-014.

Fragility:            LOW to build (new files + one bin/ww verb), HIGH in consequence. Get the
                      vocabulary wrong and every downstream card inherits it. This is the cheapest
                      moment to get it right.

Risk notes:           (Orchestrator) Both decisions are made: D1 `unit`, D2 authoritative-with-a-
                      loud-unknown. The card is fully specified — Gate A satisfied, dispatchable.
                      (Builder) The registry describes units. It does NOT value them. The moment a
                      coefficient appears in config/units.yaml, the mode concept has been collapsed
                      into the vocabulary and the "personal vs production is one engine with two
                      price tables" result is lost.

REMAINING — round 2 (card stays OPEN until these land):

  The round-1 build shipped the vocabulary, the same-dimension invariant and the hledger
  price-directive boundary. Four gaps were identified on review (2026-07-13) and are NOT done.
  The third is the serious one.

  R1. NO BASE UNIT PER DIMENSION.
      Nothing declares that `Wh` is the anchor for energy, or `g` for mass. Without it you
      cannot say "normalise everything in this dimension" — you can only convert to a unit you
      name explicitly. Add `base: true` (exactly one per dimension; enforce it).

  R2. CHAINED CONVERSION IS UNVERIFIED.
      Adding `MWh -> kWh (x1000)` means `MWh -> Wh` requires hledger to CHAIN two price
      directives. hledger can find conversion paths, but round 1 only tested DIRECT, single-hop
      conversion. **Do not rely on chaining until it is executed and observed.** Verify against
      the installed hledger before any downstream card assumes it.

  R3. A DIMENSION CAN SILENTLY FRAGMENT — validate does NOT catch it.  ** the serious one **
      `unit_reg_validate` checks that an equivalence target exists, shares the dimension, is not
      self-referential, and has a positive factor. It does NOT check CONNECTIVITY. So a unit
      added to a dimension with NO equivalence sits there as an ISLAND: incomparable to its
      peers, and nothing complains. Two energy quantities that should be addable would simply
      fail to combine in a report.
      This is the same class of bug we have hunted all session: NOT AN ERROR — just a quietly
      wrong answer. Make it fatal: every unit MUST have a conversion path to its dimension's
      base (R1), or the registry is incoherent.

  R4. NO `ww unit add`.
      The CLI is read-only BY DESIGN and that is asserted structurally — correct for round 1,
      but thin for adoption. A factory bringing this up needs `defects`, `billets`,
      `machine-hours`, and "hand-edit a YAML file, then run validate" is a developer's workflow,
      not an operator's. Add a write path that validates before it writes.

  SETTLED, not a gap: units are INSTANCE-SCOPED ONLY — no per-profile tier (unlike actors,
  which have three). A unit must mean the same thing everywhere or the shared vocabulary is not
  shared. A kilogram does not become something else in the production profile.


Resolution:
  Implemented 2026-07-13 on agent/builder/unit-001.
  config/units.yaml (9 units across time/energy/mass/count/money/score) + lib/unit-registry.sh
  (the single owner) + dev/schemas/units-v1.md + `ww unit list|show|check|prices|validate`
  (read-only, structurally asserted).
  D1 `unit` and D2 authoritative-with-a-loud-unknown both implemented and tested.
  THE SAME-DIMENSION INVARIANT IS ENFORCED: a cross-dimension equivalence is REJECTED, because
  an equivalence is a CONVERSION (1 kWh = 1000 Wh, always true) while a cross-dimension relation
  is a PRICE (what a thing is WORTH) and belongs to a mode. hledger agrees independently: -X Wh
  leaves kg and h untouched, since no price path exists between dimensions.
  END TO END VERIFIED: the registry's generated P directives drive real hledger conversion —
  3 kWh -> 3000 Wh, 2 h -> 120 min — with no hand-written price table.
  Tests 21/21; check-regression.sh clean.

Status:               complete
Taskwarrior:          (assign live TW id on dispatch)
