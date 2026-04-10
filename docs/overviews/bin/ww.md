# bin/ww — Main CLI Dispatcher

**Type:** Executed bash script  
**Size:** ~2686 lines  
**Shebang:** `#!/usr/bin/env bash` + `set -euo pipefail`

---

## Role

Single entry point for all `ww` commands. Parses global flags, resolves profile scope, then dispatches to service scripts or internal command functions. Never sources lib files directly — calls service scripts as subprocesses or delegates to lib via service scripts.

---

## Startup Sequence

```
main()
  → parse_global_flags()       # strip --profile/--global/--json/--compact/--verbose
  → resolve_scope_context()    # set WARRIOR_PROFILE/WORKWARRIOR_BASE/TASKRC/TASKDATA
  → case "$command" in ...     # dispatch to cmd_* function or service script
```

---

## Global Flags

| Flag | Effect |
|---|---|
| `--profile <name>` | Override active/last profile for this invocation only |
| `--global` | Force global context (unsets all profile env vars) |
| `--json` | Set `WW_OUTPUT_MODE=json` |
| `--compact` | Set `WW_OUTPUT_MODE=compact` |
| `--verbose` | Set `WW_VERBOSE=1` |
| `--help` / `-h` | Show usage or command-specific help |

`--profile` and `--global` are mutually exclusive. `--json` and `--compact` are mutually exclusive.

---

## Scope Resolution (`resolve_scope_context`)

Priority order:
1. `--profile <name>` flag
2. `--global` flag (unsets all profile vars)
3. Active shell profile (`WARRIOR_PROFILE` env var already set)
4. Last active profile (`~/.ww/.state/last_profile`)

If a profile is resolved, exports: `WARRIOR_PROFILE`, `WORKWARRIOR_BASE`, `TASKRC`, `TASKDATA`, `TIMEWARRIORDB`.

---

## Command Functions (internal)

| Function | Command | Notes |
|---|---|---|
| `cmd_profile()` | `ww profile` | Delegates to `services/profile/` scripts; also routes `urgency`, `uda`, `density` subcommands |
| `cmd_service()` | `ww service` | Discovers service categories via `discover_services()` |
| `cmd_journal()` | `ww journal` | Reads/writes `jrnl.yaml` via `lib/profile-manager.sh` |
| `cmd_ledger()` | `ww ledger` | Reads/writes `ledgers.yaml` via `lib/profile-manager.sh` |
| `cmd_group()` | `ww group` | Delegates to `services/groups/groups.sh` |
| `cmd_models()` | `ww model` | Delegates to `services/models/models.sh` |
| `cmd_extensions()` | `ww extensions` | Delegates to `services/extensions/extensions.sh` |
| `cmd_find()` | `ww find` | Delegates to `services/find/find.sh` |
| `cmd_custom()` | `ww custom` | Delegates to `services/custom/configure-*.sh` |
| `cmd_issues()` | `ww issues` | Routes to bugwarrior or `services/custom/github-sync.sh` |
| `cmd_shortcut()` | `ww shortcut` | Sources `lib/shortcode-registry.sh` |
| `cmd_deps()` | `ww deps` | Sources `lib/dependency-installer.sh` |
| `cmd_tui()` | `ww tui` | Execs `taskwarrior-tui` binary with `--taskrc`/`--taskdata` |
| `cmd_next()` | `ww next` | Execs `next` binary (scheduler) with profile env |
| `cmd_gun()` | `ww gun` | Execs `taskgun` binary with profile env |
| `cmd_schedule()` | `ww schedule` | Manages taskcheck toggle + config copy + exec |
| `cmd_mcp()` | `ww mcp` | Installs/registers/runs `taskwarrior-mcp` server |
| `cmd_browser()` | `ww browser` | Delegates to `services/browser/` |

---

## Service Discovery

`discover_services(category)` scans `services/<category>/` and (if a profile is active) `$WORKWARRIOR_BASE/services/<category>/` for executable files. Profile-level services shadow global ones with the same filename.

---

## Serialization Constraint

`bin/ww` is a SERIALIZED file — one writer at a time. Never include it in a parallel worktree alongside any other active task that also modifies it. All new commands are added as `cmd_<name>()` functions and wired into the `case` block in `main()`.

---

## Adding a New Top-Level Command

1. Add `cmd_<name>()` function (follow existing pattern — check profile, check binary, exec with env)
2. Add `<name>)` case in `main()` dispatcher
3. Add to `show_usage()` command list and relevant Commands section
4. Add domain to `system/config/command-syntax.yaml`
5. Write `docs/taskwarrior-extensions/<name>-integration.md` if wrapping an external tool

## Changelog

- 2026-04-10 — Initial version
