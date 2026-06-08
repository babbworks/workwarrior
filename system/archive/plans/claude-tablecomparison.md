# Point-by-Point Agree/Disagree Table: Claude Semifinal vs Codex Semifinal

Documents compared:
- `claude-semifinal.md` — Claude's comparative analysis of claude-plan vs codex-plan
- `codex-semifinal.md` — Codex's comparative analysis of codex-remix vs claude-remix

---

## Governance

| Point | Claude Semifinal | Codex Semifinal | Verdict |
|---|---|---|---|
| Hard Gates A–E are non-negotiable | Yes — both original plans agreed, treat as load-bearing | Yes — retain unchanged, enforce as merge blockers not advisory | **AGREE** |
| No self-approval (implementing role ≠ approving role) | Yes — named explicitly as non-negotiable | Yes — named as non-negotiable | **AGREE** |
| Orchestrator owns scope, contracts, and merge decisions | Yes | Yes | **AGREE** |
| Release function is a gate/checklist, not a standing role | Yes — Gate D with checklist attached is sufficient | Yes — "set aside as permanent role; retain as gate" | **AGREE** |
| Status reconciliation must precede all new feature work | Yes | Yes | **AGREE** |

---

## Roles

| Point | Claude Semifinal | Codex Semifinal | Verdict |
|---|---|---|---|
| Core always-active roles: Orchestrator, Builder, Verifier, Docs | Yes — four roles for Phase 2+ | Yes — "always active: Orchestrator, Builder, Verifier, Docs" | **AGREE** |
| Explorer is context-deployed, not a standing role | Yes — dedicated for audit phases, absorbed into Builder pre-flight for feature tasks | Yes — "conditional: Explorer (audit/high-risk)" | **AGREE** |
| Simplifier is embedded in Verifier as default | Yes — Verifier always runs `/simplify` as checklist step | Yes — "Verifier always performs `/simplify` checklist pass" | **AGREE** |
| Simplifier escalates to standalone agent for large/high-risk diffs | Yes — escalation path named | Yes — "dedicated Simplifier only for large/high-risk diffs" | **AGREE** |
| Phase 1 uses five roles (adds Explorer); Phase 2+ uses four | Yes — stated explicitly | Implied but not stated as Phase-boundary distinction | **PARTIAL** — Claude more explicit on phase-bound role count |
| codex-remix is the concise summary artifact; claude-remix is the operational playbook | Not assessed — claude-semifinal compares original plans, not remixes | Yes — stated explicitly as semi-final disposition | **DISAGREE** — Claude semifinal doesn't make this meta-judgment; Codex semifinal does |

---

## Explorer Agents

| Point | Claude Semifinal | Codex Semifinal | Verdict |
|---|---|---|---|
| Explorer A covers docs/status drift | Yes — specific files listed: `pending/IMPLEMENTATION_STATUS.md`, `pending/OUTSTANDING.md`, `docs/IMPLEMENTATION-COMPLETE.md`, `docs/RELEASE-CHECKLIST.md`, `pending/*SUMMARY*` | Yes — "status/docs contradictions and overclaims" | **AGREE** |
| Explorer B covers code/test reality | Yes — GitHub sync TODOs, dry-run paths, test coverage map, required baseline per change type | Yes — "code/test reality, TODO/placeholder paths, test baseline by change type" | **AGREE** |
| Explorer A and B run in parallel | Yes — explicitly stated as parallel, read-only | Yes — "parallel read-only audits" | **AGREE** |
| Explorer A and B produce distinct outputs feeding Orchestrator synthesis | Yes — contradiction matrix (A) and code-vs-doc gap list + test coverage map (B) | Yes — "Orchestrator synthesizes audit outputs into a single decision matrix" | **AGREE** |
| Explorer absorbed into Builder pre-flight for Phase 2+ individual feature tasks | Yes — one-paragraph risk brief | Yes — implied by "conditional" framing | **AGREE** |

---

## Parallelization

| Point | Claude Semifinal | Codex Semifinal | Verdict |
|---|---|---|---|
| Parallel execution only on disjoint write sets | Yes | Yes | **AGREE** |
| Orchestrator verifies disjointness before dispatch | Yes — stated explicitly | Implied by Orchestrator authority over contracts | **PARTIAL** — Claude more explicit |
| Branch naming: `agent/<role>/<topic>` | Yes — named as adopted from Codex | Yes — retained | **AGREE** |
| One worktree per active Builder stream | Yes | Not explicitly stated | **PARTIAL** — only in Claude semifinal |
| Default serialized files: `bin/ww` | Yes — Codex wins here, adopt its specific callouts | Yes — named in 6.4 | **AGREE** |
| Default serialized files: `lib/shell-integration.sh` | Yes | Yes | **AGREE** |
| Default serialized files: `lib/github-*.sh` | Yes | Yes | **AGREE** |
| Default serialized files: `lib/sync-*.sh` | Yes | Yes | **AGREE** |

---

## Task Card Format

| Point | Claude Semifinal | Codex Semifinal | Verdict |
|---|---|---|---|
| Unified 8-field task card format | Yes — merges Codex's 6 fields and Claude's 7 fields | Yes — "use a single `TASKS.md` with 8-field task cards" | **AGREE** |
| Fields: Goal, Acceptance criteria, Write scope, Tests required, Rollback, Fragility, Risk notes, Status | Yes — all eight named | Yes — endorsed | **AGREE** |
| "Risk notes from Explorers" as a named field (formal handoff artifact) | Yes — identified as the key addition from Codex plan | Yes — implicit in synthesis step | **AGREE** |
| `TASKS.md` at root is the single canonical source | Yes | Yes | **AGREE** |
| `pending/` becomes archive-only post-reconciliation | Yes | Yes | **AGREE** |

---

## Execution Substrate (CLAUDE.md + Memory)

| Point | Claude Semifinal | Codex Semifinal | Verdict |
|---|---|---|---|
| Root `CLAUDE.md` is highest-leverage first deliverable | Yes — Claude plan wins here, adopt its full strategy | Yes — step 1 of Phase 1 plan | **AGREE** |
| `services/CLAUDE.md` is second priority | Yes | Yes — step 2 of Phase 1 plan | **AGREE** |
| `lib/CLAUDE.md` is a Phase 2 prerequisite, not Phase 1 deliverable | Yes — "no Builder task touching `lib/` starts until it exists" | Yes — "mandatory as Phase 2 prerequisite tied to actual work type" | **AGREE** |
| `tests/CLAUDE.md` written at Phase 2 start using Explorer B output | Yes | Yes — "at Phase 2 start from Explorer B outputs" | **AGREE** |
| Memory system: Builder risk briefs → project memories | Yes — adopt fully, only Claude plan addressed this | Endorsed indirectly via "compounding behavior over repeated sessions" | **PARTIAL** — Claude more explicit on memory routing |
| Memory system: Verifier failures → feedback memories | Yes | Not explicitly stated | **PARTIAL** — only in Claude semifinal |
| Memory system: Orchestrator decisions → project memories | Yes | Not explicitly stated | **PARTIAL** — only in Claude semifinal |
| CLAUDE.md priority order: root → services → lib → tests | Yes — explicit priority sequence | Implied by Phase 1 + Phase 2 prerequisite framing | **PARTIAL** — Claude more explicit |

---

## GitHub Sync Policy

| Point | Claude Semifinal | Codex Semifinal | Verdict |
|---|---|---|---|
| "GitHub sync off-limits" framing is rejected | Yes — replaced with high-fragility policy | Yes — "reject: replace with high-fragility policy" | **AGREE** |
| Requires explicit Orchestrator approval before Builder starts | Yes | Yes | **AGREE** |
| Requires extended risk brief (beyond standard) | Yes | Yes — "extended risk notes" | **AGREE** |
| Requires integration tests against test profile, not just unit tests | Yes | Yes — "stronger integration-test requirements" | **AGREE** |
| Requires dedicated Verifier sign-off line for sync behavior | Yes | Not explicitly stated | **PARTIAL** — only in Claude semifinal |
| Specific files named: `lib/github-*.sh`, `lib/sync-*.sh`, `services/custom/github-sync.sh` | Yes — all three named | Names `lib/github-*.sh` and `lib/sync-*.sh` in serialization rules; services file not separately called out | **PARTIAL** — Claude more comprehensive |

---

## Phase 1 Plan Structure

| Point | Claude Semifinal | Codex Semifinal | Verdict |
|---|---|---|---|
| Phase 1 is foundational only — no new features or services | Yes | Yes | **AGREE** |
| Task 1.1: Root `CLAUDE.md` | Yes | Yes — step 1 | **AGREE** |
| Task 1.2: `services/CLAUDE.md` | Yes | Yes — step 2 | **AGREE** |
| Dual parallel Explorer audit (A + B) | Yes | Yes — step 3 | **AGREE** |
| Orchestrator synthesizes Explorer outputs | Yes | Yes — step 4 | **AGREE** |
| Build canonical `TASKS.md` | Yes | Yes — step 5 | **AGREE** |
| Update root `CLAUDE.md` with test baselines from Explorer B | Yes — named as amendment to Task 1.1 | Yes — step 6 | **AGREE** |
| Artifact cleanup (`.gitignore` + untrack noise) | Yes — Task 1.5 with specific write scope | Yes — step 7 | **AGREE** |
| Phase 1 has 7 exit criteria | Yes | Yes — "all seven are complete" | **AGREE** |
| Test strategy normalization is an Explorer B deliverable, not a separate task | Yes — absorbed into 1.3b | Implied by Explorer B charter covering test baselines | **AGREE** |
| Claude's numbered task format is more actionable than Codex's 8-step sequence | Yes — stated as resolution | Yes — "claude-remix is ready for immediate execution with less interpretation risk" | **AGREE** |

---

## Meta-Level Assessments

| Point | Claude Semifinal | Codex Semifinal | Verdict |
|---|---|---|---|
| Both original plans agreed on the same core points | Yes — identified as load-bearing convergence | Yes — "high-confidence, should remain fixed" | **AGREE** |
| `claude-remix-1.md` is the operational execution document | Not assessed at this level | Yes — "operational source of truth" | **DISAGREE** — Codex semifinal makes a disposition judgment; Claude semifinal does not |
| `codex-remix-1.md` serves as concise strategic summary | Not assessed | Yes — "concise alignment artifact" | **DISAGREE** — same scope difference |
| Governance validity of both documents | Not assessed in this framing | Yes — "both valid; codex-remix more compact; claude-remix operationalizes it" | **DISAGREE** — Codex semifinal includes a validity assessment section Claude semifinal does not |

---

## Summary Scorecard

| Category | Agree | Partial | Disagree |
|---|---|---|---|
| Governance | 5 | 0 | 0 |
| Roles | 5 | 1 | 1 |
| Explorer Agents | 5 | 0 | 0 |
| Parallelization | 5 | 2 | 0 |
| Task Card Format | 5 | 0 | 0 |
| Execution Substrate | 4 | 4 | 0 |
| GitHub Sync Policy | 4 | 2 | 0 |
| Phase 1 Structure | 11 | 0 | 0 |
| Meta-Level | 1 | 0 | 3 |
| **Total** | **45** | **9** | **4** |

---

## Key Observations

**Near-total agreement on substance.** 45 of 58 points are full agrees. Every disagreement is at the meta-level (scope and disposition judgments) not at the strategic or tactical level. The two semifinal documents are analyzing slightly different pairs of source documents, which accounts for the asymmetry.

**Partial agreements are exclusively about depth.** All 9 partials follow the same pattern: Claude semifinal is more explicit (memory routing, phase-bound role counts, Verifier sign-off line for sync, worktree mechanics). Codex semifinal endorses the same directions but at a higher level of abstraction. No partials represent actual conflict.

**The four disagreements are all meta-judgments.** Codex semifinal makes a disposition ruling (claude-remix = operational playbook, codex-remix = summary) and includes a validity assessment section. Claude semifinal doesn't make these judgments because it was comparing the original plans, not the remixes. These are scope differences, not strategic conflicts.

**Bottom line:** The two semifinal documents are substantively convergent. The ratified strategy from `claude-remix-1.md` stands. The only open question is whether to formally adopt Codex semifinal's meta-disposition (claude-remix as operational playbook) — which is reasonable and adds clarity.
