# Getting Started

## Install

Requires bash or zsh on macOS or Linux. Python 3 for the browser UI.

```bash
git clone <repo-url> ~/ww
cd ~/ww
./install.sh
source ~/.bashrc   # or source ~/.zshrc
```

The installer detects your platform, checks for dependencies, and offers to install missing tools via brew/apt/dnf/pacman. Each tool gets a version card showing installed vs. required versions.

After install, the `ww` command is available in your shell.

## Create Your First Profile

```bash
ww profile create work
```

This creates an isolated workspace at `profiles/work/` with its own TaskWarrior database, TimeWarrior instance, journal, and ledger.

## Activate It

```bash
p-work
```

This sets environment variables that point all tools at the profile's data. Every subsequent `task`, `timew`, `j`, and `l` command operates within this profile.

## Use the Tools

```bash
# Tasks
task add "Review PR" project:api priority:H due:tomorrow +review
task list
task 1 start          # Also starts time tracking via hook

# Time
timew summary         # This week's time
timew day             # Today's breakdown

# Journal
j "Sprint planning complete — 8 stories committed"
j standup "Daily standup notes"

# Ledger
l balance             # Account balances
l register expenses   # Transaction register
```

## Launch the Browser UI

```bash
ww browser
```

Opens a locally-served web interface at `http://localhost:7777` with panels for tasks, time, journals, ledgers, and a unified command input that accepts natural language.

## Create More Profiles

```bash
ww profile create personal
ww profile create freelance
```

Switch between them instantly:

```bash
p-personal    # All tools now point at personal data
p-work        # Back to work
```

## What's Next

- [Profiles](profiles.md) — multiple journals, ledgers, UDAs, backup/restore
- [Commands](commands.md) — the full command surface
- [Browser UI](browser.md) — the web interface in detail
- [Services](services.md) — all 20+ service domains
- [Weapons](weapons.md) — task manipulation tools
