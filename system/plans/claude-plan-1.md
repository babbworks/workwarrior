# Workwarrior: Multi-Agent Strategy and Phase 1 Execution Plan

---

## Part 1: The Operating Strategy

### Philosophy

This project will be developed under a **strict multi-agent operating model** with two distinct layers: a **governance control plane** that owns authority and quality enforcement, and an **execution substrate** that gives every agent session the context it needs to work autonomously. Neither layer is optional. Without governance you get speed without correctness. Without the execution substrate you get rules without agents that can actually follow them cold.

The objective is faster delivery with lower regression risk, deterministic handoffs, and a system that compounds in capability over time — not just a checklist.

---

### Roles (Lean Four)

**Orchestrator**
Owns the backlog, acceptance criteria, scope definition, merge decisions, and task card authoring. The Orchestrator never implements code it then approves. It reads, plans, assigns, reviews, and decides. When something is ambiguous — scope, ownership, risk — the Orchestrator resolves it before work starts, not during.

**Builder**
Implements isolated work slices within an explicitly scoped write set. Before touching any file, the Builder produces a one-paragraph risk brief covering: what existing behavior could be affected, which tests already cover the area, and what the rollback path is if the implementation fails. This absorbs the Explorer role without adding ceremony. Builders work in isolated worktrees on named branches. They do not approve their own work.

**Verifier**
Runs tests, linting, and behavioral checks against acceptance criteria. The Verifier's job is adversarial — it is looking for ways the implementation fails, not confirming it works. The Verifier runs in sequence: targeted tests first, then integration suite, then regression spot checks, then a `/simplify` pass on changed files (this absorbs the Simplifier role into a concrete checklist step rather than a vague "code review"). The Verifier produces a signed-off checklist or a failure report. Nothing merges without the former.

**Docs**
Updates `CLAUDE.md` files, `docs/`, service `README.md` files, and help strings after a feature is verified. Docs runs after merge, not before, unless a Gate C violation is flagged (docs misaligned with implementation). Docs is the last agent in the chain and the signal that a task is fully closed.

---

### Execution Substrate

**CLAUDE.md Files**
Machine-readable project context baked into the repo itself. Every agent session inherits this without needing a briefing prompt. CLAUDE.md files cover architecture, contracts, standards, fragility markers, and what agents are and are not allowed to do in each directory. Implemented in priority order: root first, then `services/`, then `lib/` (before any lib work begins), then `tests/` last. This is the highest-leverage single investment — a one-time cost that pays on every subsequent session.

**Memory System**
Risk briefs produced by Builders accumulate as project memories so future sessions don't re-discover the same risks. Verifier failure patterns become feedback memories. Orchestrator decisions on scope or fragility become project memories. The memory system is what makes the strategy compound — each session makes future sessions smarter about this specific codebase.

**Worktrees and Branch Naming**
All parallel implementation runs in isolated git worktrees via the Agent tool with `isolation: "worktree"`. Branch naming convention: `agent/<role>/<topic>` (e.g., `agent/builder/profile-stats`, `agent/verifier/github-sync-audit`). Worktrees are automatically torn down if no changes are made. Parallel work is only permitted when write sets are explicitly disjoint — verified before agents start, not assumed.

**Task Cards**
Every task dispatchable to an agent has a canonical card format:

```
## TASK-XXX: [Title]
Goal: [one sentence]
Acceptance criteria: [measurable]
Write scope: [exact files]
Tests required: [specific]
Rollback: [what to undo]
Fragility: [any flags]
Status: pending | in-progress | blocked
```

All task cards live in one canonical file (`TASKS.md` at root). `pending/` becomes archive-only. No drift between multiple status documents.

---

### Hard Quality Gates

These are non-negotiable checkpoints. Work cannot advance past a gate without explicit satisfaction.

- **Gate A** — No implementation without explicit acceptance criteria authored by the Orchestrator.
- **Gate B** — No merge with failing tests or unaddressed high-severity Verifier findings.
- **Gate C** — No task marked "complete" unless docs and command help strings are aligned with the implementation.
- **Gate D** — No release (even minor) with unchecked items in the release checklist.
- **Gate E** — No hidden TODO or placeholder in any production code path unless explicitly tracked as a deferred task card in `TASKS.md`.

---

### Parallelization Rules

- Parallel work is allowed when and only when write sets are disjoint.
- The Orchestrator verifies disjointness before dispatching parallel agents.
- If write sets overlap — even partially — the work is serialized.
- Parallel Builders do not coordinate with each other; they coordinate through the Orchestrator and through the files they are allowed to touch.

---

### GitHub Sync Fragility Policy

GitHub sync (`lib/github-*.sh`, `lib/sync-*.sh`, `services/custom/github-sync.sh`) is not off-limits but is marked **high-fragility**. Any task touching these files requires:
1. Explicit Orchestrator approval before a Builder starts
2. A more thorough risk brief than standard
3. Integration tests run against a test profile, not just unit tests
4. An explicit sign-off line in the Verifier checklist for sync behavior specifically

---

## Part 2: Phase 1 Execution Plan

Phase 1 is entirely foundational. No new features. No new services. The objective is to bring the project into a state where the multi-agent model can operate correctly — which requires honest ground truth about what is actually built, what is actually tested, and what agents need to know to work here safely.

---

### Task 1.1 — Write Root `CLAUDE.md`

**Owner:** Orchestrator (written in main session, no worktree needed)

**Content to cover:**
- Project purpose in two sentences
- Directory map: what each top-level directory is for, what belongs where, what to never create here
- The four-role agent model and how handoffs work
- Shell scripting standards: bash not sh, `set -euo pipefail` pattern, error propagation via return codes not exit traps, logging via `lib/logging.sh` not raw echo
- Environment variables every agent can rely on (`WARRIOR_PROFILE`, `WORKWARRIOR_BASE`, `TASKRC`, `TASKDATA`, `TIMEWARRIORDB`)
- Service contract summary: how `ww` discovers and invokes services, what the exit code contract is, what help string format is required
- Fragility markers: GitHub sync files (high-fragility), profile data directories (never modify directly), `.DS_Store` and generated artifacts (never commit)
- Testing requirement: every change must pass existing BATS suite; new behavior requires new BATS test
- The five hard gates, stated plainly
- Where the canonical task list lives (`TASKS.md`)

**Acceptance criteria:** An agent dropped into this repo cold can read `CLAUDE.md` and know the architecture, what it can and cannot touch, how to run tests, and where to find its task.

---

### Task 1.2 — Write `services/CLAUDE.md`

**Owner:** Orchestrator (written in main session)

**Content to cover:**
- Service discovery mechanics: how `ww` scans for executables, how profile-level services shadow global ones
- The three service template tiers and when to use each (basic script, with templates, with libs)
- Required elements: help string format, exit code contract (0 success, 1 user error, 2 system error), logging calls via lib
- Naming conventions: file names, function names, argument patterns
- How to add a new service category vs adding to an existing one
- What the Docs agent must update when a service changes: `services/README.md`, inline help, any relevant `docs/` file
- Prohibition: services must not write to profile directories directly — they invoke the appropriate lib functions

**Acceptance criteria:** A Builder agent can write a correct, discoverable service script without reading `services/README.md` or any existing service as a reference.

---

### Task 1.3 — Status Reconciliation Audit

**Owner:** Explorer pass run by Orchestrator (read-only, no worktree)

This is the most important Phase 1 task from a correctness standpoint. The project has multiple overlapping status documents that have drifted from each other and from the actual implementation.

**Steps:**
1. Read `pending/IMPLEMENTATION_STATUS.md` — extract every task claimed as complete
2. Read `pending/OUTSTANDING.md` — extract every open item
3. Read all files in `pending/` matching `*SUMMARY*` — extract completion claims
4. Read `docs/GITHUB-SYNC-README.md` and `docs/github-sync-integration-summary.md` — extract feature claims
5. For each "complete" claim, verify: does the implementation file exist? Does it do what the claim says? Is there a test? Does the test pass?
6. For GitHub sync specifically: identify every TODO comment in `lib/github-*.sh` and `lib/sync-*.sh`; identify dry-run paths that exist in docs but may not be implemented; identify tag sync references
7. Produce a reconciliation report: **confirmed complete**, **overclaimed** (docs say done, code doesn't support it), **undocumented** (code exists, not claimed), **genuinely incomplete**

**Output:** A structured reconciliation report that feeds directly into Task 1.4.

**Acceptance criteria:** Every task in `pending/IMPLEMENTATION_STATUS.md` is categorized with evidence. No task moves to `TASKS.md` as "complete" without verified implementation.

---

### Task 1.4 — Build Canonical `TASKS.md`

**Owner:** Orchestrator, using reconciliation report from Task 1.3

**Structure:**
- **Completed** section: tasks confirmed complete with implementation evidence
- **Active** section: remaining open tasks reformatted as agent task cards
- **Deferred** section: items explicitly not in current scope
- **Fragility register**: list of high-fragility files with their policy

**Rules for `TASKS.md`:**
- `pending/` directory becomes read-only archive — nothing new written there
- `TASKS.md` is the single source of truth
- Orchestrator updates status fields; no other agent touches this file
- Gate E applies: any deferred TODO in production code must have a corresponding card here

**Acceptance criteria:** Every open task has a card. Every card is dispatchable to a Builder without additional context. No open items exist in `pending/` that are not represented in `TASKS.md`.

---

### Task 1.5 — Test Strategy Normalization

**Owner:** Verifier (read-only audit pass)

The current test suite is inconsistent — some areas have BATS unit tests, some have integration tests, some have manual test scripts, and some have nothing. Before new features are built, the baseline must be defined.

**Steps:**
1. Inventory all test files in `tests/`: what they cover, what they don't, last known run status
2. Identify which lib files have no test coverage
3. Identify which services have no test coverage
4. Classify each gap as: **critical** (must have test before any change to that area), **important** (should have test in current sprint), **deferred** (acceptable gap for now)
5. Define the required baseline suite per change type:
   - lib change → which BATS suites must pass
   - service change → which integration tests must pass
   - profile change → which isolation tests must pass
   - GitHub sync change → full integration suite required

**Output:** A test coverage map and the "required baseline suite" definition that goes into root `CLAUDE.md` (Task 1.1 should reference this once known).

**Acceptance criteria:** Every Builder and Verifier agent knows exactly which tests to run for a given change type without asking.

---

### Task 1.6 — Artifact Cleanup

**Owner:** Builder (simple, low risk, no worktree needed)

**Problem:** `.DS_Store` files, generated profile data (`.task/taskchampion.sqlite3`), and sync logs are currently tracked or showing as modifications. These must never appear in PR signal.

**Steps:**
1. Audit `.gitignore` — add all macOS artifacts, generated task data, sync logs, debug output
2. Remove tracked `.DS_Store` files from git index (without deleting the files)
3. Ensure `profiles/work/.task/github-sync/` logs are gitignored
4. Ensure `profiles/work/.config/` is gitignored if it contains generated config
5. Verify `profiles/work/list/` is appropriately ignored or intentionally tracked

**Write scope:** `.gitignore` only (plus `git rm --cached` for already-tracked artifacts)

**Acceptance criteria:** `git status` on a clean working tree shows no `.DS_Store`, no `.sqlite3`, no sync logs. Future PRs will not have noise in their diffs.

---

### Phase 1 Sequence and Parallelization

```
Session start
│
├── [Serial] 1.1 Root CLAUDE.md           (Orchestrator, ~30 min)
├── [Serial] 1.2 services/CLAUDE.md       (Orchestrator, ~20 min)
│
├── [Parallel, after 1.1 + 1.2 drafted]
│   ├── 1.3 Status Reconciliation Audit   (Explorer pass, read-only)
│   └── 1.5 Test Strategy Normalization   (Verifier pass, read-only)
│
├── [Serial, after 1.3] 1.4 Build TASKS.md     (Orchestrator)
│
└── [Serial, after 1.4] 1.6 Artifact Cleanup   (Builder, minimal risk)
```

Tasks 1.3 and 1.5 are parallel because both are read-only with no write conflicts. Everything else is serial because each step feeds the next.

---

### Phase 1 Exit Criteria

Phase 1 is complete when all of the following are true:

- Root `CLAUDE.md` and `services/CLAUDE.md` exist and pass a cold-read test (an agent with no prior context can work from them)
- `TASKS.md` exists with all open tasks as dispatchable cards
- `pending/` is archive-only with nothing new written there
- Every open task's true status is known (confirmed, overclaimed, or genuinely incomplete)
- GitHub sync fragility is documented with specific file names and policy
- Test baseline per change type is defined and referenced in `CLAUDE.md`
- `git status` shows no artifact noise

Only after Phase 1 exits does feature implementation begin. Phase 2 picks up the first batch of task cards from `TASKS.md`, with Builders dispatched in parallel worktrees against disjoint write sets.
