# Codex Table Comparison: Claude vs Codex Semifinal

Source documents:
- `/Users/mp/ww/system/plans/claude-semifinal.md`
- `/Users/mp/ww/system/plans/codex-semifinal.md`

## Point-by-Point Agree/Disagree Table

| # | Topic | Claude Semifinal Position | Codex Semifinal Position | Agree/Disagree | Resolution / Ratified Direction |
|---|---|---|---|---|---|
| 1 | Hard gates A-E | Keep unchanged; load-bearing | Keep unchanged; load-bearing | Agree | Keep A-E as mandatory merge/release blockers |
| 2 | No self-approval | Explicitly required | Explicitly required | Agree | Enforce role separation in all tasks |
| 3 | Orchestrator authority | Orchestrator owns contracts/merges | Orchestrator owns control plane | Agree | Orchestrator remains final authority |
| 4 | Parallelization rule | Parallel only on disjoint write sets | Parallel only on disjoint write sets | Agree | Keep as hard dispatch constraint |
| 5 | Branch naming | `agent/<role>/<topic>` | `agent/<role>/<topic>` | Agree | Adopt as standard |
| 6 | Canonical task source | Replace `pending/` with canonical source | Use `TASKS.md`; `pending/` archive-only | Agree | Canonical `TASKS.md`; freeze `pending/` |
| 7 | Status reconciliation first | Must occur before feature work | Must occur before feature work | Agree | Phase 1 audit required before Phase 2 |
| 8 | GitHub sync risk status | Highest-risk surface | High-fragility with elevated controls | Agree | Treat as high-fragility with stricter approvals/tests |
| 9 | Role model baseline | Context-deployed Explorer; Verifier+Simplifier embedding; no standing release role | Always: Orchestrator/Builder/Verifier/Docs; conditional Explorer/Simplifier; release as gate | Partial agreement | Use dynamic model: core 4 always, Explorer/Simplifier conditional, Release handled as Gate D checklist |
| 10 | Explorer usage in Phase 1 | Dedicated Explorer A/B split for audits | Conditional Explorer; dual audit implied in Phase 1 | Partial agreement | Use explicit parallel Explorer A/B in Phase 1 |
| 11 | Explorer usage in Phase 2+ | Usually absorbed into Builder pre-flight | Conditional Explorer for high-risk work | Partial agreement | Builder pre-flight by default; dedicated Explorer for high-risk/cross-cutting changes |
| 12 | Simplifier role | Embedded in Verifier; escalate on large diffs | Conditional quality pass on large/high-risk changes | Agree | Verifier always runs simplify checklist; escalate to separate pass if needed |
| 13 | Release role | No separate release role; Gate D checklist sufficient | No permanent release role; release gate still mandatory | Agree | Keep as governance gate only |
| 14 | Serialized ownership specificity | Codex callouts should be adopted | Explicitly names serialized core paths | Partial agreement | Serialize by default for `bin/ww`, `lib/shell-integration.sh`, `lib/github-*.sh`, `lib/sync-*.sh` |
| 15 | Task card schema | Merge both into 8 fields | 8-field dispatchable cards adopted | Agree | Standardize on 8 fields (goal, acceptance, write scope, tests, rollback, fragility, risk notes, status) |
| 16 | CLAUDE.md implementation depth | Strong implementation order/details, cold-read acceptance | Endorses CLAUDE.md but less implementation detail | Disagree on detail level | Use Claude depth: root -> services -> lib -> tests progression |
| 17 | Memory system integration | Explicitly operationalized and essential | Included as substrate, less detailed | Partial agreement | Adopt explicit memory writes: risk briefs, verifier failures, orchestrator decisions |
| 18 | Phase 1 structure | Detailed tasks, owners, sequence, and outputs | High-level 8-step ratified sequence | Disagree on granularity | Use Claude structure with Codex governance constraints |
| 19 | Test strategy normalization | Integrated into Explorer B output and baseline matrix | Dedicated step in ratified Phase 1 plan | Partial agreement | Keep as explicit deliverable owned by Explorer B, validated by Orchestrator |
| 20 | `lib/CLAUDE.md` timing | Defer from Phase 1, require before lib work in Phase 2 | Qualified defer; Phase 2 prerequisite | Agree | Make Phase 2 gate: no lib task before `lib/CLAUDE.md` |
| 21 | `tests/CLAUDE.md` timing | Defer to Phase 2 using Explorer B coverage map | Qualified defer; Phase 2 start | Agree | Author at Phase 2 start from coverage audit |
| 22 | Artifact hygiene | Explicit cleanup step in Phase 1 | Explicit cleanup step in Phase 1 | Agree | Keep Phase 1 artifact cleanup before feature PR flow |
| 23 | “Off-limits” sync policy | Reject hard freeze; use strict policy | Reject hard freeze; use strict policy | Agree | High-fragility policy, not absolute prohibition |
| 24 | Final operating source | Claude remix is primary execution playbook | Claude remix is primary, Codex remix is summary | Agree | Use Claude-derived operating procedure, Codex as concise governance summary |

## Consolidated Ratified Outcome

| Area | Ratified Decision |
|---|---|
| Operating spec | Use Claude-style detailed execution model with Codex governance hardening |
| Core roles | Orchestrator, Builder, Verifier, Docs |
| Conditional roles | Explorer (audits/high-risk), Simplifier (large/high-risk diffs) |
| Governance | Hard gates A-E, no self-approval, explicit contracts before coding |
| Parallelism | Disjoint write sets only; serialized ownership for named core files |
| Canonical tracking | `TASKS.md` only; `pending/` archive-only after reconciliation |
| Phase 1 | Context docs -> dual explorer audits -> synthesis -> canonical tasks -> artifact cleanup |
| Phase 2 entry constraints | `lib/CLAUDE.md` and `tests/CLAUDE.md` policy prerequisites enforced by task type |

