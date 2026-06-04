# Installing Workwarrior

## Quick start

```bash
git clone https://github.com/babbworks/ww ~/ww
cd ~/ww
./install.sh
source ~/.zshrc   # or open a new terminal
ww version
```

The installer is interactive. It walks you through preset selection, optional dependency installation, and shell configuration. Everything can be done non-interactively with flags:

```bash
./install.sh --preset basic --non-interactive --skip-deps
```

---

## Install presets

The preset controls how `ww` is wired into your shell and whether instance routing is enabled. Choose once at install time — you can reinstall with `--force` to change it.

| Preset | Launcher | Shell function | Registry | Use when |
|--------|----------|---------------|----------|----------|
| `basic` | PATH only | no | no | simplest setup, single install |
| `direct` | `~/.local/bin/ww` | no | no | explicit binary, no shell function overhead |
| `multi` | `~/.local/bin/ww` | yes | yes | multiple installs, `@instance` routing |
| `hidden` | `~/.local/bin/ww` | yes | yes | secondary install, excluded from default listing |
| `isolated` | `~/.local/bin/ww` | no | no | install now, register manually later |
| `hardened` | `~/.local/bin/ww` | yes | yes | multi + mandatory security unlock |

---

## How each preset wires into the shell

### basic

The simplest path. The installer adds a block to `~/.zshrc` (and `~/.bashrc` if present) that exports `WW_BASE` and sources `ww-init.sh`:

```bash
# --- Workwarrior Installation (ww) ---
export WW_BASE="$HOME/ww"
if [[ -f "$HOME/ww/bin/ww-init.sh" ]]; then
  source "$HOME/ww/bin/ww-init.sh"
fi
# --- End Workwarrior Installation (ww) ---
```

`ww-init.sh` adds `~/ww/bin` to `PATH`, making `ww` available as a plain binary. It also defines the profile shell functions (`j`, `l`, `task`, `timew`, `p-<name>`) and sets `WARRIOR_PROFILE`, `WORKWARRIOR_BASE`, `TASKRC`, `TASKDATA`, `TIMEWARRIORDB` when a profile is active.

Full chain from terminal open to command:

```
~/.zshrc
  └─ source ~/ww/bin/ww-init.sh
       ├─ PATH += ~/ww/bin          → enables: ww, task, timew as binaries
       ├─ defines: j(), l(), i()    → journal, ledger, issues shortcuts
       ├─ defines: p-<name>()       → profile activation aliases
       └─ sets: WW_BASE, WARRIOR_PROFILE (if profile was previously active)

ww <command>
  └─ ~/ww/bin/ww                    → bash script, routes to services/
```

---

### direct

Identical shell-init behavior to `basic`, but instead of relying on PATH, a launcher script is written to `~/.local/bin/ww`:

```bash
#!/usr/bin/env bash
export WW_BASE="/path/to/ww"
exec "/path/to/ww/bin/ww" "$@"
```

The RC block still sources `ww-init.sh` for profile functions. The launcher is the explicit entry point — it hardcodes `WW_BASE` so `ww` works even if `WW_BASE` is not in the environment. Lower runtime overhead than the `multi` bootstrap because there is no instance resolution step.

---

### multi

The flagship preset for users who want multiple named installs or `@instance` dispatch. Instead of sourcing `ww-init.sh` directly, the RC file sources a **bootstrap script** written to `~/.config/<cmd>/bootstrap.sh`:

```bash
# --- Workwarrior Installation (ww) ---
source "$HOME/.config/ww/bootstrap.sh"
# --- End Workwarrior Installation (ww) ---
```

The bootstrap defines a `ww()` **shell function** (not a binary lookup) that:

1. Reads `~/.config/ww/registry/` to find instance install paths
2. Resolves which instance should handle the command (last-used, explicitly addressed, or env-pinned)
3. Dispatches: `env WW_BASE="<install_path>" <install_path>/bin/ww "$@"`

The bootstrap also defines `_ww_resolve_default_base()`, `_ww_instance_path()`, and `_ww_prompt_prefix()` for prompt integration. A `task()` and `timew()` wrapper are also injected so those commands route through the active instance.

Full chain from terminal open to command:

```
~/.zshrc
  └─ source ~/.config/ww/bootstrap.sh
       ├─ exports: WW_CONFIG_HOME, WW_REGISTRY_DIR, WW_LAST_INSTANCE_FILE
       ├─ defines: ww()               → shell function (not binary)
       ├─ defines: task(), timew()    → instance-aware wrappers
       ├─ defines: _ww_resolve_default_base()
       │    └─ reads ~/.config/ww/registry/*.json
       │         └─ picks instance by: WW_ACTIVE_INSTANCE > WW_BASE > last-used
       └─ hooks _ww_apply_prompt_prefix into precmd/PROMPT_COMMAND

ww <command>
  └─ ww()                             → shell function
       └─ _ww_resolve_default_base()  → returns ~/ww (or other instance path)
            └─ env WW_BASE=~/ww ~/ww/bin/ww <command>
                 └─ ~/ww/bin/ww       → bash script, routes to services/
```

**Instance registry** — `~/.config/ww/registry/`

Each registered instance has a JSON manifest:

```json
{
  "id": "main",
  "alias": "main",
  "install_path": "/Users/you/ww",
  "preset": "multi",
  "command_name": "ww",
  "visibility": "visible",
  "status": "active"
}
```

**`@instance` dispatch** — addressing a specific instance:

```bash
ww @main profile list        # routes to the 'main' instance
ww @dev task add "fix it"    # routes to the 'dev' instance
```

The shell function intercepts any argument starting with `@`, resolves the install path from the registry, and execs `<install_path>/bin/ww` with the remaining arguments.

**Companion activation function** — `~/.config/ww/instance-functions.sh`

For multi-instance workflows, the installer also writes per-instance activation functions into `~/.config/ww/instance-functions.sh`. Each function (e.g., `wwdev()`, called with no arguments) sets `WW_BASE`, activates a profile, and exports the full profile environment:

```bash
wwdev()          # no args: activate the wwdev instance + last-used profile
wwdev task list  # with args: pass-through to wwdev instance
```

---

### hidden

Identical to `multi` but the instance manifest has `"visibility": "hidden"`. It does not appear in `ww instance list` by default and is not selected by last-used resolution unless `allow_hidden_last=on` in `~/.config/ww/runtime.conf`. Useful for a secondary install that should not interfere with the primary `ww` workflow.

---

### isolated

Writes a launcher to `~/.local/bin/<cmd>` but does **not** write a bootstrap or register the instance. The RC block sources `ww-init.sh` directly. Useful when you want to install the files first and decide on registration later:

```bash
ww instance register main ~/ww   # register after the fact
```

---

### hardened

Like `multi` but the bootstrap additionally checks for a security unlock before dispatching. The instance must be unlocked with a credential (keychain on macOS, libsecret/pass on Linux) before commands run. The security backend is configured at install time with `--security-backend auto|keychain|libsecret|pass`.

```bash
ww unlock main          # unlock the instance (prompts for credential)
ww security status      # show lock state
ww security lock main   # re-lock
```

---

## What goes into shell RC files

On macOS the installer writes to `~/.zshrc` and `~/.bashrc` (if it exists). On a fresh machine with neither file, it creates `~/.zshrc`.

Every install writes a delimited block marked with the command name so multiple installs can coexist in the same RC file without collision:

```
# --- Workwarrior Installation (ww) ---
...
# --- End Workwarrior Installation (ww) ---

# --- Workwarrior Installation (wwdev) ---
...
# --- End Workwarrior Installation (wwdev) ---
```

Reinstalling with the same command name replaces only that block. Legacy blocks from older installs (marked `# --- Workwarrior Installation ---` without a name) are migrated and backed up automatically.

---

## ww-init.sh — what it injects

`ww-init.sh` is sourced at shell start for all non-multi presets (and also from within bootstrap-based installs when a profile is active). It is safe to source multiple times — an init guard prevents duplicate injection.

What it does when sourced:

- Adds `$WW_BASE/bin` to `PATH`
- Exports `WW_BASE`
- Defines shell functions:
  - `j [args]` — journal shortcut (`jrnl --config-file <profile-jrnl.yaml>`)
  - `l [args]` — ledger shortcut (`hledger -f <profile-ledger>`)
  - `i [args]` — issues shortcut (`ww issues`)
  - `q [args]` — questions shortcut
  - `task [args]` — routes through active instance
  - `timew [args]` — routes through active instance
- Defines `p-<name>()` aliases for each profile found under `$WW_BASE/profiles/`
- Restores last active profile from `~/.config/<cmd>/last-profile-<cmd>` if `resume_last=on`

---

## Command name and multiple installs

The installer accepts a custom command name (`--cmd <name>`). Each name gets its own config directory, registry, bootstrap, and shell block. Installing `ww` (default) and `wwdev` produces:

```
~/.config/ww/
  bootstrap.sh          → defines ww() shell function
  registry/
    main.json           → points to ~/ww

~/.config/wwdev/
  bootstrap.sh          → defines wwdev() shell function
  registry/
    main.json           → points to ~/ww-dev

~/.zshrc
  source ~/.config/ww/bootstrap.sh
  source ~/.config/wwdev/bootstrap.sh
```

Both `ww` and `wwdev` are available as independent shell functions with separate registries, last-instance tracking, and profile state.

---

## Dependency installation

The installer offers interactive per-tool dependency installation at the start. Each tool gets a version card showing installed version, latest available (fetched from brew/GitHub/PyPI), and the WW minimum. You can upgrade, keep, or skip each one.

```bash
ww deps install    # run dep installer standalone
ww deps check      # show status without installing
```

If you skip deps during install, everything still installs — deps can be added any time.

---

## Non-interactive install

```bash
./install.sh --non-interactive --preset basic --skip-deps
./install.sh -y --preset multi --cmd ww --skip-deps
```

`--non-interactive` / `-y` skips all prompts and uses defaults. `--skip-deps` skips the dependency installation step. Combine for fully automated installs.

---

## Platform notes

**macOS (bash 3.2):** The installer is bash 3.2 compatible. macOS ships `/bin/bash` 3.2 and zsh as the default terminal shell. The installer writes to `~/.zshrc` (and `~/.bashrc` if present). `#!/usr/bin/env bash` resolves to the system bash; all bash 4+ constructs (`mapfile`, `declare -A`, `${var^^}`) have been replaced with 3.2-compatible equivalents.

**Linux:** `apt`, `dnf`, and `pacman` are detected. Dep installs on Linux show the right command — you run it; auto-install is macOS/brew only.

**Windows/WSL:** Not officially supported.
