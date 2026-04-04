# Codex Semi-Final: Deep Comparison of Remix Documents

Primary documents compared:
- `/Users/mp/ww/system/plans/codex-remix-1.md`
- `/Users/mp/ww/system/plans/claude-remix-1.md`

This document provides a detailed side-by-side analysis and a semi-final recommendation before execution begins.

---

## 1. Executive Summary

The two remix documents are strategically aligned on core governance and quality principles, but differ substantially in operational depth. `claude-remix-1.md` is the stronger execution protocol and should be treated as the active operating specification. `codex-remix-1.md` remains a strong concise summary and is valuable as a quick alignment artifact, but by itself is too high-level for deterministic multi-agent execution.

Recommended disposition:
- **Operational source of truth:** `claude-remix-1.md`
- **Concise alignment summary:** `codex-remix-1.md`

---

## 2. What the Two Remixes Agree On (Load-Bearing)

Both documents independently validate the following points, which should be considered non-negotiable:

1. Hard gates A-E are required.
2. No self-approval: the implementing role cannot be the approving role.
3. Parallelization only with disjoint write sets.
4. Orchestrator authority over scope/contracts/merge decisions.
5. Status reconciliation must occur before new feature implementation.
6. A canonical task source must replace drifting status narratives.
7. GitHub sync paths are high-fragility and require stricter controls.

Because these are convergent conclusions from both artifacts, they are high-confidence and should remain fixed.

---

## 3. Core Differences and Their Practical Impact

### 3.1 Depth of Execution Detail

`codex-remix-1.md`:
- Clear strategic direction.
- Defines role set and Phase 1 sequence at a high level.
- Emphasizes governance hardening and hybridization.

`claude-remix-1.md`:
- Converts strategy into explicit operating mechanics.
- Specifies nuanced role deployment modes.
- Adds concrete task structuring, sequencing, and dependency logic.

Impact:
- `codex-remix` is good for strategy confirmation.
- `claude-remix` is ready for immediate execution with less interpretation risk.

### 3.2 Role Model Specificity

`codex-remix-1.md` recommends:
- Orchestrator, Builder, Verifier, Docs.
- Conditional Explorer and conditional Simplifier.

`claude-remix-1.md` refines this:
- Explorer is **context-deployed** (explicitly used for audit phases and major analysis).
- Simplifier is embedded in Verifier as default, with escalation to standalone pass for large diffs.
- Release function is a gate/checklist (Gate D), not a standing role.

Impact:
- `claude-remix` better resolves role-overhead vs rigor by making deployment conditional by context.

### 3.3 Explorer Deployment

`codex-remix-1.md`:
- Endorses conditional Explorer use but does not define exact split mechanics.

`claude-remix-1.md`:
- Explicitly splits Phase 1 audit into:
  - **Explorer A:** status/docs contradiction audit.
  - **Explorer B:** code/test reality and risk audit.
- Makes these parallel, read-only, and output-distinct.

Impact:
- This split reduces ambiguity and increases audit quality and throughput.

### 3.4 Serialized Ownership Guidance

`codex-remix-1.md`:
- Mentions serialized ownership for shared core files conceptually.

`claude-remix-1.md`:
- Names default serialized file sets concretely:
  - `bin/ww`
  - `lib/shell-integration.sh`
  - `lib/github-*.sh`
  - `lib/sync-*.sh`

Impact:
- Concrete serialization rules are operationally superior; they avoid accidental overlap and merge contention.

### 3.5 Task Card Contract Design

`codex-remix-1.md`:
- Strong contract principle, but not fully normalized into a single expanded schema.

`claude-remix-1.md`:
- Defines a unified 8-field card:
  - Goal
  - Acceptance criteria
  - Write scope
  - Tests required
  - Rollback
  - Fragility
  - Risk notes
  - Status

Impact:
- Higher dispatchability and cleaner cross-agent handoffs.

### 3.6 Substrate Maturity (CLAUDE.md + Memory)

`codex-remix-1.md`:
- Endorses `CLAUDE.md` and memory as strategy.

`claude-remix-1.md`:
- Provides implementation posture:
  - Priority order for context docs.
  - Where and how memory gets populated from risk briefs/failures/decisions.
  - Phase boundary rules for `lib/CLAUDE.md` and `tests/CLAUDE.md`.

Impact:
- Better compounding behavior over repeated sessions; less re-briefing.

---

## 4. Reassessment of Previously Set-Aside Approaches

### 4.1 Dedicated Explorer Role

Status: **Partially restore**
- Keep explicit Explorer role for Phase 1 audits and high-risk cross-cutting analysis.
- Absorb Explorer behavior into Builder pre-flight for routine feature tasks.

Rationale:
- Full-time Explorer is unnecessary overhead.
- No Explorer at all is insufficient for large audit/reconciliation phases.

### 4.2 Separate Simplifier Stage

Status: **Conditional**
- Baseline: Verifier always performs `/simplify` checklist pass.
- Escalation: dedicated Simplifier only for large/high-risk diffs.

Rationale:
- Preserves quality tightening without introducing blanket process drag.

### 4.3 Separate Release Agent

Status: **Set aside as permanent role; retain as gate**
- No standing release role required at this scale.
- Gate D remains mandatory via checklist signoff.

Rationale:
- Keep rigor, avoid unnecessary role proliferation.

### 4.4 “GitHub Sync Off-Limits”

Status: **Reject**
- Replace with high-fragility policy:
  - Explicit Orchestrator approval.
  - Extended risk notes.
  - Stronger integration-test requirements.

Rationale:
- Absolute freezes block necessary maintenance and bug fixes.

### 4.5 Deferring `lib/CLAUDE.md` and `tests/CLAUDE.md`

Status: **Qualified defer**
- Not mandatory as immediate Phase 1 deliverables.
- Mandatory as Phase 2 prerequisites tied to actual work type:
  - `lib/CLAUDE.md` before any `lib/` builder work.
  - `tests/CLAUDE.md` at Phase 2 start from Explorer B outputs.

Rationale:
- Keeps Phase 1 focused while preventing unsafe Phase 2 expansion.

---

## 5. Validity Assessment by Category

### Governance Validity

Both documents are valid. `codex-remix` expresses governance more compactly; `claude-remix` preserves that governance and makes it operational. No conflict requiring rejection.

### Execution Validity

`claude-remix` is more valid as an execution artifact due to explicit sequencing and deliverable decomposition.

### Risk-Control Validity

`claude-remix` is stronger because it anchors fragility controls in specific file classes and required outputs.

### Scalability Validity

Hybrid model remains valid:
- Lean core roles for normal flow.
- Contextual role expansion (Explorer/Simplifier) when risk or complexity dictates.

---

## 6. Ratified Semi-Final Strategy

### 6.1 Operating Model

Adopt a two-layer system:
1. Governance control plane (Orchestrator + hard gates + no self-approval + explicit contracts).
2. Execution substrate (`CLAUDE.md` context docs + memory accumulation + worktree isolation + canonical task cards).

### 6.2 Role Deployment

- Always active: Orchestrator, Builder, Verifier, Docs.
- Conditional: Explorer (audit/high-risk), Simplifier (large/high-risk diffs).
- Release function: checklist gate under Orchestrator, not a standing role.

### 6.3 Hard Gates

Retain gates A-E unchanged and enforce them as merge blockers, not advisory criteria.

### 6.4 Parallelization Policy

- Parallel only on explicitly disjoint write scopes.
- Default serialization for:
  - `bin/ww`
  - `lib/shell-integration.sh`
  - `lib/github-*.sh`
  - `lib/sync-*.sh`

### 6.5 Canonical Tasking

Use a single `TASKS.md` with 8-field task cards.
Treat `pending/` as archive-only post-reconciliation.

---

## 7. Semi-Final Phase 1 Plan (Ratified)

1. Draft root `CLAUDE.md` with architecture, constraints, gates, and task-source references.
2. Draft `services/CLAUDE.md` with service-contract mechanics and conventions.
3. Run dual parallel read-only audits:
   - Explorer A: status/docs contradictions and overclaims.
   - Explorer B: code/test reality, TODO/placeholder paths, test baseline by change type.
4. Orchestrator synthesizes audit outputs into a single decision matrix.
5. Build canonical `TASKS.md` from verified truth; enforce 8-field format.
6. Update root `CLAUDE.md` with required baseline test suites by change type.
7. Perform artifact hygiene (`.gitignore` + untrack noise artifacts).
8. Exit Phase 1 only when all exit criteria are satisfied.

---

## 8. Phase 1 Exit Criteria (Mandatory)

All must be true:

1. Root `CLAUDE.md` and `services/CLAUDE.md` pass cold-start usability.
2. `TASKS.md` exists and all open work is represented as dispatchable 8-field cards.
3. `pending/` is archive-only (no active tracking there).
4. Completion claims are evidence-categorized (confirmed/overclaimed/incomplete/deferred).
5. GitHub sync fragility policy is documented with explicit file scope.
6. Baseline required tests per change type are documented.
7. Workspace artifact noise is cleaned from normal PR signal.

No Phase 2 feature execution should begin until all seven are complete.

---

## 9. Semi-Final Decision

Proceed with execution using `claude-remix-1.md` as the operational playbook and `codex-remix-1.md` as the concise strategic summary.

This gives:
- strong governance,
- low ambiguity execution,
- controlled parallelism,
- and a realistic path to begin agentic development of Workwarrior safely.
