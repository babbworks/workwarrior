# Comparative Analysis: Claude Plan vs Codex Plan

---

## Where They Agree (Strong Signal — Keep All)

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

## Where They Diverge — Point by Point

**1. Role count: Codex=6, Claude=4**

Codex keeps Explorer as distinct agents, Simplifier as conditional, and Release Check as a lightweight gate. Claude absorbed Explorer into Builder pre-flight, Simplifier into Verifier, and dropped Release Check entirely.

The previous hybrid discussion chose 4 roles. That was the right call *for ongoing Phase 2+ feature work* — per-task risk briefs don't need dedicated agents. But for Phase 1 specifically, the Explorer A/B split is correct: the status drift audit and the code/test gap audit are genuinely different analysis tasks, too large for a one-paragraph pre-flight, and best run in parallel. The answer is **context-dependent Explorer deployment**: dedicated for large audit work, absorbed for individual feature tasks. Not a fixed slot, a mode.

Simplifier: Codex's "conditional" framing (not always needed, exists for large diffs) is compatible with Claude's "fold into Verifier checklist." Resolution: Verifier always runs `/simplify` as a checklist step. For diffs over a meaningful threshold, Simplifier runs as a separate agent pass. Not a permanent role, an escalation.

Release Check: Codex calls it "lightweight gate," not a full agent. That's the same as Gate D operationalized. No separate role needed — Gate D with a concrete checklist attached is sufficient.

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

## Items Previously Set Aside — Reassessment

**`lib/CLAUDE.md` (deferred in previous hybrid)**
Previous hybrid said defer. I argued second priority. Codex doesn't mention it. Verdict: keep deferred from Phase 1, but make it a **Phase 2 prerequisite**. Specifically: no Builder task touching `lib/` starts until `lib/CLAUDE.md` exists. It's not a Phase 1 deliverable but it's not indefinitely deferred either. It becomes the first Docs agent task in Phase 2.

**`tests/CLAUDE.md` (deferred in previous hybrid)**
Deferred is correct. Explorer B's test coverage map (Task 1.3b output) provides the content. Write `tests/CLAUDE.md` at the start of Phase 2 using that map.

**Simplifier as separate stage (set aside in previous hybrid)**
Previous hybrid folded it into review. Codex makes it conditional. The right implementation is: Verifier always calls `/simplify` as a checklist step (not a separate agent). For large diffs, Verifier can escalate to a dedicated Simplifier agent. This is finer-grained than either original position.

**Explorer role absorbed into Builder (set aside in previous hybrid)**
Correct for Phase 2+ individual feature tasks. Wrong for Phase 1 audit work. Restore Explorers for audit phases. Context-dependent.

**Memory system (only in Claude plan, never discussed in hybrid)**
Not set aside — just never addressed by Codex. Adopt fully. It's the only mechanism that makes repeated sessions smarter without a briefing prompt.
