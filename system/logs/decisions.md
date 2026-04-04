# Architectural Decisions Log

Running record of non-obvious decisions, direction choices, and resolved debates.
Each entry: date, decision, context, and why — so future sessions don't re-litigate settled ground.

---

## 2026-04-04 — CLAUDE.md and TASKS.md do not belong at project root

**Decision:** TASK-1.1 (deploy root CLAUDE.md), TASK-1.2 (deploy services/CLAUDE.md), and TASK-1.4 (TASKS.md at root) closed as design corrections rather than executed.

**Context:** Phase 1 verify-phase1.sh checked for these files at `/Users/mp/ww/CLAUDE.md` and `/Users/mp/ww/TASKS.md`, following the conventional "repo root = agent entry point" pattern.

**Why closed:** `/Users/mp/ww` is a hybrid — it's both a software project (`bin/`, `lib/`, `services/`) and a user data container (`profiles/`). CLAUDE.md and TASKS.md are dev artifacts. Placing them at the root would put agent context files alongside a user's personal task data and journals. The `system/` directory was explicitly created as the control plane for these files — they already exist there and are already authoritative. Copying them to the root creates a maintenance split without benefit.

**Consequence:** verify-phase1.sh rollout checks for root CLAUDE.md/TASKS.md will always fail. Those checks should be updated to point at `system/CLAUDE.md` and `system/TASKS.md` instead.

---

## 2026-04-04 — `i` and `ww issues` are synonymous entry points to two engines

**Decision:** `i` (shell function) and `ww issues` (bin/ww domain) route identically. `ww issues` added as TASK-SVC-006 output.

**Context:** Pre-flight direction questions asked before implementing TASK-SVC-006. Options were: (A) keep both under `i`, add `ww issues` as alias; (B) split them. User chose A.

**Why:** Consistency with the rest of the CLI — every shell function has a `ww <domain>` counterpart. An AI agent calling `ww` directly (not through a shell) needs `ww issues` to reach the same functionality.

**Consequence:** `i` remains a shell function injected via shell-integration.sh. `ww issues` is implemented independently in bin/ww `cmd_issues()` with identical routing logic. Both must be kept in sync when routing changes.

---

## 2026-04-04 — Bugwarrior is one-way pull only; github-sync is the two-way engine

**Decision:** Messaging across all user-facing surfaces leads with GitHub two-way sync. Bugwarrior is described as a pull engine for GitHub and 20+ other services.

**Context:** User confirmed: bugwarrior has no meaningful capabilities independent of external issue tracking services. It cannot push, create, or update issues — only pull them into TaskWarrior.

**Why:** Leading with bugwarrior's multi-service support buried the most important distinction (one-way vs two-way). GitHub is the primary integration for most users. Framing bugwarrior as a "pull engine" and github-sync as the "two-way engine" clarifies which to use for which purpose.

**Consequence:** configure-issues.sh banner, README-issues.md, `i help`, and `ww issues help` all lead with GitHub + the two-engine model. Don't revert to generic multi-service framing.

---

## 2026-04-04 — Profile import vs restore: distinct operations with different safety contracts

**Decision:** `ww profile import` = create new profile from archive (errors if name already exists). `ww profile restore` = replace existing profile, with mandatory safety backup before any destructive action.

**Context:** TASK-SVC-004 required adding archive-based profile operations. Two semantics were possible — overwrite or new-only.

**Why:** Distinguishing them prevents accidental data loss. Import is safe by default (cannot overwrite). Restore is explicit about its danger and requires the profile to already exist (pointing users to import if it doesn't). The safety backup in restore ensures rollback is always possible.

**Consequence:** Both are now in lib/profile-manager.sh, scripts/manage-profiles.sh, and bin/ww. Do not merge them into a single command with a flag.

---

## 2026-04-04 — Explorer B: three critical data-integrity bugs found, not yet fixed

**Decision:** Logged as TASK-SYNC-002, dispatched as Wave A Priority 2.

**Bugs:**
1. `lib/github-sync-state.sh:182` — bare `mv` after jq transform, no error check. If mv fails, state.json is silently lost.
2. `lib/sync-detector.sh:43–46` — jq failure leaves `changes` as empty string and code continues silently.
3. `lib/profile-manager.sh:1753–1762` — restore deletes original profile with `rm -rf` before confirming `mv` of replacement succeeds. Profile is permanently lost if mv fails.

**Why not fixed immediately:** These are HIGH FRAGILITY files. Fixes require a dedicated Builder + Verifier cycle with tests for each failure path. Rushing them risks introducing new bugs in the sync engine.

**Consequence:** Until TASK-SYNC-002 is complete, `ww profile restore` and all github-sync operations carry known data-integrity risks. Users should ensure they have backups before using restore.

---

## 2026-04-04 — set -euo pipefail missing from all lib/ files

**Decision:** Logged as TASK-SHELL-001, dispatched as Wave A Priority 1.

**Context:** Explorer B found `bin/ww` has only `set -e`. All 24 lib/ files and 6 services/custom/ scripts have no safety flags at all. This means unset variable references silently become empty strings and broken pipes succeed silently.

**Why Priority 1:** This is the foundation under every other fragility finding. Adding `-u` may expose latent bugs (unset variables currently silently passing). Those bugs need to be found and fixed, not bypassed. Doing this before TASK-SYNC-002 means the sync bug fixes will immediately benefit from stricter error propagation.

**Consequence:** TASK-SHELL-001 may reveal additional bugs when `-u` is added. The task card explicitly calls this out: "run bats tests/ after each file group and fix failures before proceeding."

---

## 2026-04-04 — `--json` on i pull suppresses output; on i status wraps it

**Decision:** `i pull --json` → suppresses bugwarrior's stdout/stderr, emits `{"command":"pull","status":"success"}`. `i status --json` → captures github-sync status output as a string field in JSON.

**Context:** Bugwarrior has no native JSON output mode. github-sync has no `--json` flag. AI agent use case requires machine-readable output.

**Why this approach:** The simplest useful implementation for AI consumers. Pull result is pass/fail — a structured boolean is more useful than captured human text. Status output has meaningful content — wrapping it preserves the information while making it parseable.

**Consequence:** `i pull --json` silences all bugwarrior output. If a user needs the raw sync log, they must omit `--json`. `i status --json`'s `output` field contains a human-formatted string — it is not fully structured. Full structured status output would require changes to github-sync.sh (HIGH FRAGILITY, separate task).
