Comparison complete. `claude-plan-1.md` is the stronger execution document; `codex-plan-1.md` is the stronger governance skeleton. The right move is to ratify a merged version with `claude-plan-1.md` as the base and a few governance upgrades from `codex-plan-1.md`.

Primary sources reviewed: [claude-plan-1.md](/Users/mp/ww/system/plans/claude-plan-1.md), [codex-plan-1.md](/Users/mp/ww/system/plans/codex-plan-1.md).

**Assessment**
- `claude-plan-1.md` wins on operational detail: concrete tasks, sequencing, acceptance criteria, and immediate repo-specific risk handling.
- `codex-plan-1.md` wins on clean control-plane framing: explicit non-negotiable gates and role clarity with less process noise.
- Both correctly converge on the essentials: disjoint write-set parallelism, contract-before-code, independent verification, and docs/help parity.

**Set-Aside Approaches Reassessed**
- Separate dedicated `Explorer` role remains valid for high-risk work. Keep it for audits and fragile domains.  
- Builder-embedded risk brief is also valid for normal work. Use both: explicit Explorer for risky/cross-cutting tasks, Builder brief for standard tasks.
- Mandatory standalone `Simplifier` is over-ceremonial. Keep as conditional quality pass for large diffs or shared-lib edits.
- Full-time separate `Release` agent is unnecessary for current scale, but release gating is still mandatory. Keep release as a gate/checklist, not a permanent role.
- “GitHub sync fully off-limits” is too rigid. Better policy is “high-fragility + explicit approval + stronger test requirements.”
- Converting all status to one canonical tracker is valid and should proceed, but only after reconciliation audit to avoid canonizing incorrect state.

**Ratified Strategy**
- Governance model: Orchestrator authority, no self-approval, hard gates A-E retained as written.
- Role set: Orchestrator, Builder, Verifier, Docs, plus conditional Explorer and conditional Simplifier.
- Execution substrate: `CLAUDE.md` context files, worktree isolation, branch naming `agent/<role>/<topic>`, canonical task cards.
- Quality system: PR/task contract required before coding, verifier-owned pass/fail signoff, Gate C and Gate E strictly enforced.
- Fragility policy: GitHub sync is high-fragility with elevated approval/test bar, not frozen.

**Ratified Phase 1 Plan**
1. Orchestrator initializes Sprint 0 with feature freeze and declares hard gates active.
2. Create foundational context docs in order: root `CLAUDE.md`, then `services/CLAUDE.md`.  
3. Run two parallel read-only audits:
1. Status/doc reconciliation (`pending/*` vs `docs/*` vs implementation reality).
2. Test coverage and baseline-by-change-type audit.
4. Orchestrator publishes a reconciliation decision set: confirmed complete, overclaimed, incomplete, deferred.
5. Establish canonical `TASKS.md` from audited truth; mark `pending/` as archive-only.
6. Define baseline required test suites per change type and bind them into `CLAUDE.md` operating rules.
7. Run artifact hygiene pass (`.gitignore` + untrack noise) so PR signal is clean.
8. Phase 1 exits only when canonical status, test baselines, fragility rules, and clean workspace criteria are all satisfied.

**Go/No-Go Decision**
- Go with hybrid ratification now.
- Use [claude-plan-1.md](/Users/mp/ww/system/plans/claude-plan-1.md) as execution blueprint.
- Apply governance tightening from [codex-plan-1.md](/Users/mp/ww/system/plans/codex-plan-1.md): hard gates A-E, explicit no self-approval, and serialized ownership for shared core files.
