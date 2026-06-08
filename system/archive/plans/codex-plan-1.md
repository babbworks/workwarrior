# Multi-Agent Strategy (Hybrid, Enforced)

This project should run on a strict agent operating system: strong governance from the Orchestrator, strong pre-code risk analysis from Explorers, parallel execution via isolated worktrees, and hard verification gates before merge. The key principle is separation of concerns: no agent both authors and approves the same change, and no task starts without a written contract.

The strategy combines two strengths:
- Operational rigor: hard gates, explicit PR/task contracts, ownership boundaries, and deterministic merge criteria.
- Compounding context: `CLAUDE.md` guidance at repo/subdir level plus retained project memory so new sessions can start cold without re-deriving conventions.

This gives speed and safety simultaneously:
- Speed from parallel workers on disjoint write sets.
- Safety from Explorer risk briefs, verifier independence, and enforced acceptance criteria.
- Maintainability from standardized contracts, canonical status tracking, and docs/help parity gates.

## Role Model

- `Orchestrator`: defines scope, contracts, ownership, gates, and merge decisions.
- `Explorer` (2): read-only impact/risk analysis before implementation.
- `Worker` (2-4): implementation only in assigned write scope.
- `Verifier`: test execution, regression checks, acceptance validation.
- `Simplifier` (conditional): quality tightening for high-risk or large diffs.
- `Release Check` (lightweight gate): checklist/doc/version readiness before marking “complete.”

## Non-Negotiable Gates

- Gate A: no implementation without explicit acceptance criteria.
- Gate B: no merge with failing required tests or unresolved high-severity findings.
- Gate C: no “complete” status unless docs and CLI help text match behavior.
- Gate D: no release-ready claim with critical checklist items unchecked.
- Gate E: no untracked TODO/placeholder in production path; deferred items must be explicitly tracked.

## Task/PR Contract (Required Before Coding)

- Problem statement.
- Allowed files (write scope).
- Required tests and validation commands.
- Rollback plan.
- Risk notes from Explorers.
- Definition of done.

## Parallelization Rules

- Use `agent/<role>/<topic>` branch naming.
- One worktree per active worker stream.
- Parallel only for disjoint write sets.
- Shared core files (`bin/ww`, `lib/shell-integration.sh`, sync libs) default to serialized ownership unless explicitly split.

# Detailed Phase 1 Execution Plan (No File Writes Yet)

## 1. Phase 1 Objective

- Establish the operating system for agentic execution.
- Reconcile project truth (status/docs/code/tests drift) before new feature work.
- Produce dispatch-ready contracts for Phase 2 implementation.

## 2. Phase 1 Deliverables

- Approved role charter and gate checklist.
- Canonical discrepancy report: `pending/*` vs `docs/*` vs code reality.
- Risk map of fragile paths (especially GitHub sync and shared libs).
- Initial task board of agent-sized cards with ownership and acceptance criteria.
- Worktree/branch policy and merge policy confirmed.

## 3. Execution Sequence

- Step 1: Orchestrator opens Sprint 0 with scope freeze on net-new features.
- Step 2: Explorer A audits status/documentation claims.
- Step 3: Explorer B audits implementation reality and test coverage gaps.
- Step 4: Orchestrator merges both briefs into prioritized remediation tracks.
- Step 5: Orchestrator defines 3-5 first implementation contracts (small, disjoint).
- Step 6: Workers are assigned only after contract sign-off.
- Step 7: Verifier defines required test matrix per contract type.
- Step 8: Orchestrator approves Phase 1 exit only when truth-reconciliation is done.

## 4. Explorer A Charter (Read-Only)

- Compare completion claims across `pending/IMPLEMENTATION_STATUS.md`, `pending/OUTSTANDING.md`, `docs/IMPLEMENTATION-COMPLETE.md`, `docs/RELEASE-CHECKLIST.md`.
- Identify contradictory claims, stale dates, and release-readiness overstatements.
- Output: contradiction matrix with severity and suggested canonical source of truth.

## 5. Explorer B Charter (Read-Only)

- Inspect code paths and tests for known high-risk areas.
- Focus on GitHub sync TODO/placeholders, dry-run behavior claims, error handling paths, and docs/help parity.
- Output: code-vs-doc gap list, test coverage map, and highest regression-risk hotspots.

## 6. Orchestrator Synthesis Output

- Priority 1: status reconciliation and canonical tracking model.
- Priority 2: GitHub sync claim hardening (especially dry-run and TODO paths).
- Priority 3: test baseline normalization by change type.
- Priority 4: release checklist hardening and completion criteria.
- Priority 5: runtime artifact hygiene for clean PR signal.

## 7. Phase 1 Acceptance Criteria

- A single agreed truth source for “what is complete.”
- A signed risk register for fragile modules.
- A required test matrix defined for each task class.
- First 3-5 implementation tasks fully contract-defined and assignable.
- Gate checklist operational and attached to every new task/PR.

## 8. Phase 1 Exit / Phase 2 Entry

- Exit Phase 1 only when all above criteria are met.
- Start Phase 2 with parallel worker execution on disjoint scopes under enforced contracts and independent verification.

If you want, I can now draft the exact first 5 task contracts in this format so you can dispatch agents immediately.
