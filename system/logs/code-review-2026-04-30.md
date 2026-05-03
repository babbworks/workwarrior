# Workwarrior CLI — Comprehensive Code Review

**Reviewed:** 2026-04-30 | **Scope:** All of `bin/`, `lib/`, `services/`, `tests/`, `install.sh`

---

## 1. Overall Architecture & Design — 8/10

**Structure is genuinely well-thought-out.** The three-layer model (dispatcher → libraries → services) is clean and logical:

```
bin/ww (4,918 lines — dispatcher + all cmd_ functions)
lib/   (24 files, ~8,300 lines — sourced libraries)
services/ (25+ categories — executed bash scripts)
```

**Separation of concerns is good** where it counts most: sourced libs vs executed scripts is a real architectural distinction, enforced by documentation (lib/CLAUDE.md explicitly forbids `set -euo pipefail` and `exit` in libs). That discipline pays off.

**Where it breaks down:** `bin/ww` is doing two jobs — routing AND implementation. At 4,918 lines with 28 `cmd_*` functions defined inline, it's a monolith. Functions like the questions system (lines 2420+) embed a full Python script via heredoc inside a bash function. This works but is hard to test and debug.

**Service routing is inconsistent.** Some services are dispatched through function wrappers, others invoked directly with `bash`:

```bash
# Pattern A — function wrapper (can intercept, validate):
cmd_profile "$@"

# Pattern B — direct invocation (no wrapper, no interception):
bash "$WW_BASE/services/network/network.sh" "$@"
bash "$WW_BASE/services/saves/saves.sh" "$@"
```

Both patterns exist in the same switch statement. Pick one.

**GitHub sync dependency graph** (9 interdependent lib files) is the most fragile subsystem. The CLAUDE.md correctly flags all of these as HIGH FRAGILITY. This complexity is partly inherent to bidirectional sync, but 9 coupled files is a lot.

**Not over-engineered** for a system unifying 4 tools across multiple profiles. The profile isolation model is clean.

---

## 2. Code Quality & Best Practices — 7/10

**Good discipline where it matters:**
- `#!/usr/bin/env bash` + `set -euo pipefail` in every executed script ✓
- `local` declarations on all variables in functions ✓
- Quoted expansions throughout: `"$var"`, `"${array[@]}"` ✓
- `return` instead of `exit` in lib functions ✓
- `log_error()` to stderr, user messages via logging.sh ✓
- No TODO/FIXME/HACK comments anywhere in the codebase — clean ✓

**Inconsistencies:**

The fallback log functions in bin/ww (lines 29–35) don't match the real signatures:

```bash
# Fallback (no emoji, no stderr redirect on log_info):
log_info()    { echo "info $*"; }
log_error()   { echo "err $*" >&2; }

# Real (with emoji, consistent stderr):
log_info()    { echo "ℹ $*"; }
log_error()   { echo "✗ $*" >&2; }
```

If someone runs `ww` with a broken install, the fallback output looks broken.

**Dead code:** `WW_MAIN_ARGS=()` on line 20 is initialized but never populated or read anywhere in the file. This suggests either a planned feature or a removed one.

**`sed -i.bak` chain in profile-manager.sh** (lines 163–176): three successive `sed -i.bak` calls on the same file, one `rm -f` at the end. On macOS, each call overwrites the same `.bak` path, so only one backup file exists at the end — the `rm` correctly handles it. Not a bug, but surprising. A single multi-expression sed call would be cleaner:

```bash
sed -i.bak \
  -e "s|^data\.location=.*|data.location=$task_data_dir|" \
  -e "s|^hooks\.location=.*|hooks.location=$hooks_dir|" \
  -e "s|^hooks=.*|hooks=on|" \
  "$taskrc_path"
rm -f "$taskrc_path.bak"
```

**Python embedded in bash (line 2420):** Writing a temp Python file via heredoc and running it is a real pattern but creates problems:
- No trap for cleanup on early exit — the `.py` file leaks if `set -e` triggers before line 2558
- File created in `/tmp/` (not `${TMPDIR:-/tmp}/`) — minor portability gap
- Can't be unit-tested independently

---

## 3. Reliability & Robustness — 7/10

**Strengths:**
- Browser service checks for server readiness via `/health` with 10-second timeout before proceeding ✓
- Profile activation validates the profile name before touching anything ✓
- Stale PID file detection in browser service ✓
- Library defensive sourcing with fallback ✓

**No `trap` for temp file cleanup.** The pattern used:

```bash
tmp="$(mktemp -d "${TMPDIR:-/tmp}/ww-timew-billable.XXXXXX")"
# ... work ...
rm -rf "$tmp"   # only reached on success path
```

appears in at least 4 places. If `set -e` fires mid-function (e.g., `git clone` fails), the temp directory leaks. The correct pattern:

```bash
tmp="$(mktemp -d "${TMPDIR:-/tmp}/ww-timew-billable.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
```

**Browser service has no signal handler.** If the shell that started `ww browser start` exits, the Python server becomes an orphan — no mechanism to detect or reap it except checking the stale PID on next start.

**Log rotation logic (lib/logging.sh:249–256)** is the standard logrotate pattern and is correct. A race condition only applies if two processes rotate simultaneously — unlikely given sync is single-threaded.

**`error-handler.sh` interactive prompts have no timeout.** The `read -p "Choose..." >&2` calls block indefinitely if running non-interactively (e.g., in a CI hook or cron). No `read -t N` timeout.

**Service discovery deduplication** uses a linear search through an array (O(n²)):

```bash
for seen in "${seen_services[@]}"; do
  [[ "$seen" == "$service_name" ]] && already_seen=1 && break
done
```

With 25+ services this is fine. At 200+ it would matter.

---

## 4. Performance & Efficiency — 7/10

No obvious bottlenecks for a CLI tool. The main concern is startup time, not throughput.

**Subshell usage** is appropriate — subshells used for scoping, not gratuitously.

**`mktemp` + embedded Python** adds ~100ms overhead to the questions system. Fine for interactive use.

**Service discovery runs on every invocation** that calls `discover_services()`. For a CLI this is acceptable but worth noting — profiling might reveal this as a startup cost in a slow filesystem.

**`git clone --depth 1` in timew extension install** (lines 1652+) is correct — shallow clone for install is the right choice.

No pipe abuse — no chains like `cat file | grep | awk | sed` where a single tool would suffice.

---

## 5. Security & Safety — 8/10

**Strong baseline:**
- No `eval` with user input ✓
- All variable expansions properly quoted ✓
- GitHub tokens accessed via `gh auth` (OS keychain), not hardcoded ✓
- No secrets in code ✓
- Profile name validation prevents path traversal (enforces charset + length) ✓

**One real concern:** The embedded Python script (line 2421+) writes to `/tmp/ww_q_XXXXXX.py` and executes it. On a shared system, `/tmp/` may be world-readable depending on OS configuration. Use `${TMPDIR:-/tmp}` and verify umask. The script contains no secrets currently, but the pattern is worth hardening.

**HTTP server (browser/server.py) is localhost-only**, no auth. Appropriate for a local dev tool, but worth documenting explicitly in the help text for users who might bind to `0.0.0.0`.

**Shell injection surface is low.** User-supplied strings (profile names, task descriptions) pass through validation before being used in commands.

---

## 6. User Experience — 8/10

**Help text is thorough.** The `show_usage()` function covers all commands with examples. Each service responds to `--help`. `ww help <command>` delegates to service help. Well-designed.

**Error messages are human-friendly.** `log_error "Profile 'foo' not found"` with emoji (✗) and stderr is the right pattern.

**Profile switching UX** (shell aliases `p-work`, `p-personal`) is elegant — no manual `export` required.

**Output modes** (compact/JSON) are a good design choice for tool composability.

**Density control in browser UI** (compact / normal / relaxed) stored in localStorage — good UX detail.

**One gap:** The fallback error messages when libs are missing (`"err $*"`) are ugly and would confuse a new user with a broken install.

**`ww browser` UX gap:** starting the server prints status but doesn't tell the user the URL unless they look at the PID file. The URL should always be echoed on start.

---

## 7. Strengths

1. **Profile isolation model is excellent.** Independent `.task`, `.timewarrior`, `journals/`, `ledgers/` per profile, fully activated via env vars. Clean, correct.

2. **lib/CLAUDE.md is one of the best pieces of internal documentation in this codebase.** The sourced-vs-executed distinction, serialization rules, dependency chain diagram, and fragility register are all things most teams skip and regret.

3. **Test coverage is real.** 41 `.bats` files plus integration scripts. Pre-existing failures are documented. Tests cover edge cases (profile name validation, taskrc path updates, alias creation). Not just "we have tests."

4. **Service discovery with profile overrides** (profile-local services shadowing globals) is a sophisticated feature done cleanly.

5. **Defensive library sourcing** — `bin/ww` continues to function (with degraded output) if libs are missing. Appropriate for an install tool.

6. **Consistent exit code discipline** — 0/1/2 throughout. Libraries return, scripts exit. Followed project-wide.

7. **No dead dependencies.** The `package.json` has one dependency (`@google/generative-ai`). No dependency sprawl.

8. **The browser UI** is light and maintainable — vanilla JS SPA with CSS custom properties, no build step, no framework overhead.

---

## 8. Priority Improvements

### Critical

| # | Issue | Fix |
|---|---|---|
| C1 | Temp files leak on `set -e` early exit | Add `trap 'rm -rf "$tmp"' EXIT` after every `mktemp` call in bin/ww (lines 1652, 1695, 2420, 4475) |
| C2 | Interactive `read` in error-handler.sh has no timeout | Add `-t 30` to all `read` calls; print a default-action message on timeout |

### High

| # | Issue | Fix |
|---|---|---|
| H1 | Inconsistent service dispatch (some use `bash`, some use wrapper functions) | Standardize: either extract all inline `cmd_*` functions to service scripts, or always dispatch via `bash` with a common wrapper that logs and checks exit codes |
| H2 | Browser Python server has no signal handler | Add `trap 'kill $server_pid 2>/dev/null' EXIT SIGTERM SIGINT` in `_browser_start()` |
| H3 | Fallback log functions in bin/ww don't match real signatures | Either remove the fallback (fail loudly if libs missing) or match the real function signatures exactly, including stderr routing |
| H4 | Dead code: `WW_MAIN_ARGS=()` | Remove, or document what it was intended for |

### Medium

| # | Issue | Fix |
|---|---|---|
| M1 | Multiple `sed -i.bak` calls in profile-manager.sh | Consolidate into one sed call with `-e` expressions |
| M2 | Embedded Python heredoc in bash (questions system) | Extract to `services/questions/runner.py`; pass args via env — makes it independently testable |
| M3 | `ww browser start` doesn't echo the URL | Add `log_success "Browser running at http://localhost:${port}"` |
| M4 | config-loader.sh silently corrects invalid config values instead of erroring | Warn + return 1 on invalid config so misconfiguration is caught at load time |
| M5 | Service discovery O(n²) deduplication | Replace array linear search with an associative array: `declare -A seen_services` |

### Low

| # | Issue | Fix |
|---|---|---|
| L1 | `WW_VERSION="1.0.0"` hardcoded | Read from `$WW_BASE/VERSION` file, or auto-detect from `git describe` |
| L2 | warrior.sh has no warning for deleted/missing profiles | Add `profile_exists "$profile"` check before querying task data |
| L3 | Browser HTTP server not documented as localhost-only | Add a note to `--help` and the browser README |
| L4 | `mktemp /tmp/ww_q_XXXXXX.py` uses hardcoded `/tmp/` | Use `${TMPDIR:-/tmp}` for portability |

---

## Overall Score: 7.5 / 10

**This is a well-engineered bash project with real architectural discipline** — the sourced-vs-executed boundary, explicit fragility registers, and meaningful test coverage put it comfortably above most CLI tools of this scope. The main weaknesses are the monolithic `bin/ww`, the temp file cleanup gap (a reliability risk, not cosmetic), and the inconsistent service dispatch pattern. None of these are fundamental — they're fixable without structural changes. The foundation is solid enough to build on confidently.
