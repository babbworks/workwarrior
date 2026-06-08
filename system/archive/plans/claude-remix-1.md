# Comparative Analysis: Claude Plan vs Codex Plan

### Where They Agree (Strong Signal — Keep All)

Both plans independently converged on:
- Identical five hard gates (A–E), word-for-word equivalent in intent
- Branch naming: `agent/<role>/<topic>`
- Parallel execution only on disjoint write sets
- Orchestrator owns merge authority; no self-approval
- `pending/` replaced by a single canonical task source
- Status reconciliation before any new feature work
- GitHub sync treated as the highest-risk surface

When two independently produced plans agree on something, treat it as load-bearing. None of these points are up for debate.

---

### Where They Diverge — Point by Point

**1. Role count: Codex=6, Claude=4**

Codex keeps Explorer as distinct agents, Simplifier as conditional, and Release Check as a lightweight gate. Claude absorbed Explorer into Builder pre-flight, Simplifier into Verifier, and dropped Release Check entirely.

The previous hybrid discussion chose 4 roles. That was the right call *for ongoing Phase 2+ feature work* — per-task risk briefs don't need dedicated agents. But for Phase 1 specifically, the Explorer A/B split is correct: the status drift audit and the code/test gap audit are genuinely different analysis tasks, too large for a one-paragraph pre-flight, and best run in parallel. The answer is **context-dependent Explorer deployment**: dedicated for large audit work, absorbed for individual feature tasks. Not a fixed slot, a mode.

Simplifier: Codex's "conditional" framing (not always needed, exists for large diffs) is compatible with Claude's "fold into Verifier checklist." Resolution: Verifier always runs `/simplify` as a checklist step. For diffs over a meaningful threshold, Simplifier runs as a separate agent pass. Not a permanent role, an escalation.

Release Check: Codex calls it "lightweight gate," not a full agent. That's the same as Gate D operationalized. No separate role is needed — Gate D with a concrete checklist attached is sufficient.

**Final role model:** Orchestrator, Explorer (context-deployed), Builder, Verifier (with Simplifier embedded), Docs. Five in Phase 1, four in Phase 2+.

---

**2. Explorer specificity — Codex wins here**

Codex names specific files for Explorer A and Explorer B. Claude's Task 1.3 covers the same ground but as one undifferentiated task with less specific file references. The Codex split is strictly better:

- **Explorer A** (docs/status drift): `pending/IMPLEMENTATION_STATUS.md`, `pending/OUTSTANDING.md`, `docs/IMPLEMENTATION-COMPLETE.md`, `docs/RELEASE-CHECKLIST.md`, all `pending/*SUMMARY*` files — produces a contradiction matrix with severity
- **Explorer B** (code/test reality): GitHub sync TODO paths, dry-run behavior claims, error handling gaps, docs/help parity, test coverage by module — produces a code-vs-doc gap list plus test coverage map

These run in parallel. Each produces a distinct output that feeds the Orchestrator's synthesis. Adopt this split verbatim.

---

**3. Serialization callouts — Codex wins here**

Codex explicitly names files that default to serialized ownership: `bin/ww`, `lib/shell-integration.sh`, sync libs. Claude states only the general principle. Concrete named files belong in both root `CLAUDE.md` and the parallelization rules. Adopt Codex's specific callouts.

---

**4. Task/PR contract fields — merge both**

Codex: problem statement, write scope, required tests, rollback plan, risk notes from Explorers, definition of done (6 fields).
Claude: goal, acceptance criteria, write scope, tests required, rollback, fragility flags, status (7 fields).

These are complementary, not competing. The unified card format should be 8 fields: **goal, acceptance criteria, write scope, tests required, rollback, fragility flags, risk notes (from Explorer output), status**. "Risk notes from Explorers" is the formal handoff artifact — it should be a named field, not implied.

---

**5. CLAUDE.md and Memory System — Claude wins here**

Codex mentions "compounding context" and `CLAUDE.md` as a principle but provides no implementation plan. Claude provides: priority order (root → services → lib → tests), what each file covers, cold-read acceptance criteria, and how the memory system integrates (risk briefs → project memories, Verifier failures → feedback memories, Orchestrator decisions → project memories). Adopt Claude's approach entirely. Codex has no answer to this.

---

**6. Phase 1 task structure — Claude's format, Codex's Explorer split**

Claude's numbered tasks with owner/steps/acceptance criteria/sequence diagram are more actionable than Codex's 8-step governance sequence. But Codex's Explorer A/B split is better than Claude's single Task 1.3. Resolution: keep Claude's task card format, split Task 1.3 into 1.3a and 1.3b using Codex's charters. Task 1.5 (test strategy normalization) is absorbed into Explorer B's output — it's not a separate task, it's a named deliverable of 1.3b.

---

### Items Previously Set Aside — Reassessment

**`lib/CLAUDE.md` (deferred in previous hybrid)**
Previous hybrid said defer. I argued second priority. Codex doesn't mention it. Verdict: **keep deferred from Phase 1, but make it a Phase 2 prerequisite**. Specifically: no Builder task touching `lib/` starts until `lib/CLAUDE.md` exists. It's not a Phase 1 deliverable but it's not indefinitely deferred either. It becomes the first Docs agent task in Phase 2.

**`tests/CLAUDE.md` (deferred in previous hybrid)**
Deferred is correct. Explorer B's test coverage map (Task 1.3b output) provides the content. Write `tests/CLAUDE.md` at the start of Phase 2 using that map.

**Simplifier as separate stage (set aside in previous hybrid)**
Previous hybrid folded it into review. Codex makes it conditional. The right implementation is: Verifier always calls `/simplify` as a checklist step (not a separate agent). For large diffs, Verifier can escalate to a dedicated Simplifier agent. This is finer-grained than either original position.

**Explorer role absorbed into Builder (set aside in previous hybrid)**
Correct for Phase 2+ individual feature tasks. Wrong for Phase 1 audit work. Restore Explorers for audit phases. Context-dependent.

**Memory system (only in Claude plan, never discussed in hybrid)**
Not set aside — just never addressed by Codex. Adopt fully. It's the only mechanism that makes repeated sessions smarter without a briefing prompt.

---

## Ratified Strategy

### Operating Model

Two-layer architecture: **governance control plane** (Orchestrator authority, explicit contracts, hard gates, independent verification, no self-approval) over **execution substrate** (CLAUDE.md context files, memory accumulation, worktree isolation, canonical task source).

### Roles

| Role | Deployed | Scope |
|---|---|---|
| Orchestrator | Always | Backlog, contracts, merge authority, gate enforcement |
| Explorer | Audit phases + large analysis | Read-only risk briefs; absorbed into Builder pre-flight for individual feature tasks |
| Builder | Always (implementation) | Implements within explicit write scope; produces risk brief before any file change |
| Verifier | Always (post-implementation) | Adversarial test execution + `/simplify` checklist step; can escalate Simplifier for large diffs |
| Docs | Always (task closure) | CLAUDE.md files, docs/, help strings; runs after merge |

No self-approval. Orchestrator never implements. Verifier never implements.

### Hard Gates (unchanged, both plans agreed)

- **Gate A** — No implementation without Orchestrator-authored acceptance criteria
- **Gate B** — No merge with failing tests or unresolved high-severity findings
- **Gate C** — No "complete" without docs and help strings aligned to behavior
- **Gate D** — No release claim without signed release checklist (not a role, a checklist)
- **Gate E** — No untracked TODO in production path; every deferred item has a task card

### Task Card Format (unified, 8 fields)

```
## TASK-XXX: [Title]
Goal:                 [one sentence]
Acceptance criteria:  [measurable, Orchestrator-authored]
Write scope:          [exact files permitted]
Tests required:       [specific BATS or integration commands]
Rollback:             [what to undo and how]
Fragility:            [any high-risk flags]
Risk notes:           [Explorer output, if applicable]
Status:               pending | in-progress | blocked | complete
```

### Parallelization Rules

- Parallel only when write sets are explicitly disjoint, verified by Orchestrator before dispatch
- Files that default to serialized ownership: `bin/ww`, `lib/shell-integration.sh`, all `lib/github-*.sh`, all `lib/sync-*.sh`
- Branch naming: `agent/<role>/<topic>`
- One worktree per active Builder stream

### Execution Substrate

- **Root `CLAUDE.md`** — architecture, agent model, shell standards, env vars, service contract, fragility markers, gate list, TASKS.md location
- **`services/CLAUDE.md`** — discovery mechanics, template tiers, exit code contract, naming, prohibited patterns
- **`lib/CLAUDE.md`** — Phase 2 prerequisite, not Phase 1 deliverable
- **`tests/CLAUDE.md`** — Written using Explorer B output at Phase 2 start
- **Memory system** — Builder risk briefs → project memories; Verifier failures → feedback memories; Orchestrator decisions → project memories
- **`TASKS.md` at root** — single canonical source; `pending/` becomes archive

### GitHub Sync Fragility Policy

Files: `lib/github-*.sh`, `lib/sync-*.sh`, `services/custom/github-sync.sh`. Not off-limits. Requires: explicit Orchestrator approval, extended risk brief, integration tests against test profile (not just unit tests), dedicated Verifier sign-off line for sync behavior.

---

## Ratified Phase 1 Execution Plan

**Objective:** Establish operating foundation. No new features. No new services. Produce honest ground truth and dispatch-ready contracts for Phase 2.

---

### Task 1.1 — Root `CLAUDE.md`
**Owner:** Orchestrator | **Worktree:** No

Content: project purpose, directory map, agent model + handoffs, shell scripting standards, env vars, service contract summary, fragility markers (named files), testing requirements, five gates, TASKS.md location.

**Acceptance criteria:** A cold-started agent can read it and know architecture, what it can/cannot touch, how to run tests, and where its task is.

---

### Task 1.2 — `services/CLAUDE.md`
**Owner:** Orchestrator | **Worktree:** No

Content: discovery mechanics, profile-level override inheritance, three template tiers, exit code contract, naming conventions, help string format, what Docs must update on service change, prohibited patterns.

**Acceptance criteria:** A Builder can write a correct discoverable service without reading any existing service as reference.

---

### Tasks 1.3a + 1.3b — Dual Explorer Audit *(parallel after 1.1 + 1.2)*
**Owner:** Two Explorer agents | **Worktree:** No (read-only)

**Explorer A — Docs/Status Drift:**
Reads: `pending/IMPLEMENTATION_STATUS.md`, `pending/OUTSTANDING.md`, `pending/*SUMMARY*`, `docs/IMPLEMENTATION-COMPLETE.md`, `docs/RELEASE-CHECKLIST.md`, `docs/github-sync-*.md`.
Produces: contradiction matrix (confirmed complete / overclaimed / undocumented / genuinely incomplete) with severity rating per item.

**Explorer B — Code/Test Reality:**
Reads: all `lib/github-*.sh` and `lib/sync-*.sh` for TODOs; all `tests/` files for coverage; all services for help/docs parity.
Produces: code-vs-doc gap list, test coverage map by module, required baseline suite per change type (lib / service / profile / sync), highest regression-risk hotspots.

**Acceptance criteria:** Every completion claim is categorized with evidence. Every test coverage gap is classified (critical / important / deferred). Required test baseline per change type is defined.

---

### Task 1.4 — Canonical `TASKS.md`
**Owner:** Orchestrator | **Worktree:** No | **Depends on:** 1.3a + 1.3b

Synthesizes both Explorer outputs. Sections: Completed (evidence-backed), Active (task cards, 8-field format), Deferred (explicit, not forgotten), Fragility Register (named files + policy). Test baseline definition from Explorer B goes into root `CLAUDE.md` as an amendment to Task 1.1.

**Rules:** `pending/` is now archive-only. Only Orchestrator updates status fields. Gate E: every deferred production TODO has a card here.

**Acceptance criteria:** Every open task has a dispatchable card. No open items in `pending/` lack a corresponding card. Fragility register names specific files.

---

### Task 1.5 — Artifact Cleanup
**Owner:** Builder | **Worktree:** No | **Depends on:** 1.4

**Write scope:** `.gitignore` only (plus `git rm --cached` for tracked artifacts).
Adds: macOS artifacts, `.task/taskchampion.sqlite3`, `github-sync/` logs, generated sync config, profile list data.

**Acceptance criteria:** `git status` on clean working tree shows none of: `.DS_Store`, `.sqlite3`, sync logs, generated config. Future PRs carry no artifact noise.

---

### Sequence

```
1.1 Root CLAUDE.md          [Orchestrator, serial]
1.2 services/CLAUDE.md      [Orchestrator, serial]
        │
        ├── 1.3a Explorer A  [parallel, read-only]
        └── 1.3b Explorer B  [parallel, read-only]
                │
        1.4 TASKS.md         [Orchestrator, serial, synthesizes both]
                │
        1.5 Artifact Cleanup [Builder, serial]
```

---

### Phase 1 Exit Criteria

All must be true before Phase 2 begins:

1. Root `CLAUDE.md` and `services/CLAUDE.md` pass cold-read test
2. `TASKS.md` exists with all open tasks as 8-field dispatchable cards
3. `pending/` is archive-only
4. Every completion claim is categorized with evidence (confirmed / overclaimed / incomplete)
5. GitHub sync fragility documented with named files and policy in both `CLAUDE.md` and `TASKS.md` fragility register
6. Required test baseline per change type defined and written into root `CLAUDE.md`
7. `git status` shows no artifact noise

Phase 2 entry: first Builder tasks dispatched in parallel worktrees against disjoint write sets, each with an Orchestrator-issued task card meeting the 8-field format.
