# Workflow: Phase 1 Execution

**Objective:** Establish the operating foundation. No new features. No new services.
Produce honest ground truth and dispatch-ready contracts for Phase 2.

---

## Pre-Conditions

Before starting Phase 1:
- [ ] `system/` directory exists with full architecture
- [ ] User has reviewed and approved the ratified strategy
- [ ] No active feature branches exist (Sprint 0 feature freeze is in effect)

---

## Step 1: Sprint 0 Declaration (Orchestrator)

The Orchestrator declares Sprint 0:
- Feature freeze: no new services, features, or lib changes until Phase 1 exits
- Hard gates A–E are active from this point forward
- All work flows through task cards

**Output:** Verbal declaration (no file change needed — gates are active by policy).

---

## Step 2: Deploy CLAUDE.md (Orchestrator, serial)

**Task card:** TASK-1.1

```bash
cp system/CLAUDE.md CLAUDE.md
```

Then do a cold-read validation: read the file as if you have no prior project knowledge. Can you determine:
- What the project does?
- What you can and cannot touch?
- How to run tests?
- Where your task is?

If no: update until the answer is yes. This is the acceptance criterion for TASK-1.1.

Mark TASK-1.1 `complete` in TASKS.md.

---

## Step 3: Deploy services/CLAUDE.md (Orchestrator, serial)

**Task card:** TASK-1.2

```bash
cp system/services-CLAUDE.md services/CLAUDE.md
```

Cold-read validation: can you write a correct Tier 1 service without reading any existing service?

Mark TASK-1.2 `complete` in TASKS.md.

---

## Step 4: Dual Explorer Audit (parallel after Steps 2–3)

Dispatch Explorer A and Explorer B as parallel subagents. Both are read-only.

**Task cards:** TASK-1.3a and TASK-1.3b

### Dispatching Explorer A

Use the Agent tool with the prompt from `roles/explorer.md` (Explorer A section).

Key parameters:
- No worktree (read-only)
- Output: `system/outputs/explorer-a-report.md`
- Template: `templates/explorer-a-output.md`

### Dispatching Explorer B

Use the Agent tool with the prompt from `roles/explorer.md` (Explorer B section).

Key parameters:
- No worktree (read-only)
- Output: `system/outputs/explorer-b-report.md`
- Template: `templates/explorer-b-output.md`

### Running in parallel

Both can run simultaneously — their write sets are disjoint (different output files) and both are read-only on the project.

**Wait for both to complete before Step 5.**

---

## Step 5: Orchestrator Synthesis (serial, after Step 4)

Read both Explorer reports. Produce a synthesis decision:

1. **From Explorer A:** Which tasks are confirmed-complete? Which are overclaimed? Which are genuinely incomplete?
2. **From Explorer B:** What is the test coverage state? What TODOs need task cards? What is the required baseline per change type?
3. **Decision:** Which overclaimed tasks become active task cards? Which are deferred?

Update root `CLAUDE.md` testing section with Explorer B's baseline matrix (amendment to TASK-1.1 — no new task card needed, this is within scope).

---

## Step 6: Build Canonical TASKS.md (Orchestrator, serial)

**Task card:** TASK-1.4

Replace the seeded `TASKS.md` with a fully populated one:
- Completed section: all confirmed-complete tasks with evidence
- Active section: all genuine open work as 8-field task cards
- Deferred section: overclaimed/unscoped items with explicit tracking
- Fragility register: updated from Explorer B hotspot findings

For every TODO/FIXME found by Explorer B in HIGH FRAGILITY files: create a deferred or active task card (Gate E).

Mark TASK-1.4 `complete` in TASKS.md after rebuild.

---

## Step 7: Artifact Cleanup (Builder, serial)

**Task card:** TASK-1.5 / TASK-QUAL-001

Builder runs the cleanup:

```bash
# Untrack already-tracked artifacts (does not delete files on disk)
git rm --cached --ignore-unmatch \
  .DS_Store \
  "profiles/work/.task/taskchampion.sqlite3"

# Run the pre-merge hygiene check to verify no artifacts remain tracked
bash system/scripts/check-artifacts.sh
```

The hygiene check at `system/scripts/check-artifacts.sh` validates:
- No `.DS_Store` files tracked
- No `*.sqlite3` databases tracked
- No `*.log` files tracked
- No profile runtime data tracked (`profiles/*/.config/`, `profiles/*/list/`, `profiles/*/.task/`)
- No `.env` / secrets files tracked

Expected output: `Status: ALL CLEAR`

If violations are found, the script exits non-zero and names each offending path. Use `git rm --cached <path>` to untrack without deleting.

Verify repo state:
```bash
git ls-files '*.DS_Store' '*.sqlite3'  # should be empty
git status                              # should be clean after commit
```

Mark TASK-1.5 / TASK-QUAL-001 `complete` in TASKS.md.

---

## Step 8: Phase 1 Exit Validation (Orchestrator)

Check all seven exit criteria:

- [ ] Root `CLAUDE.md` passes cold-read test
- [ ] `services/CLAUDE.md` passes cold-read test
- [ ] `TASKS.md` is rebuilt (not seeded) with all open work as 8-field cards
- [ ] `pending/` has no new files
- [ ] Every completion claim categorized with evidence (Explorer A report exists)
- [ ] GitHub sync fragility documented with named files and policy in CLAUDE.md + TASKS.md
- [ ] Test baseline per change type defined in root `CLAUDE.md`
- [ ] `git status` is clean

If all pass: **Phase 1 is complete. Proceed to Phase 2.**

If any fail: create a task card for the gap. Do not declare Phase 1 complete.

---

## Phase 2 Entry Conditions

Before dispatching any Phase 2 Builder tasks:

1. Docs agent authors `lib/CLAUDE.md` from Explorer B output
2. Docs agent authors `tests/CLAUDE.md` from Explorer B coverage map
3. Orchestrator picks first 2–3 task cards from TASKS.md with disjoint write sets
4. Orchestrator confirms write sets are disjoint and no SERIALIZED files overlap
5. Dispatch Builders in parallel worktrees: `agent/builder/<topic>`
