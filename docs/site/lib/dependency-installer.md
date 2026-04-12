# lib/dependency-installer.sh

**Type:** Sourced bash library  
**Invoked by:** `ww deps install`, `install.sh`

---

## Role

Per-tool interactive installer with version transparency. Presents a card per tool showing installed/latest/minimum versions, platform-specific install command, default files created, and ww integration details. After each successful install, neutralises the tool's default config to prevent conflicts with ww's profile isolation.

---

## Tool Cards

**`run_dependency_installer()`**  
Main entry point. Iterates the tool list in install order: `task`, `timew`, `hledger`, `jrnl`, `pipx`, `bugwarrior`. For each tool, shows a card and prompts to install/skip/upgrade.

**`get_tool_description(tool)`** — One-line role description.  
**`get_tool_default_files(tool)`** — Files the tool creates by default (that ww needs to neutralise).  
**`get_tool_ww_integration(tool)`** — How ww integrates with this tool.  
**`get_tool_install_cmd(tool)`** — Platform-detected install command (brew/apt/dnf/pacman).

---

## Version Detection

**`check_all_dependencies()`** — Checks all tools, populates status arrays.  
**`display_dependency_status()`** — Shows installed/missing/version for each tool.

---

## Conflict Neutralisation

**`neutralise_tool_defaults(tool)`**  
Called immediately after each successful install. Prevents the tool from writing to global locations that would conflict with ww's profile isolation:

- **TaskWarrior:** Writes a sentinel `~/.taskrc` with `data.location=/dev/null` and `hooks=off`. When a user runs bare `task` without activating a ww profile, they get a clear error instead of silently writing to `~/.task/`.
- **TimeWarrior:** Similar sentinel for `~/.timewarrior/`.
- **Bugwarrior:** Sets `BUGWARRIORRC` to point to a non-existent path so bare `bugwarrior` fails visibly.

**`restore_tool_configs()`** — Called by `uninstall.sh`. Finds the most recent `.pre-ww-<date>` backup and restores it.

---

## Bugwarrior Install

Bugwarrior requires a two-step install on Python 3.12+:
```bash
pipx install bugwarrior
pipx inject bugwarrior setuptools
```
The `setuptools` inject is required because `taskw` (a bugwarrior dependency) imports `distutils.version.LooseVersion`, which was removed in Python 3.12. Single-command install fails silently on first run.

---

## WW_INSTALL_DIR

`WW_INSTALL_DIR="${WW_INSTALL_DIR:-$HOME/ww}"` — never `readonly`. Allows `WW_INSTALL_DIR=/tmp/ww-test ./install.sh` for testing. The shell RC block uses an unquoted heredoc (`<< EOF` not `<< 'EOF'`) so `${WW_INSTALL_DIR}` expands to the actual chosen path at write time.

## Changelog

- 2026-04-10 — Initial version
