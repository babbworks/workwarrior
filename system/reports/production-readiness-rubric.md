# Production-Readiness Rubric — Workwarrior CLI

**Authored:** 2026-04-09
**Task:** TASK-REL-002
**Scope:** v1 release gate criteria

Production-ready = stable install + every command listed in `ww help` works.
This is distinct from "all intended functionality" — the help output is the contract.

---

## Criteria

### 1. `ww help` clean output

**Definition:** `ww help` produces no errors, no garbled output, no "command not found" messages.

**Evidence source:** Manual: run `ww help 2>&1` and inspect stderr. No lines from stderr should appear before or mixed into the help text.

**Owner:** Verifier

**Status:** Fixed in TASK-REL-002 (backtick command substitution in heredoc Compatibility line; stray bare-word examples removed).

---

### 2. Every help-listed command responds correctly

**Definition:** Every command token listed in `ww help` (Commands section) routes to a working handler that exits 0 on `--help` and does not produce an unhandled error.

**Commands to verify:**
| Command | Verifier check |
|---|---|
| `ww profile --help` | exits 0, shows profile help |
| `ww profiles` | exits 0 (nudge + list) |
| `ww service --help` | exits 0, shows service help |
| `ww services` | exits 0 (nudge + list) |
| `ww group --help` | exits 0, shows group help |
| `ww groups` | exits 0 (nudge + list) |
| `ww model --help` | exits 0, shows model help |
| `ww models` | exits 0 (nudge + list) |
| `ww journal --help` | exits 0, shows journal help |
| `ww journals` | exits 0 (nudge + list or profile error) |
| `ww ledger --help` | exits 0, shows ledger help |
| `ww ledgers` | exits 0 (nudge + list or profile error) |
| `ww tui help` | exits 0, shows tui help |
| `ww mcp help` | exits 0, shows mcp help |
| `ww extensions --help` | exits 0 |
| `ww find --help` | exits 0 |
| `ww custom help` | exits 0 |
| `ww shortcut help` | exits 0 |
| `ww export --help` | exits 0 or informative error |
| `ww x --help` | exits 0 or informative error |
| `ww deps help` | exits 0, shows deps help |
| `ww version` | exits 0, shows version string |
| `ww help` | exits 0, clean output |

**Evidence source:** Manual spot-check (5+ commands). Full check is a Verifier task at Gate D.

**Owner:** Verifier (spot check); Builder (implementation correctness)

---

### 3. `ww deps install` succeeds on clean macOS (brew baseline)

**Definition:** On a macOS system with Homebrew installed, `ww deps install` installs all core tools (task, timew, hledger, jrnl, pipx, gh) without error.

**Evidence source:** Manual walkthrough on a clean macOS environment, or code review of `lib/dependency-installer.sh` brew branches.

**Owner:** Builder (code correctness); Orchestrator (live-test sign-off before release)

**Notes:** Live macOS clean-install test is v1 requirement. Linux live-testing deferred to post-v1 (see criterion 4).

---

### 4. Extension installs give platform-appropriate guidance on Linux

**Definition:** On Linux (no brew), `ww tui install` and `ww mcp install` detect the platform (apt/dnf/pacman), emit the correct install hint, and exit with a non-zero code. They do not silently fail and do not produce a generic "brew not found" message.

**Evidence source:** Code review of `cmd_tui` install branch and `cmd_mcp` install branch in `bin/ww`. Verify the `_pm` detection block uses `command -v apt/dnf/pacman`. No live Linux test required for v1.

**Owner:** Builder (code correctness); Verifier (code review)

**Status:** Implemented in TASK-REL-002.

---

### 5. Core profile round-trip works

**Definition:** The sequence `ww profile create <name>` → activate profile (`p-<name>`) → `task add "test task"` → `timew start "test task"` completes without error and data appears in the correct profile directory.

**Evidence source:** Manual walkthrough. Covered in `tests/test-foundation.bats` for profile creation. Time tracking integration is manual.

**Owner:** Verifier (sign-off)

**Notes:** This is the minimum viable user journey. Failure here blocks release regardless of other criteria.

---

## Release Gate

All five criteria must be satisfied (code correct + evidence gathered) before any release claim. Gate D in `system/gates/all-gates.md` references this rubric as the production-readiness evidence requirement.

See `system/gates/all-gates.md` — Gate D.

---

## Out of Scope (Post-v1)

- Full Linux live-install testing
- Multi-user / multi-profile isolation stress testing
- Windows / WSL support
- Bugwarrior live integration testing (requires GitHub API quota)
- Performance benchmarks
