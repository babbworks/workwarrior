# Workflow: Standard Feature Delivery (Phase 2+)

Use this workflow for all implementation tasks after Phase 1 is complete. Every task follows this sequence without exception.

---

## Pre-Conditions

- Task card exists in TASKS.md with status `pending`
- Gate A is satisfied (acceptance criteria authored by Orchestrator)
- Session init complete: `eval "$(ww agent init)"` — see `.claude/ww/ww-agent-guidance.md`

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
[ ] If command/help/docs behavior changes: include `config/command-syntax.yaml` in write scope
[ ] Command syntax changes reflected in CSSOT before Builder dispatch
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

**4a. Determine required test suite from change type:**

```bash
# Identify the change type(s) from the task card write scope, then:
bash dev/scripts/select-tests.sh <type>          # list mode — see what's required
bash dev/scripts/select-tests.sh <type> --run    # run mode — execute and gate
```

Change types: `lib` | `service` | `profile` | `shell_integration` | `bin_ww` | `github_sync`

If `select-tests.sh <type> --run` exits non-zero → **Gate B is blocked. Do not sign off.**

CI context: the `sync-engine` CI job runs `test-github-sync.bats` and `test-sync-state.bats` on both macOS and Linux and blocks merge on failure. The `full-suite` job runs all tests as informational. A passing CI is a necessary but not sufficient condition for Gate B — the Verifier still runs `select-tests.sh --run` locally to confirm.

**4b. Remaining checks:**

1. Required test suite (from `select-tests.sh --run` above)
2. Full BATS suite `bats dev/tests/` if not already covered
3. Integration tests (if `github_sync` type — HIGH FRAGILITY path)
4. Acceptance criteria check (each criterion from the task card individually)
5. Write scope audit (verify no files modified outside declared scope)
6. Simplify pass on all changed files
7. Gate C check (help strings, docs, and CSSOT match implementation) — run:
   ```bash
   bash dev/scripts/check-parity.sh
   ```
   Exit code must be `0` (CSSOT syntax lines must be reflected in mapped `ww … help` output).
8. Gate E check (TODO/FIXME scan on changed files)

**If HIGH FRAGILITY files are in scope:** add Step 9 — explicit sync/integration sign-off line.

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
- `dev/tests/CLAUDE.md` (if test suite changed)
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

## Release

Release is not part of feature delivery. See `dev/workflows/release.md`.

---

## Agent Execution Model (token-efficient default)

The handoff sequence is a set of **roles (hats) and gates** — not a mandate to spawn a
separate cold agent per role. Every spawned agent re-derives context (ONBOARDING, CLAUDE,
TASKS, decisions, plus repo reconnaissance) from a cold start. Doing that once per role,
per task, is expensive and redundant when one session already holds the context.

**Default: inline.** The active session wears each hat in sequence and completes
Steps 2–6 in one session (see Cycle Time Target). No-self-approval and the gates are
enforced by running the **Verifier checklist as a distinct, adversarial step with a real
PASS/FAIL** — not by the *identity* of the agent.

**Spawn a fresh, independent agent only when independence is required or clearly adds value:**
- HIGH FRAGILITY files in scope → independent sync/integration verification, **or**
- diff > 200 lines → standalone Simplifier (already required by Step 4), **or**
- write sets are disjoint and parallelism saves wall-clock (see Parallel Execution).

**When you do spawn:** give a scoped prompt (the diff + exact test commands + the card's
acceptance criteria), **cite the design spec rather than restating it**, and continue the
same agent via follow-up messages instead of re-spawning cold.

**Orchestrator authoring:** batch-author related cards in one pass; each card **cites its
spec section** rather than duplicating it. Prefer `wwctl new-task` (template-generated) to
keep cards lean.

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
