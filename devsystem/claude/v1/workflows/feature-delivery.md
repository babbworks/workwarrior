# Workflow: Standard Feature Delivery (Phase 2+)

Use this workflow for all implementation tasks after Phase 1 is complete. Every task follows this sequence without exception.

---

## Pre-Conditions

- Phase 1 is complete (all exit criteria satisfied)
- `CLAUDE.md`, `services/CLAUDE.md`, `lib/CLAUDE.md`, `tests/CLAUDE.md` are deployed
- Task card exists in TASKS.md with status `pending`
- Gate A is satisfied (acceptance criteria authored by Orchestrator)

---

## Step 1: Orchestrator — Pre-Flight Check

Before dispatching any Builder:

```
[ ] Task card is complete (all 8 fields filled)
[ ] Acceptance criteria are measurable (not "it works" or "tests pass")
[ ] Write scope is specific (no unnecessary files included)
[ ] Write scope is disjoint from all other active tasks (check TASKS.md in-progress entries)
[ ] SERIALIZED files in write scope? If yes: confirm no other active task touches them
[ ] HIGH FRAGILITY files in write scope? If yes: add approval to task card risk notes
[ ] Required tests are specific (actual commands, not categories)
[ ] Rollback path is concrete and reversible
```

If any check fails: update the task card before dispatching.

---

## Step 2: Builder — Pre-Flight Risk Brief

Before writing any code, Builder produces a risk brief using `templates/builder-risk-brief.md`.

Paste the completed brief into the task card's `Risk notes` field.

If the risk brief reveals a need to touch files outside the write scope: **stop and report to Orchestrator**. Do not expand scope. Wait for task card revision.

---

## Step 3: Builder — Implementation

Work in an isolated worktree on branch `agent/builder/<topic>`.

```
Rules during implementation:
- Only modify files in the declared write scope
- Follow all shell scripting standards from CLAUDE.md
- Write or update BATS tests for every changed behavior
- Do not add features, refactor adjacent code, or clean up anything not required
- Run required tests before handing off
```

When implementation is complete:
- Run all required tests from the task card
- Confirm all pass
- Update task status to `in-review`
- Produce a change summary for the Verifier (what changed, why, key decisions)

---

## Step 4: Verifier — Adversarial Review

Verifier uses `templates/verifier-signoff.md`. Runs in sequence:

1. Targeted tests (from task card)
2. Full BATS suite
3. Integration tests (if applicable)
4. Acceptance criteria check (each criterion individually)
5. Write scope audit (verify no files modified outside scope)
6. Simplify pass on all changed files
7. Gate C check (help strings and docs)
8. Gate E check (TODO/FIXME scan)

**If HIGH FRAGILITY files are in scope:** add Step 9 — sync/integration sign-off.

**If diff > 200 lines:** escalate simplify pass to standalone Simplifier agent before completing sign-off.

Verifier produces:
- **PASSED** sign-off → proceed to Step 5
- **FAILED** sign-off → return to Orchestrator with specific findings

**On FAILED sign-off:** Orchestrator decides — fix in current task (reopen, Builder addresses findings) or create new task card for the issue. Either way: new task card, not informal "just fix it".

---

## Step 5: Docs Agent — Task Closure

After Verifier PASSED sign-off:

Docs agent checks and updates as needed:
- Inline `--help` strings (Gate C)
- `services/README.md` (if service changed)
- Root `CLAUDE.md` (if fragility, env vars, or structure changed)
- `services/CLAUDE.md` (if contract changed)
- `lib/CLAUDE.md` (if lib behavior changed)
- `tests/CLAUDE.md` (if test suite changed)
- `docs/usage-examples.md` (if user-facing examples exist)

Docs agent reports completion to Orchestrator.

---

## Step 6: Orchestrator — Merge and Close

Orchestrator confirms:
- Verifier sign-off is PASSED (no open HIGH findings)
- Docs agent has confirmed updates
- `TASKS.md` status can be updated to `complete`

Merge the Builder's worktree branch. Update task status.

If the task revealed new risk information (fragility, edge cases, test gaps): save to project memory.

---

## Parallel Execution

Multiple tasks can run Steps 2–4 simultaneously when:
- Write sets are explicitly disjoint
- No SERIALIZED files overlap
- Orchestrator has verified disjointness before dispatch

Parallel tasks do not coordinate with each other. They communicate through the Orchestrator and through the files they are allowed to touch.

---

## Cycle Time Target

A well-scoped task (1–5 files, clear criteria) should complete Steps 2–6 in one agent session. If a task is taking multiple sessions:
- It may be too large: split at the Orchestrator level
- It may have scope creep: audit the write scope and tighten

---

## Memory Updates After Completion

Save to project memory any:
- Non-obvious implementation decisions
- Fragility information discovered during implementation
- Test patterns that caught real issues
- Scope judgment calls the Orchestrator made

These compound over sessions and reduce re-work.
