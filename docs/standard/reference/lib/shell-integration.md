# lib/shell-integration.sh

**Type:** Sourced bash library  
**Size:** ~1190 lines  
**Fragility:** SERIALIZED — one writer at a time; broken shell integration breaks all profile activation

---

## Role

Injects shell functions and aliases into the user's shell session. Manages the `p-<name>` profile activation aliases, the `j`/`l`/`task`/`timew`/`i`/`q` shell functions, and the rc file write mechanism. Sourced via `bin/ww-init.sh` at shell start.

---

## Re-source Safety

Guard at top: `[[ -n "${SHELL_INTEGRATION_LOADED:-}" ]] && return 0`  
The guard variable is never `readonly` — re-sourcing `.bashrc`/`.zshrc` is a normal user action and must not error.

---

## RC File Management

**`get_ww_rc_files()`**  
Returns the list of shell rc files to write to (`.bashrc`, `.zshrc`, or both). Creates `.bashrc` as fallback if neither exists. This is the canonical source for all alias/config writes — never hardcode `.bashrc` or `.zshrc` paths anywhere else.

**`add_alias_to_section(alias_name, alias_value, [rc_file])`**  
Appends an alias to the WW ALIASES section of the rc file. Idempotent — silently returns 0 if alias already present (no output, no noise).

**`ensure_shell_functions()`**  
Ensures the `ww-init.sh` source line is present in all rc files. Does NOT inject per-function stubs — all functions are defined in this file and sourced via `ww-init.sh`. Silent no-op for established installs.

---

## Profile Alias Management

**`create_profile_aliases(profile_name)`**  
Writes `p-<name>` alias to all rc files. Also writes bare `<name>` alias unless the name is reserved (`ww`, `task`, `timew`, `jrnl`, `hledger`). Reserved names only get `p-<name>` to avoid shadowing system commands.

**`remove_profile_aliases(profile_name)`**  
Removes all aliases for a profile from all rc files.

---

## Shell Functions Injected

These are defined in this file and become available in the user's shell after sourcing:

**`use_task_profile(name)`** — Core profile activation. Sets all five env vars, calls `set_last_profile()`.

**`j([journal-name] entry)`** — Write to JRNL. Resolves journal name from `jrnl.yaml`. Supports `--profile` and `--global` scope flags.

**`l([args])`** — Access default Hledger ledger for active profile.

**`task([args])`** — TaskWarrior passthrough with profile TASKRC/TASKDATA.

**`timew([args])`** — TimeWarrior passthrough with profile TIMEWARRIORDB.

**`list([args])`** — List management tool passthrough.

**`i([args])`** — Issues service. Routes to bugwarrior (pull) or github-sync (push/sync/status). Synonymous with `ww issues`.

**`q([args])`** — Questions service passthrough.

**`search([args])`** — Routes to `ww find`. Named `search` (not `find`) to avoid shadowing the system `find` binary.

---

## Design Decisions

- `ensure_shell_functions()` is a source-line check only — never injects per-function stubs into rc files. Stubs create maintenance splits and diverge from the lib file over time.
- `get_ww_rc_files()` is the single source of truth for rc file discovery — all write operations loop over its output.
- Reserved CLI names (`ww`, `task`, `timew`, `jrnl`, `hledger`) never get bare aliases — only `p-<name>` form.
- Profile creation output is signal-only: no per-alias lines, no idempotency notices. Single `✓ Aliases written → .bashrc .zshrc` summary.

## Changelog

- 2026-04-10 — Initial version
