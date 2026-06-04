# Architectural Decisions Log

Running record of non-obvious decisions, direction choices, and resolved debates.
Each entry: date, decision, context, and why — so future sessions don't re-litigate settled ground.

---

## 2026-05-02 — Installer v0.2: multi-instance architecture, companion functions, 5 bug fixes

**Decision:** Complete redesign of installer to support 6 presets, per-instance shell isolation, and `@instance` dispatch.

**Key choices:**

- **6-preset taxonomy** (`basic`, `direct`, `multi`, `hidden`, `isolated`, `hardened`): `basic` adds only a source block to rc; `direct` adds a launcher; `multi`/`hardened` write a full bootstrap with registry. `hidden` = `multi` but visibility hidden in `instance list`. `isolated` = launcher only, no registry. `plain` deprecated → `basic` with warning.

- **Command-specific rc markers**: All installs previously used `# --- Workwarrior Installation ---`. With coexisting installs this caused idempotency false-positives (second install found first install's marker, skipped). Fixed: markers now include command name — `# --- Workwarrior Installation (basic1) ---`. Old generic markers still recognized by `remove_ww_from_shell_rc` for backward compat.

- **Companion activation functions** (`write_instance_function()`): For standalone presets (basic/direct/isolated), a shell function is written to `~/.config/ww/instance-functions.sh`. The function is self-contained — no `use_task_profile` call (which uses stale `PROFILES_DIR`). Instead it exports `TASKRC`/`TASKDATA`/`TIMEWARRIORDB` directly from hardcoded install path. Sourced explicitly after `ww-init.sh` source line to bypass the `WW_INITIALIZED` guard.

- **`ww()` no-args = activate last instance**: Previously called with no args showed help. Now reads `~/.config/ww/last-instance` and activates that instance (or `main` if not found). Instance id written to that file on every `ww @instance` activation.

- **Prompt prefix uses registry check**: `_ww_prompt_prefix()` now: empty when no profile active; `ww|instance:profile` for registry-registered instances; `instance|profile` for standalone. Previously showed `ww|none` always.

- **`_ww_apply_prompt_prefix()` uses regex detection**: Uses `=~ ^[a-z][a-z0-9_-]*\|` to detect and strip ww-style prefix on deactivation, instead of hardcoded `ww|*` glob (which would miss standalone instance prefixes like `basic1|`).

- **Production migrated to `~/wwv02`**: Legacy `~/ww` eliminated. 23 profiles consolidated into new multi-instance install. Shell configs rewritten. GitHub package snapshot at `~/wwv02-package/`.

- **Default profile renamed `main` → `default`**: `install.sh` `create_default_main_profile()` now creates `default` profile, not `main`.

- **Multi-anchor registry isolation**: `WW_CONFIG_HOME` computed from `COMMAND_NAME` after arg parsing — `ww` anchor → `~/.config/ww/`, `hub` anchor → `~/.config/hub/`. Backward compatible.

**Why not keep use_task_profile in companion functions:** `use_task_profile()` reads `PROFILES_DIR` which is set at ww-init.sh source time. When two installs coexist, the last-sourced ww-init.sh wins, so a standalone's companion function would use the anchor's profiles dir. Self-contained env var export sidesteps this entirely.

---

## 2026-04-25 — Browser header restructure: resource slot unified, green bar removed, stat-context-bar removed

**Decision:** Three persistent UI complaints resolved in one header pass.

**Changes:**
- `active-task-pill` (green flex-1 element between title and stats) removed from `header-row1`. It expanded to fill available space, creating a green bar effect the user found visually disruptive. Active-task state is still reflected via `stat-tasks-count` highlight class.
- `header-row2` / `#stat-context-bar` (the secondary text bar showing "pending: N · active: N") removed entirely. User had requested this removal multiple times across sessions.
- All per-section `section-resource-bar` divs removed from Tasks, Times, Journals, Lists. The single `#header-resource-slot` in `header-row1` now serves all sections — `refreshResourceSelectors` shows/hides it on section switch.
- `header-title-group` wrapper added so the title and resource dropdown are co-located as a flex unit with `margin-right: auto`, keeping stats pushed to the right edge.
- `renderResourceSelector` now always renders the `+` button even when no resources exist (previously returned empty if `names.length === 0`, leaving users unable to create the first resource).

**Why not keep the stat-context-bar:** It was a second line of text below the header that duplicated information already visible in the section body. It required every `loadSection` path to call `updateContextBar`, creating tight coupling between section logic and the header. Removal simplifies both.

---

## 2026-04-25 — Tags screen: design, chip filters, UDA detection

**Decision:** Tags screen added as a first-class function alongside Tasks/Times/Journals/Ledger/Lists.

**Design choices:**
- Placed in the functions group (not services), after Lists. Tags are a core data dimension, not a service tool.
- Server endpoint `/data/tags` returns per-tag: count, up to 20 tasks (urgency-sorted), priorities present, UDAs present, latest modified date. One network call populates all filter state client-side.
- Three quick-filter chip rows: status tags (detected from tag name against a hardcoded STATUS_KEYWORDS set), priority (H/M/L/none filters by task priority presence within the tag), UDA (only rendered if tasks actually have UDA fields set — confirmed via `task _udas` + per-task field inspection).
- **Exclude mode**: filter input paired with an "exclude" toggle — when active, the text filter hides matching tags rather than showing them. Requested by user as an inversion toggle.
- Sort options: A→Z, most tasks, fewest tasks, recently modified (uses `latest_modified` field from server).

**`buildTaskMetaPills` fix:** The function handled `tag:name` (singular) but the server encodes community-task meta as `tags:foo,bar` (plural comma-separated). Fixed with `flatMap` — `tags:` tokens are split by comma and each value rendered as a separate pill.

---

## 2026-04-25 — Task dependencies: inline display and add/remove

**Decision:** Task dependency UI implemented purely in the inline detail (no separate screen). Two display levels.

**Row-level badges:** `⊸N` (orange) = "blocked by N tasks" (this task's `depends` array). `→N` (blue) = "blocking N tasks" (computed client-side by scanning `cachedTasks` for entries whose `depends` includes this task's UUID). These badges are zero-cost to render since `cachedTasks` is already in memory.

**Inline detail section:** `renderDepSection()` renders a "dependencies" panel at the bottom of expanded task detail. Shows blocked-by list (with `×` remove buttons) and blocking list (navigation only, no remove — removing a blocking dep would modify the other task). Add input accepts task ID (numeric) or description substring; resolves against `cachedTasks` client-side before calling server.

**Server actions `dep_add` / `dep_remove`:** Use `task {id} modify depends+:{uuid}` / `depends-:{uuid}`. Added to `TASK_MUTATING` set so SSE broadcast fires on change.

**Why UUID not ID for dep_remove:** Task IDs are ephemeral in Taskwarrior (renumbered on filter). UUIDs are stable. The remove button stores the dep task's UUID in `data-uuid` and sends that to the server.

---

## 2026-04-25 — Community task → journal: removed redundant @project suffix

**Decision:** The `community_journal_entry` server action was appending ` @project:{project}` after the `[community-task:...]` marker in every stored journal line. This was a legacy artefact — the project is already encoded inside the marker's meta field and rendered as a blue pill by `buildTaskMetaPills`. The trailing `@project:` token was showing as a second redundant project display in the journal.

**Fix:** Removed `proj_tag` variable and interpolation from the line builder. The marker's meta field is the single source of project/tag/priority data for these entries.

---

## 2026-04-24 — Ledger UI overhaul: annotation model, balance grouping, reporting toggle

**Decision:** Five concrete ledger UI changes applied in this session. Three larger items deferred to TASK-LED-001–003.

**Changes applied:**
- `ledger_add` action now accepts optional `comment` field → appended as `; comment` posting-level comment
- New `ledger_annotate` action appends a standalone top-level comment `; [date] desc: note` to the ledger file (not a transaction — valid hledger syntax, skipped by balance/register commands)
- Balance display now groups by account type prefix (assets / liabilities / equity / income / expenses) with labelled section headers
- `ledger-balances` div moved to after `ledger-recent` so the transaction list is seen first
- Reporting buttons (hl-btn) now toggle: clicking the active button again collapses the output panel; active button gets highlight state

**annotation model (settled):**
The previous annotation implementation was invalid — it called `ledger_add` with `description: "; note"` and `amount: "0"`, producing a malformed transaction. The new `ledger_annotate` action writes a raw comment line. This is intentionally NOT a transaction: it produces no balance effect and won't show in `register`. It serves as a human-readable memo attached to the ledger file near a date.

**amount field (settled):**
`ledger_add` previously hardcoded `$` prefix on amounts, breaking non-dollar commodities (hours `h`, sessions `sess`, etc.). Fixed: amount is written verbatim from the form input. Users should type `$50` or `2h` or `1 sess` themselves.

**account hierarchy for non-accounting use (proposed, captured in TASK-LED-002):**
```
time:project:<name>    ; hours invested
sessions:agent:claude  ; agent-assisted sessions (source of time)
costs:api:anthropic    ; external costs
output:features        ; value produced
backlog:tech-debt      ; deferred work (like liabilities)
```
hledger's commodity-agnostic model makes this work naturally. Use `h` for hours, `sess` for sessions, `$` for money.

**hledger status markers:**
- unmarked = in-progress or not reviewed
- `!` pending = ready for review / awaiting confirmation  
- `*` cleared = reviewed, approved, reconciled

---

## 2026-04-23 — Communities panel: reference model, task/journal action semantics, terminology

**Decision:** Finalized how journal entries, task items, and community entries relate to each other through annotations, rejournal operations, and back-references. Five concrete changes made.

**Context:** Prior implementation had `→ journal` in the journal view creating new entries (growing orphan chains), `→ journal` from community writing no `rejournal-of:` marker, and no design analysis of the captured/live-state distinction or cross-type action semantics.

**Reference model (settled):**

`source_ref` format: `{profile}.task.{uuid}` or `{profile}.journal.{date-slug}` — stable identifiers in community SQLite.

Marker set in jrnl plain text (all inline, jrnl-transparent):
- `@project:` `@tags:` `@priority:` — entry-level metadata, scanner-parsed
- `[community-ref:ID|source_ref|desc]` — written into new journal entry when rejournaling from community; links back to community entry
- `rejournal-of:SLUG` — written alongside community-ref when source is a journal entry; enables "Rejournaled" filter
- `rejournaled → SLUG [community-ref:ID]` — written as an annotation on the SOURCE journal entry by the server at rejournal time; forward-pointer so original entry shows the chain

**Action semantics per entry kind (settled):**

| Context | Action | Behavior |
|---|---|---|
| Journal view "→ journal" | Changed to `+ note` | Annotates the source entry in-place; no new entry, no chain growth |
| Journal view `+ annotate` | Unchanged | Annotation block on source entry |
| Community panel, journal-sourced entry `+ comment` | Unchanged | Saves community comment only |
| Community panel, journal-sourced entry `→ annotate source` | NEW label | Annotates the original journal entry; saves community comment |
| Community panel, task-sourced entry `+ comment` | Unchanged | Saves community comment only |
| Community panel, task-sourced entry `→ journal entry` | NEW label + heavier | Structured journal entry: task fields (description, status, project, priority, due, tags) + user note + community-ref; also annotates task in taskwarrior |

**Captured vs. live state (settled):**

Keeping the captured/live distinction — it is semantically correct and valuable. `captured_state` is the point-in-time task snapshot when the task was added to community; `live_state` is fetched fresh on load. This supports "what did we discuss vs. what is the task like now."

Current UI shows full JSON blobs side-by-side — noisy. Changed to field-diff: only keys that changed between captured and live are shown.

**Chain depth management:**

Journal-to-journal follow-ups are now annotations (no new entry created), eliminating one axis of chain growth entirely. Community-to-journal rejournal creates a new entry pointing back to the journal source slug (not to a previous rejournal slug), keeping chains linear. A 3-hop chain (J1→C1→J2→C2→J3) is walkable via clickable `rejournal-of:` / `rejournaled →` links.

**Taskwarrior back-reference:**

When a task community entry is journaled out, a `task uuid annotate` is run to write a back-reference into the task's annotation history. This requires shell access to the profile's taskrc/taskdata — same pattern already used for live_state fetch.

**Terminology:**

Sidebar label changed from "Community" to "Communities" — the service manages multiple named collections; the singular label implied one shared space.

**Why these choices:**
- Annotation-as-note for journal view: avoids chain proliferation; keeps follow-up text attached to the source entry where it is most useful for recall
- Structured task journal entry: tasks have rich metadata; a one-liner with a community-ref backlink wastes it
- Field-diff for captured/live: full JSON blobs are unreadable; field-diff is actionable at a glance
- rejournal-of points to journal source slug (not prior rejournal slug): keeps the reference graph a shallow DAG, not a linked list requiring traversal

**Consequence:** COMM-008 (task annotation copy-back) is superseded in part by this work. Warrior service (COMM-009) is unaffected. Any future "update captured_state" button should write back to the SQLite `captured_state` column, not to the jrnl file.

---

## 2026-04-20 — Community Service architecture settled

**Decision:** Community Service is a global aggregation layer grouping task and journal items into named, shareable collections. Primary use: export/sharing for colleagues and teaching. Ten task cards created (TASK-COMM-001..010).

**Key decisions:**
- `community.db` SQLite at `$WW_BASE/.community/community.db` — global, not per-profile
- `source_ref` format: `{profile}.task.{uuid}` or `{profile}.journal.{date-slug}`
- Community entries show both captured-state (snapshot at add-time) and live current state
- Community-editable fields: community tags/priority/comments only; source fields read-only
- Journal annotation format: `---\n[YYYY-MM-DD HH:MM] text` appended to jrnl plain text
- Journal metadata: `@tags:x @project:y @priority:H` inline markers, scanner-parsed
- Rejournal backlinks: scan-based (acceptable breakage risk); no forward-ref index
- Task annotation copy-back: real `task annotate` write, opt-in approve/deny modal, optional `[community:name]` prefix
- Warrior service promoted from stub to control plane; cross-profile read in phase 1, cross-profile write in phase 2 (COMM-010)
- No timewarrior in community layer
- Plain-text-integrity clause revised: jrnl files ARE modified (annotation append, metadata markers at creation)
- Community accessible from global Warrior context — no profile-switching required

**Why:** Community's purpose is assembly for export/sharing, not task management. Tasks shown in simplified screened view. Warrior is the meta-profile control plane enabling global access.

**Consequence:** COMM-001 (storage) is the root dependency for most other COMM tasks. Journal scanner (COMM-005) is the shared utility for annotation parsing, metadata parsing, and filter buttons.

---

## 2026-04-24 — TASK-EXT-WARLOCK-001 complete: task-warlock adopted as `ww browser warlock`

**Decision:** Adopt jonestristand/task-warlock (Next.js 15, MIT, v0.3.0) as a sibling web UI at `ww browser warlock` (port 5001). Profile isolation via environment variable inheritance — no source patches required. `ww browser` (port 7777) remains primary.

**Architecture:** `services/warlock/warlock.sh` handles install/start/stop/status/PID management. `ww web` synonym registered in `config/shortcuts.yaml`. Browser sidebar panel added to `ww browser` with status badge and Install/Start/Stop controls. `/data/warlock/status` endpoint added to `server.py`. 25 bats tests in `tests/test-browser-warlock.bats`.

**Consequence:** `tools/warlock/source/` and `tools/warlock/settings/` are gitignored runtime dirs. `tools/warlock/WW-PATCHES.md` is version-controlled documentation of the isolation wiring. Future warlock upgrades: update `WARLOCK_GIT_TAG` in `warlock.sh` and run `ww browser warlock reinstall`.

---

## 2026-04-20 — `ww routines` design settled; WARLOCK adoption paused

**Decision:** Implement TASK-EXT-CRON-001 now as `ww routines` with profile-scoped storage at `profiles/<name>/.config/routines/`. Keep run trigger manual (`ww routines run`), use template-first authoring (`ww routines new <name>`), and require Python runtime only (no nix dependency at ww runtime). `TASK-EXT-WARLOCK-001` moved to parked/paused state pending broader web architecture decisions.

**Context:** Operator requested to skip gun work, pause warlock, and proceed with cron integration. Clarification requested whether microservice data should live with service code or in `.config`.

**Why:** Existing project precedent stores profile-scoped service config/state under `.config/` (`taskcheck`, `bugwarrior`, sync permissions). This keeps runtime/user-authored files in profile data space while command/runtime code remains in repo.

**Consequence:** `ww routines` commands now operate on `.config/routines` per profile and write run metadata there; `ww routines install` places upstream source under `$WW_BASE/tools/extensions/cron`. Future work should treat warlock as explicitly parked unless reopened by operator.

---

## 2026-04-20 — Integration scripts that touch `~/.bashrc` require elevated write context in agent runs

**Decision:** Treat profile-creation/integration test failures caused by `~/.bashrc` writes as environment constraints, not product regressions, when running in sandboxed agent mode.

**Context:** During TASK-UX-001 verification, `tests/test-scripts-integration.sh` failed because profile creation attempted to write `~/.bashrc` via shell-integration helpers and sandboxed execution blocked home-directory writes (`Operation not permitted` on `.bashrc.tmp` rename). The test passed earlier steps and failed only at shell rc mutation.

**Why:** The integration script currently assumes host-level write access to shell rc files. In agent sandboxes this may be denied or require explicit elevated permission approval, which can abort verification independently of code correctness.

**Consequence:** Future agents should either (a) run this integration test with approved elevated permissions, or (b) provide a test-safe rc override path for integration mode so writes stay within workspace temp files. Do not treat this specific failure signature as an immediate CLI behavior regression.

---

## 2026-04-09 — `ww browser` service architecture: live server + static export hybrid

**Decision:** `ww browser` runs a Python3 stdlib HTTP server (ThreadingHTTPServer — required for SSE + concurrent POST) as the primary experience. Static snapshot export (`ww browser export`) is a secondary path for sharing/publishing. No external dependencies — Python3 stdlib + vanilla JS only.

**Service namespace:** `browser` is the command. `sites` is reserved for future profile documentation site generation.

**SSE design:** ping thread broadcasts to per-client `queue.Queue` objects. Profile changes detected by polling `.state/active_profile` every 15s and broadcasting a `profile` event. ThreadingHTTPServer is mandatory — single-threaded BaseHTTPServer deadlocks when an SSE client holds the connection.

**Security boundary on POST /cmd:** `ALLOWED_SUBCOMMANDS` frozenset enforces that only `ww` subcommands are accepted. No `sh -c`, no eval. First token of the submitted command is validated against the set.

**Static files:** served from `services/browser/static/` — paths are hardcoded (`/`, `/app.js`, `/style.css`), no user-controlled path traversal possible.

**UI shell:** dark terminal aesthetic — `#0d1117` background, `ui-monospace` font stack, collapsing sidebar (collapse state in `localStorage`). Terminal line is dual-mode: execute (`❯ `) runs real `ww` commands via POST /cmd; filter (`/ `) dispatches a `filter` CustomEvent for sections to consume. Command history in `localStorage` (max 100).

---

## 2026-04-08 — Minimal root CLAUDE.md stub approved

**Decision:** `/Users/mp/ww/CLAUDE.md` created as a minimal redirect stub (no dev content) to fix Claude Code's auto-load gap. All real content stays in `system/`. The stub redirects to `system/ONBOARDING.md` and states the Orchestrator→Builder→Verifier→Docs handoff requirement. Previous rule was "no CLAUDE.md at root" — this is a narrow exception for tooling necessity, not a content file.

---

## 2026-04-08 — Integration tests pending quota; BATS suite is not postponed

**Decision:** Live integration tests (`run-integration-tests.sh`) require GitHub API quota/auth and are noted as pending on any task card that requires them (currently: TASK-SYNC-003). BATS suite (`bats tests/`, `select-tests.sh --run`) is NOT postponed — it should run normally for all change types. When a task card says "integration tests pending," Verifier may sign off on BATS pass alone; integration test completion is a follow-up requirement before production release.

---

## 2026-04-08 — Install role split: ww deps install is canonical; extension installs are best-effort

**Decision:** `ww deps install` (backed by `lib/dependency-installer.sh`) is the canonical, cross-platform install path for the core toolchain (task, timew, hledger, jrnl, pipx, gh). It handles brew/apt/dnf/pacman. Extension-specific install subcommands (`ww tui install`, `ww mcp install`, etc.) are best-effort: auto-install on macOS via brew, emit platform-appropriate hint on Linux via `detect_package_manager()`, never produce an unexplained error. Not fully enforced (no hard Linux CI) but must never silently fail.

---

## 2026-04-04 — CLAUDE.md and TASKS.md do not belong at project root

**Decision:** TASK-1.1 (deploy root CLAUDE.md), TASK-1.2 (deploy services/CLAUDE.md), and TASK-1.4 (TASKS.md at root) closed as design corrections rather than executed.

**Context:** Phase 1 verify-phase1.sh checked for these files at `/Users/mp/ww/CLAUDE.md` and `/Users/mp/ww/TASKS.md`, following the conventional "repo root = agent entry point" pattern.

**Why closed:** `/Users/mp/ww` is a hybrid — it's both a software project (`bin/`, `lib/`, `services/`) and a user data container (`profiles/`). CLAUDE.md and TASKS.md are dev artifacts. Placing them at the root would put agent context files alongside a user's personal task data and journals. The `system/` directory was explicitly created as the control plane for these files — they already exist there and are already authoritative. Copying them to the root creates a maintenance split without benefit.

**Consequence:** verify-phase1.sh rollout checks for root CLAUDE.md/TASKS.md will always fail. Those checks should be updated to point at `system/CLAUDE.md` and `system/TASKS.md` instead.

**2026-04-09 update:** A root `CLAUDE.md` *was* added, but as a redirect only — not a copy. It points agents to `system/ONBOARDING.md` and lists the 5-file read order. This is intentional and does not create a maintenance split. `system/CLAUDE.md` remains authoritative. The original decision against *copying* system/CLAUDE.md to root still stands.

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

## 2026-04-04 — set -euo pipefail belongs only in executed scripts, not sourced libs

**Decision:** `set -euo pipefail` removed from all 23 lib/ files. File-level `set` flags are only added to executed scripts (`bin/ww`, `services/custom/*.sh`). Sourced libraries use `${var:-}` defensive guards instead.

**Context:** TASK-SHELL-001 implementation attempted adding `set -euo pipefail` to all lib/ files. This caused 109 BATS test failures — from 37 baseline failures to 146. Root cause: sourced files propagate `set` flags to the caller's shell. BATS's internal `setup()` and test runner are not `-u`/`-e` safe, so sourcing any lib file that sets flags made the entire test suite fail.

**Why this approach:** The safety benefit of `-u` (catching unset variables) can still be achieved in sourced libs via `${var:-}` defensive guards on every expansion. These guards are defensive against strict callers without propagating strictness to permissive callers. The benefit of `-e` (exit on error) in lib functions is achieved by returning error codes to the caller, which enforces the pattern of callers deciding how to handle failures.

**Consequence:** Do not add `set -euo pipefail` to any file in `lib/`. This is an intentional design choice, not an oversight. For new executed scripts (bin/, services/custom/), always add it as the second line. The final test baseline after TASK-SHELL-001: 23 failures (down from 37 before session, improvement of 14 tests).

---

## 2026-04-04 — on-modify.timewarrior hook managed as per-profile template

**Decision:** `services/profile/on-modify.timewarrior` is the canonical hook template. It is installed per-profile at setup time by `install_timewarrior_hook()`. Each profile's `TIMEWARRIORDB` env var directs that profile's timew to its own isolated database.

**Context:** The hook was present in some profiles at `~/.task/hooks/on-modify.timewarrior` pointing to a global or wrong path. This caused cross-profile time tracking contamination.

**Why template approach:** Each profile needs its own hook instance because the hook reads `TIMEWARRIORDB` at runtime. By installing the hook file into each profile's `.task/hooks/` during profile creation, the env-var isolation architecture is preserved end-to-end. The template was updated from the 2020 Gothenburg Bit Factory version to the 2021 version with tasklib string-type tag handling.

**Consequence:** When a new profile is created, `install_timewarrior_hook()` must be called. The hook template at `services/profile/on-modify.timewarrior` is the single source of truth — do not edit per-profile hook files directly.

---

## 2026-04-04 — Tool conflict neutralisation via env-var redirection + sentinel ~/.taskrc

**Decision:** Workwarrior's conflict strategy for pre-existing tool configs is: (1) env-var redirection (`TASKRC`, `TASKDATA`, `TIMEWARRIORDB`, `BUGWARRIORRC`) as the primary mechanism; (2) sentinel `~/.taskrc` to convert silent fallback into a visible error; (3) `neutralise_tool_defaults()` called immediately after each tool install.

**Context:** The architectural question was whether to use symlinks or env-var overrides to redirect tools to profile-specific data. The installer needed to handle the case where tools are installed before ww (existing global configs) or after ww (new configs that default to wrong locations).

**Why env-vars, not symlinks:** Symlinks require management (creation, cleanup, conflict on concurrent profiles). Env-vars are stateless — set on profile activation, cleared on deactivation. No filesystem state to maintain. Tools already support these env vars natively.

**Why sentinel ~/.taskrc:** When a user runs bare `task` (without activating a ww profile), the default ~/.taskrc would silently write to the global `~/.task/` database instead of failing visibly. The sentinel file contains `data.location=/dev/null` and `hooks=off`, which makes bare `task` fail with a clear error rather than silently polluting the wrong database.

**Consequence:** `neutralise_tool_defaults()` in `lib/dependency-installer.sh` backs up `~/.taskrc` to `~/.taskrc.pre-ww-<date>` and writes the sentinel. `restore_tool_configs()` in `uninstall.sh` finds the most recent backup via `ls -t` and restores it. Do not use symlinks for tool redirection.

---

## 2026-04-04 — WW_INSTALL_DIR is overridable for custom installs and testing

**Decision:** `WW_INSTALL_DIR` changed from `readonly WW_INSTALL_DIR="$HOME/ww"` to `WW_INSTALL_DIR="${WW_INSTALL_DIR:-$HOME/ww}"` in `lib/installer-utils.sh`. `install.sh` now prompts for install directory and exports the user's choice.

**Context:** `readonly` prevented `WW_INSTALL_DIR=/tmp/ww-test ./install.sh` from working for testing. The install overview screen hardcoded `~/ww`. Users on shared systems or with existing `~/ww` directories from previous versions had no clean install path.

**Why:** Custom install paths are essential for: (a) testing the installer without touching a live installation, (b) users with existing `~/ww` data from old workwarrior versions who want a clean location, (c) multi-user systems. The shell RC block now uses `${WW_INSTALL_DIR}` (unquoted heredoc) so it records the actual chosen path, not the default.

**Consequence:** Always use `WW_INSTALL_DIR="${WW_INSTALL_DIR:-$HOME/ww}"` (not `readonly`) in installer code. The `add_ww_to_shell_rc` heredoc must remain unquoted (`<< EOF` not `<< 'EOF'`) to expand `${WW_INSTALL_DIR}` into the shell config block at write time.

---

## 2026-04-04 — Installer uses per-tool interactive cards with version transparency

**Decision:** `run_dependency_installer()` in `lib/dependency-installer.sh` presents a card per tool showing: (1) display name and one-line role, (2) installed/latest/WW-minimum versions, (3) platform-detected install command (brew/apt/dnf/pacman), (4) default files the tool creates, (5) how ww integrates with it. After each successful install, `neutralise_tool_defaults()` is called immediately.

**Context:** The original installer checked for missing tools and offered a single `brew install` for all of them. This was: platform-specific, opaque about what would be installed where, and left post-install conflicts unhandled.

**Why per-tool cards:** Users need to make an informed decision for each tool — some may already have managed installations, some may not want all tools. Version transparency (installed/latest/minimum) allows upgrading, skipping if up-to-date, or declining if below minimum. Platform detection covers brew/apt/dnf/pacman so the installer works on macOS and Linux.

**Consequence:** Adding a new supported tool requires entries in `get_tool_description()`, `get_tool_default_files()`, `get_tool_ww_integration()`, `get_tool_install_cmd()`, and `neutralise_tool_defaults()`. Bugwarrior is optional (clearly labelled). pipx must be installed before jrnl/bugwarrior (handled by install order in the tool list).

---

## 2026-04-04 — `--json` on i pull suppresses output; on i status wraps it

**Decision:** `i pull --json` → suppresses bugwarrior's stdout/stderr, emits `{"command":"pull","status":"success"}`. `i status --json` → captures github-sync status output as a string field in JSON.

**Context:** Bugwarrior has no native JSON output mode. github-sync has no `--json` flag. AI agent use case requires machine-readable output.

**Why this approach:** The simplest useful implementation for AI consumers. Pull result is pass/fail — a structured boolean is more useful than captured human text. Status output has meaningful content — wrapping it preserves the information while making it parseable.

**Consequence:** `i pull --json` silences all bugwarrior output. If a user needs the raw sync log, they must omit `--json`. `i status --json`'s `output` field contains a human-formatted string — it is not fully structured. Full structured status output would require changes to github-sync.sh (HIGH FRAGILITY, separate task).

---

## 2026-04-04 (session 2) — Re-source idempotency: session guards + no readonly on session indicators

**Decision:** ww-init.sh and shell-integration.sh use session guard variables (`WW_INITIALIZED`, `SHELL_INTEGRATION_LOADED`) checked at the top: `[[ -n "${VAR:-}" ]] && return 0`. These guards must never be declared `readonly`.

**Context:** `source ~/.bashrc` or `source ~/.zshrc` were causing "readonly variable" errors. Root causes: (1) `core-utils.sh` declared `readonly WW_BASE` on first source; on re-source `ww-init.sh` tried `export WW_BASE=` again. (2) `shell-integration.sh` declared several `readonly` section constants. (3) `.bashrc`/`.zshrc` had `export WW_BASE=` at top level.

**Why guards, not readonly:** `readonly` prevents re-declaration in the same shell session. But re-sourcing (e.g. `source ~/.bashrc`) is a normal user action. The correct pattern is: check if already loaded, return early if so. The loaded indicator itself must be a plain variable — `readonly GUARD=1` errors on second source just as surely as any other readonly.

**Consequence:** Never add `readonly` to `WW_INITIALIZED`, `SHELL_INTEGRATION_LOADED`, or `CORE_UTILS_LOADED`. Never write `export WW_BASE=` at the top level of `.bashrc`/`.zshrc` — use the guarded block in `ww-init.sh` only. All constants in `core-utils.sh` are guarded by `[[ -z "${CORE_UTILS_LOADED:-}" ]]`.

---

## 2026-04-04 (session 2) — get_ww_rc_files() is the single source of truth for rc file writes

**Decision:** All functions that write to shell config (aliases, source lines, etc.) call `get_ww_rc_files()` to discover which rc files to write to, rather than using a hardcoded `$SHELL_CONFIG` path.

**Context:** `add_alias_to_section()` previously defaulted to `$SHELL_CONFIG` (`.bashrc`). On zsh-primary systems, aliases were never written to `.zshrc`, making them invisible in zsh sessions.

**Why a discovery function:** The user may have `.bashrc`, `.zshrc`, both, or neither. The function creates `.bashrc` as fallback only if neither exists. The caller never needs to know which files exist — it just iterates the returned list.

**Consequence:** `get_ww_rc_files()` in `lib/shell-integration.sh` is the canonical rc-discovery function. `add_alias_to_section()` accepts an optional 3rd arg for the target file (rc-file-agnostic). `create_profile_aliases()`, `remove_profile_aliases()`, and `ensure_shell_functions()` all loop over `get_ww_rc_files()`. Never hardcode `.bashrc` or `.zshrc` paths in alias/config write operations.

---

## 2026-04-04 (session 2) — ensure_shell_functions() is a source-line check only, not a function injector

**Decision:** `ensure_shell_functions()` replaced from 400+ lines (injecting per-function stubs into rc files) to 20 lines (only ensuring the `ww-init.sh` source line is present).

**Context:** The old implementation injected definitions of every shell function (`profile()`, `journals()`, `ledgers()`, etc.) directly into the user's `.bashrc`. When functions were renamed or added, the stale stubs remained in rc files, causing old API behaviour and double-definition noise.

**Why source-line only:** All shell functions are defined in `lib/shell-integration.sh`, which is sourced via `ww-init.sh`. A single source line in `.bashrc`/`.zshrc` is the only bootstrapping needed. Adding functions to the rc file directly creates a maintenance split — the rc file becomes a shadow of the lib file and diverges over time.

**Consequence:** `ensure_shell_functions()` only appends the ww-init.sh source block if it is not already present. It is a silent no-op for established installs. Never revert to per-function injection. If a function needs to be in the shell, it belongs in `lib/shell-integration.sh`, not in the user's rc file.

---

## 2026-04-04 (session 2) — find() renamed to search() to avoid shadowing system find

**Decision:** The Workwarrior shell function previously named `find()` is now `search()`. It routes to `ww find`.

**Context:** Defining a bash function named `find` shadows the system `find` binary for the duration of the shell session. Workwarrior's own code (and other tools) use `command find` to bypass this, but it's a constant footgun.

**Why search:** `search` is semantically accurate (user is searching for tasks/items), unambiguous, and does not shadow any system command. The `ww find` domain name is unchanged — only the shell function alias changed.

**Consequence:** Users call `search` not `find` for ww search operations. Any documentation or help strings that reference the bare `find` command must be updated to `search`. `command find` bypass pattern is no longer needed in ww code.

---

## 2026-04-04 (session 2) — Profile creation output: only meaningful progress markers, no per-alias lines

**Decision:** Profile creation output shows component-level progress (`🔧 Creating default TaskRC...`, `✓ .taskrc created at:...`) but suppresses per-alias detail, "already present" idempotency notices, and duplicate step labels.

**Context:** Output for `profile create <name>` included 4 lines of `ℹ Added alias: p-<name> / <name> / j-<name> / l-<name>`, 2 lines of `ℹ Shell integration already present in .bashrc/.zshrc`, plus duplicate step labels between `create-ww-profile.sh` and its called functions.

**Why signal, not noise:** Idempotency is the expected happy path — reporting it clutters output without informing the user of anything actionable. Per-alias lines repeat information the user already requested. The `✓ Aliases written  →  .bashrc .zshrc` summary line provides all the confirmation needed.

**Consequence:** `add_alias_to_section()` idempotency check is a silent `return 0`. `create_profile_aliases()` emits no per-alias log lines. `ensure_shell_functions()` emits no "already present" messages. The only alias-related output during profile creation is the single summary line. `log_success "Added alias to..."` must not be re-added.

---

## 2026-04-04 (session 4) — bugwarrior GitHub token: @oracle:eval:gh auth token is canonical

**Decision:** When `gh` CLI is present and authenticated, bugwarriorrc uses `github.token = @oracle:eval:gh auth token` rather than a static Personal Access Token.

**Context:** The `ww issues custom` GitHub wizard now detects `gh auth status` at setup time. If `gh` is authed, option 1 is "use gh CLI auth" which writes the oracle directive. The token never appears in the config file. Manual PAT entry remains available as a fallback.

**Why:** The `gho_` OAuth token `gh` holds lives in the OS keychain (macOS: keyring confirmed). The oracle directive evaluates at pull time — token rotates automatically with `gh auth refresh`. No separate PAT lifecycle to manage. Scopes confirmed sufficient: `repo`, `admin:org`.

**Consequence:** New GitHub service configs generated via `ww issues custom` will default to the oracle form. Existing plain-text configs are unaffected. `configure-issues.sh` must not write `github.token = @oracle:eval:gh auth token` if `gh` is absent or not authed — it falls back to prompted PAT entry.

---

## 2026-04-04 (session 4) — bugwarrior install requires setuptools inject on Python 3.12+

**Decision:** The canonical bugwarrior install command is `pipx install bugwarrior && pipx inject bugwarrior setuptools`. The single-command form `pipx install bugwarrior` is insufficient on Python 3.12+.

**Context:** `taskw` (a bugwarrior dependency) imports `distutils.version.LooseVersion`. `distutils` was removed in Python 3.12. Without `setuptools` injected, bugwarrior crashes with `ModuleNotFoundError: No module named 'distutils'` on first run.

**Consequence:** All install hints updated: `bin/ww`, `configure-issues.sh`, `dependency-installer.sh` (all four platform branches). Any documentation or help text referencing bugwarrior installation must use the two-step form.

---

## 2026-04-04 (session 4) — github.login vs github.username are distinct fields in bugwarrior

**Decision:** `github.login` = the authenticated GitHub user (your personal account). `github.username` = the namespace to pull issues from (a user or org). These are separate config fields and must be prompted separately.

**Context:** The original `configure-issues.sh` wizard set both to the same value (the personal username). For org-based workflows (e.g. a profile with login=user1, username=orgname), this caused the pull to silently fetch the wrong set of issues — or no issues at all if the org had no repos owned by that username.

**Consequence:** `configure_github()` now prompts for login (pre-filled from `gh api user`) separately from namespace/org. Default for namespace is the login value, which is correct for personal-account setups.

---

## 2026-04-04 (session 4) — service-managed UDA classification by prefix

**Decision:** UDAs whose names start with `github*`, `gitlab*`, `jira*`, `trello*`, or `bw*` are classified as service-managed and displayed separately in `uda-manager.sh` with a `[source]` tag. User-defined UDAs are shown in a separate section.

**Context:** bugwarrior injects 15 `github*` UDAs into `.taskrc`. Users managing UDAs interactively had no signal that these fields are externally managed — renaming or deleting them breaks sync.

**Consequence:** `classify_uda()` function in `uda-manager.sh` is the canonical source. Future service integrations must use a prefix consistent with this classification (e.g. a Linear integration should use `linear*` UDA names). The `ww issues uda` CLI (TASK-ISSUES-001) will use the same classification.

## 2026-04-10: Browser UI session — direct execution without orchestrator

**Decision:** Execute browser UI and service wiring changes directly without the
Explorer → Builder → Verifier orchestrator workflow.

**Justification:**
1. Write scope is predominantly LOW fragility (browser static files, new service dirs)
2. `bin/ww` changes are additive only (new `cmd_questions`, no modification to existing commands)
3. Server changes are contained within `services/browser/server.py` with no CLI impact
4. Kiro IDE provides inline diagnostics, compile checks, and direct testing that
   replaces the Verifier role for these file types
5. The orchestrator overhead (~30 min per change for task cards, gate checks) is
   disproportionate to the risk level of browser UI changes
6. All changes are logged in `system/logs/session-browser-ui.md` with full detail

**Files touched:**
- services/browser/static/* (LOW) — HTML, CSS, JS
- services/browser/server.py (LOW) — new endpoints only
- bin/ww (SERIALIZED) — additive cmd_questions function only
- services/questions/* — new/updated templates and handlers
- services/cmd/ — new service directory
- system/audits/divergences.md — new documentation

**What would trigger orchestrator use:**
- Any modification to `lib/sync-*.sh`, `lib/github-*.sh` (HIGH FRAGILITY)
- Any modification to existing `bin/ww` command logic (SERIALIZED)
- Any change to `lib/shell-integration.sh` (SERIALIZED)
- Any change affecting test baselines

## 2026-04-10: Simultaneous time tracking — multiple TIMEWARRIORDB approach

**Decision:** Use multiple TIMEWARRIORDB instances for concurrent time tracking
rather than tag merging or a ww-native time log.

**Rationale:**
- TimeWarrior is fundamentally single-track by design
- Tag merging (tried and reverted) loses per-task time granularity
- Multiple timew instances under `profiles/<name>/timew/<track>/` leverages
  existing resource infrastructure (timew.yaml, resource selectors)
- Each concurrent track is a real timew database with full timew compatibility
- Aggregation for display is a read-only operation in the browser UI

**Implementation:** Deferred to dedicated task card when ready.

## 2026-04-10: Projects service design

**Decision:** Projects are a cross-cutting view that groups resources by a shared
project name/tag, not a new data store.

**Design:**
- A project is defined in `config/projects.yaml` with a name and associated resources
- Tasks are linked via TaskWarrior's `project:` field
- Journal entries are linked via `[project:name]` prefix convention
- Ledger entries are linked via account hierarchy (e.g., `expenses:project-name:*`)
- Time entries are linked via timew tags matching the project name
- The browser Projects panel aggregates these views

## 2026-04-10: Task card organization and index

**Decision:** Create INDEX.md as a scannable manifest alongside TASKS.md.
INDEX.md is NOT redundant with TASKS.md:
- TASKS.md = human-readable dispatch board (strategic view, dependency waves)
- INDEX.md = machine-scannable manifest (one-line per card, priority flags, folder structure)
- Folder structure = status-at-a-glance (subfolders reserved for future physical separation)

Cards remain flat in cards/ for now. INDEX.md provides virtual organization.

## 2026-04-10: Weapons as top-level concept

**Decision:** Create /weapons/ top-level folder. Weapons are distinct from services
(infrastructure) and extensions (external tool wrappers). Weapons manipulate data
from the four main functions in specialized ways.

Gun is modeled as an extension-type weapon (wraps taskgun binary).
Sword is ww-native (implemented in bin/ww).
Both live in weapons/<name>/ with README.md.

## 2026-04-10: AI access control

**Decision:** Create config/ai.yaml for controlling LLM access across services.
Global enable/disable, per-service allowlist, confirmation toggle, offline mode.

## 2026-04-10: TimeWarrior extensions — separate from TaskWarrior

**Decision:** Keep `ww extensions taskwarrior` and `ww extensions timewarrior` as
separate commands. Registry at config/extensions.timewarrior.yaml.

## 2026-04-10: Recurring tasks — full cross-function recurrence

**Decision:** Use TaskWarrior's built-in recurrence for tasks, plus a ww layer
for recurring journal prompts and ledger entries. Lives under CTRL panel.

## 2026-04-10: Calendar integration — parked

**Decision:** CAL-001 stays parked. Not a current priority.

## 2026-04-10: WEB-001 — removed

**Decision:** TASK-WEB-001 archived to removed/. Superseded by the browser service
(SITE-002 through SITE-010).

## 2026-04-11: Task card index and folder structure

**Decision:** Create INDEX.md as a scannable registry alongside TASKS.md dispatch board.

**Rationale:** TASKS.md is the Orchestrator's working surface (dispatch queue, priorities,
dependency waves). INDEX.md is the complete inventory with one-line summaries per card,
organized by status. They serve different purposes and are not redundant.

**Scanning mechanism:** The Orchestrator reads TASKS.md for dispatch decisions. Any agent
(Kiro, Claude, Codex) reads INDEX.md for project state overview. The system/CLAUDE.md
references TASKS.md as the canonical task board. INDEX.md is the lookup table behind it.

**Priority field:** Added to INDEX.md with values: NEXT, HIGH, MEDIUM, LOW, PARKED.
TASK-QUAL-002 bumped to NEXT priority.

## 2026-04-11: Weapons as top-level concept

**Decision:** Create /weapons/ folder as the home for weapon documentation and config.
Weapon code lives in bin/ww (cmd_<weapon>) for native weapons, or passes through to
external binaries for extension weapons.

**Gun:** Extension weapon. Binary: taskgun (cargo install). Docs: weapons/gun/README.md.
Modeled as an extension in docs/taskwarrior-extensions/taskgun-integration.md.

**Sword:** Native weapon. Code: cmd_sword() in bin/ww. Docs: weapons/sword/README.md.
Mechanical splitting by default. AI splitting (--ai) is future work using the same
provider resolution as CMD AI.

## 2026-04-11: AI access control

**Decision:** Create config/ai.yaml for controlling LLM access points.
User controls: mode (off/local-only/local+remote), per-feature toggles.
Managed via CTRL panel in browser UI.

## 2026-04-11: TASK-WEB-001 archived

**Decision:** Moved to removed/. The browser service IS the web UI.
TASK-EXT-WARLOCK-001 remains pending as a separate future consideration.

## 2026-04-11: ww issues uda value

**Decision:** Keep `i uda` as a distinct command that shows service-managed UDAs
specifically (bugwarrior/github-sync fields). Different from `ww profile uda list`
which shows all UDAs. Route to service-uda-registry.yaml reading.

## 2026-04-11: Recurring tasks via TaskWarrior built-in

**Decision:** Use TaskWarrior's built-in recurrence for CRON-style actions rather
than external tool (allgreed/cron). Managed via CTRL panel. TASK-EXT-CRON-001
updated to LOW priority.

## 2026-04-11: Models service core stabilization (Phase 1)

**Decision:** Stabilize `ww model` parsing/behavior before broader AI-control work.

**Implemented now:** Section-aware YAML parsing in `services/models/models.sh`,
correct `list/providers/env/check` behavior, prevent removing the active default model,
and align docs/tests with singular-first syntax (`ww model`, `ww models` as legacy alias).

**Process note:** Applied risk-tiered workflow. This change touched LOW-fragility service
and docs paths only, so the full high-fragility orchestration chain was not required.

## 2026-04-11: Phase 2 AI control enforcement + CTRL control plane

**Decision:** Enforce `config/ai.yaml` server-side for CMD AI and centralize runtime/UI
settings under a CLI-accessible CTRL service.

**Implemented now:**
- Browser server `/cmd/ai` now resolves providers/models via config, enforces AI mode and
  access-point policy, and returns active provider/model metadata.
- Added `/data/ctrl` endpoint for effective AI + command-line/UI indicator state.
- Added `ww ctrl` service (`status`, `ai-mode`, `ai-cmd`, `prompt-ww`, `prompt-ai`,
  `ui-model-indicator`) with persisted settings in `config/ctrl.yaml`.
- CTRL browser panel now updates persisted settings via `ww ctrl` commands instead of
  localStorage-only toggles.
- CMD UI now displays active AI provider/model discreetly.

## 2026-04-11: Alias warning removal + model syntax refinement

**Decision:** Remove deprecation nudges for plural aliases while keeping alias support.

**Implemented now:**
- `ww models|groups|journals|ledgers|profiles|services` run without warning text.
- Model namespace updated to support singular create shortcut:
  `ww model <name> <type> <base_url> [api_key_env]` (add-provider synonym).
- Added `ww model remove-provider <name>` (guarded when models still reference provider).

## 2026-04-11: Ollama sensing and per-profile AI config

**Decision:** Implement three levels of ollama integration:
- L1: Background probe in ww-init.sh (1s timeout, non-blocking)
- L2: ww ctrl ai-on/off/status convenience commands
- L3: profiles/<name>/ai.yaml overrides global config/ai.yaml

**Mechanism:** curl probe to localhost:11434/api/tags with 1-second timeout.
If reachable, exports WW_OLLAMA_AVAILABLE=1. The browser server reads
profile-level ai.yaml after global, overriding mode and preferred_provider.

**Per-profile use case:** One profile uses a coding model (codellama), another
uses a general model (llama3.2). Each profile's ai.yaml specifies its preference.

## 2026-04-11: Heuristic evolution system design

**Decision:** Build a self-improving command interpretation system where:
1. Every CMD request is logged with route (ai/heuristic), input, output, success
2. Successful AI responses are digested into heuristic rules
3. Rules are stored in config/cmd-heuristics.yaml (YAML, user-editable)
4. Over time, more requests are handled by heuristics, reducing AI dependency
5. Users can view, edit, add, delete rules via CTRL panel

**Route indicator:** UI now shows ⚡ (AI) or ⚙ (heuristic) for every CMD execution.
CMD log records the route field for historical analysis.

**Initial rules:** 12 builtin patterns extracted from the existing heuristic code,
covering task creation, time tracking, journal entries, profile commands, and
direct ww command passthrough.

**Plan document:** system/plans/heuristic-evolution.md with 5-phase roadmap.

## 2026-04-11: Heuristic Compilation spec — remaining tasks completed

**Decision:** Implemented all remaining required tasks from the Kiro heuristic compilation spec (`.kiro/specs/heuristic-compilation/`).

**Tasks completed:**
- 5.2: `detect_conflicts()` and `resolve_conflicts()` — finds rule pairs matching same input with different outputs, keeps higher-confidence rule
- 5.3: `validate_corpus_coverage()` and `fill_gaps()` — identifies corpus entries unmatched by any rule, creates gap-filling rules with escaped regex
- 9.1: `split_compound_input()` — splits on conjunctions (and/then/also/plus) at word boundaries
- 9.2: `HeuristicEngine.match_compound()` in server.py — tries compound split, matches each segment, falls through to AI if any segment unrecognizable
- 9.3: `generate_composition_patterns()` — 9 multi-command rules covering task+annotation, task+time tracking, task done+stop tracking
- 11.2: `--verbose` report mode — detailed per-rule output grouped by domain with sample test results
- 11.3: `--digest` report additions — `read_cmd_log_digest()` reads cmd.log JSONL, `merge_corpus()` deduplicates, report shows log stats and conflicts

**Validation:** Full pipeline run: 260 commands discovered, 911 rules generated, 0 failures, 93 conflicts resolved, 64 gaps filled, 621 merged rules. `--digest` found 7 AI entries from 20 log lines. `--verbose` shows all rules grouped by domain with PASS/FAIL per sample.

## 2026-04-12: Stress-test profile created from business document

**Decision:** Created a full profile populated with data inferred from a detailed business document about a Delaware-incorporated electronics assembly network company.

**Scope:** 143 tasks across 11 projects, 103 journal entries across 13 named journals, 139 ledger transactions in dual currency (USD + CAD) with 47 accounts, 52 time tracking intervals totaling 180 hours. UDA data populated on ~20 key tasks. Tasks span incorporation, node setup, logistics hub, software development, workforce training, fundraising, compliance, M&A, sales, brand, and housing.

**Purpose:** Stress test of the full workwarrior system — profile creation, multi-journal support, dual-currency hledger, rich UDA usage, time tracking with tags, and browser UI rendering of a complex profile.

**Ledger design:** Full chart of accounts with startup costs through Q2 2026, bridge financing (USD 500K SAFE notes), Year 1 actual revenue, Year 2 quarterly projections, Year 3 semi-annual projections. Revenue grows from ~USD 500K (Y1) to ~USD 2M (Y2) to ~USD 5M (Y3). Dual currency: CAD for Canadian operations, USD for American operations and platform-level revenue.

## 2026-04-12: Profile removal service and repo hygiene

**Decision:** Built `ww remove` service for clean profile removal. Gitignored `profiles/`, `config/cmd-heuristics*.yaml`, `functions/journals/CONFIG/`, `functions/journals/private/`. Sanitized all system docs to replace real profile names with dummy names.

**Remove service design:** Supports `--keep` (inverse selection), `--archive-all` / `--delete-all` (batch mode), `--dry-run`, `--force`. Each profile prompted individually: archive, delete, or skip. Archive preserves to `profiles/.archive/<name>-<timestamp>/`. Scrubs: groups.yaml, .state files, question templates, shell RC aliases.

**Scramble flag:** Flagged for future implementation. Will obfuscate profile data (task descriptions, journal content, ledger amounts, time tags, UDA values) before deletion to prevent recovery from disk or git history. Multi-pass overwrite option.

**Heuristic files gitignored:** `config/cmd-heuristics.yaml` and `config/cmd-heuristics-corpus.yaml` are generated output from `ww compile-heuristics`. Each install regenerates its own based on the user's command surface. No reason to commit them.

**Profile data gitignored:** `profiles/` contains all user-specific task, journal, ledger, and time data. Never belongs in the repo. Existing tracked profile files will need `git rm -r --cached profiles/` before commit.
