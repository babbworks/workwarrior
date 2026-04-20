# Workwarrior — Install Policy

## Core toolchain: `ww deps install` is canonical

`ww deps install` is the single authoritative install path for the core toolchain:

- **TaskWarrior** (`task`) — task management
- **TimeWarrior** (`timew`) — time tracking
- **Hledger** (`hledger`) — ledger accounting
- **JRNL** (`jrnl`) — journaling
- **pipx** — Python tool isolation (required for jrnl and bugwarrior)
- **gh** — GitHub CLI (required for github-sync)

The installer detects your package manager and emits the correct install command:

| Platform | Package manager | Behavior |
|---|---|---|
| macOS | brew | Auto-installs via `brew install <tool>` |
| Debian/Ubuntu | apt | Emits `apt install <tool>` — you run it |
| Fedora/RHEL | dnf | Emits `dnf install <tool>` — you run it |
| Arch/Manjaro | pacman | Emits `pacman -S <tool>` — you run it |
| Other | unknown | Emits manual install URLs |

On macOS, `ww deps install` runs the installs automatically after confirmation.
On Linux, it shows you the right command for your distro — you run it yourself.

```bash
ww deps install    # interactive, platform-aware
ww deps check      # show dependency status without installing
```

---

## Extension installs: best-effort with platform guidance

Extension-specific install subcommands (`ww tui install`, `ww mcp install`) are
**best-effort**: they auto-install on macOS via brew, and on Linux they emit the
platform-appropriate install hint without auto-installing.

### `ww tui install` (taskwarrior-tui)

On **macOS** (brew present): runs `brew install taskwarrior-tui` automatically.

On **macOS** (brew absent, cargo present): runs `cargo install taskwarrior-tui`.

On **Linux**: detects your package manager and shows the right command:

| Linux distro | Recommended command |
|---|---|
| Debian/Ubuntu | `cargo install taskwarrior-tui` or `snap install taskwarrior-tui` |
| Fedora/RHEL | `cargo install taskwarrior-tui` |
| Arch/Manjaro | `sudo pacman -S taskwarrior-tui` or `yay -S taskwarrior-tui` |

### `ww mcp install` (taskwarrior-mcp)

`ww mcp install` installs the [taskwarrior-mcp](https://github.com/hnsstrk/taskwarrior-mcp)
MCP server. It requires `uv` (Python package manager).

On **macOS** (brew present): runs `brew install uv` automatically if needed.

On **Linux**: detects your package manager and shows the right `uv` install command:

| Linux distro | Recommended command |
|---|---|
| Debian/Ubuntu | `curl -LsSf https://astral.sh/uv/install.sh \| sh` or `pip install uv` |
| Fedora/RHEL | `curl -LsSf https://astral.sh/uv/install.sh \| sh` or `pip install uv` |
| Arch/Manjaro | `sudo pacman -S uv` or `curl -LsSf https://astral.sh/uv/install.sh \| sh` |

After installing `uv`, re-run `ww mcp install`.

---

## What "best-effort" means

Extension install subcommands will:
- Never silently fail with no actionable output
- Always emit a platform-appropriate install command on Linux
- Auto-install only on macOS via brew (the only verified auto-install path)
- Exit with a non-zero code if installation cannot proceed

They will **not**:
- Auto-install on Linux (too many distro variations, privilege requirements)
- Install without your confirmation on macOS (brew confirms before install)

---

## First-time setup sequence

```bash
# 1. Install core toolchain
ww deps install

# 2. Create your first profile
ww profile create work

# 3. Activate the profile (re-open terminal or source your RC)
p-work

# 4. Verify everything works
ww deps check
task list
timew summary

# 5. (Optional) Install extensions
ww tui install    # taskwarrior-tui interactive UI
ww mcp install    # MCP server for AI agent access
```

---

## Platform notes

**macOS:** Fully supported. Homebrew is the recommended package manager.
All `ww deps install` installs and extension auto-installs use brew.

**Linux:** Core toolchain install is supported via apt/dnf/pacman with
platform-appropriate hints. Extension auto-install is not implemented on Linux
(manual install with provided commands). Live Linux testing is deferred to post-v1.

**Windows/WSL:** Not officially supported in v1.
