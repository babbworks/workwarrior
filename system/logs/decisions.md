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

**Context:** Output for `profile create john` included 4 lines of `ℹ Added alias: p-john / john / j-john / l-john`, 2 lines of `ℹ Shell integration already present in .bashrc/.zshrc`, plus duplicate step labels between `create-ww-profile.sh` and its called functions.

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

**Context:** The original `configure-issues.sh` wizard set both to the same value (the personal username). For org-based workflows (e.g. babb profile: login=peers8862, username=babbworks), this caused the pull to silently fetch the wrong set of issues — or no issues at all if the org had no repos owned by that username.

**Consequence:** `configure_github()` now prompts for login (pre-filled from `gh api user`) separately from namespace/org. Default for namespace is the login value, which is correct for personal-account setups.

---

## 2026-04-04 (session 4) — service-managed UDA classification by prefix

**Decision:** UDAs whose names start with `github*`, `gitlab*`, `jira*`, `trello*`, or `bw*` are classified as service-managed and displayed separately in `uda-manager.sh` with a `[source]` tag. User-defined UDAs are shown in a separate section.

**Context:** bugwarrior injects 15 `github*` UDAs into `.taskrc`. Users managing UDAs interactively had no signal that these fields are externally managed — renaming or deleting them breaks sync.

**Consequence:** `classify_uda()` function in `uda-manager.sh` is the canonical source. Future service integrations must use a prefix consistent with this classification (e.g. a Linear integration should use `linear*` UDA names). The `ww issues uda` CLI (TASK-ISSUES-001) will use the same classification.
