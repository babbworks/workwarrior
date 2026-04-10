# lib/installer-utils.sh — Cross-Cutting: Install Infrastructure

**Type:** Sourced bash library
**Used by:** `install.sh`, `uninstall.sh`, `lib/dependency-installer.sh`
**Classification:** Cross-cutting — install infrastructure used by both the main installer and the dependency installer

---

## Role

Low-level install infrastructure: shell detection, rc file management, directory structure creation, version checking. Used by both `install.sh` (ww itself) and `lib/dependency-installer.sh` (external tools).

---

## Shell Detection

**`detect_shell()`** — Returns `bash`, `zsh`, or `unknown` based on `$SHELL` and running process.

**`get_shell_rc_files()`** — Returns list of rc files for the detected shell(s). Checks for existence of `.bashrc`, `.zshrc`, `.bash_profile`. Returns all that exist. Creates `.bashrc` as fallback if none found.

---

## RC File Management

**`add_ww_to_shell_rc(install_dir)`** — Appends the ww bootstrap block to all detected rc files:
```bash
# === WW INIT ===
export WW_BASE="/Users/mp/ww"
source "$WW_BASE/bin/ww-init.sh"
# === END WW INIT ===
```
Uses an unquoted heredoc (`<< EOF` not `<< 'EOF'`) so `${WW_INSTALL_DIR}` expands to the actual install path at write time — not the literal string.

**`remove_ww_from_shell_rc()`** — Removes the `# === WW INIT ===` block from all rc files. Used by `uninstall.sh`.

---

## Install Structure

**`create_install_structure(install_dir)`** — Creates the ww directory tree at the install location. Called by `install.sh` before copying files.

**`is_ww_installed()`** — Returns 0 if `$WW_BASE/bin/ww` exists and is executable.

**`get_installed_version()`** — Reads `$WW_BASE/VERSION` file. Returns "unknown" if not found.

---

## Dependency Checks

**`command_exists(name)`** — Returns 0 if a command is on PATH. Thin wrapper around `command -v`.

**`check_dependencies()`** — Checks for required tools (`bash`, `git`, `jq`) and optional tools (`task`, `timew`, `hledger`, `jrnl`, `bugwarrior`). Returns a structured status report.

---

## WW_INSTALL_DIR

`WW_INSTALL_DIR="${WW_INSTALL_DIR:-$HOME/ww}"` — never `readonly`. Allows custom install paths for testing (`WW_INSTALL_DIR=/tmp/ww-test ./install.sh`) and multi-user systems. The rc block records the actual chosen path, not the default.
