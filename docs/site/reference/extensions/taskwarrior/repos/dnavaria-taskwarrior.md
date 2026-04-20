# dnavaria/taskwarrior

**URL:** https://github.com/dnavaria/taskwarrior  
**Stars:** 0  
**Language:** Shell  
**Last push:** 2026-03-07  
**Archived:** No  
**Topics:** aws, cli, productivity, selfhosted, taskwarrior  

## Description

Personal TaskWarrior 3.x setup — config, hooks, shell aliases, cheatsheet, and a hardened Taskchampion sync server guide for AWS.

## Category

Sync

## Workwarrior Integration Rating

**Score:** 13  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +2: Sync capability relevant to ww profile isolation
- +3: UDAs — core to ww service model
- +1: Shell integration — ww is shell-first
- +1: Shell scripting — matches ww stack
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration

## README excerpt

```
# TaskWarrior Setup — dnavaria

Personal TaskWarrior configuration, hooks, scripts, and documentation.

**TaskWarrior Version:** 3.4.2  
**Platform:** macOS (Apple Silicon)  
**Shell:** zsh

---

## Directory Structure

```
taskwarrior/
├── README.md              # This file
├── taskrc                 # Main configuration (deployed to ~/.taskrc)
├── install.sh             # Automated setup script
├── docs/
│   ├── cheatsheet.md      # Command reference & 10 tutorials
│   └── server-setup.md    # Sync server deployment guide (AWS t3a, hardened)
├── hooks/                 # Git-tracked hooks (deployed to ~/.task/hooks/)
│   ├── on-add.01-inbox-tag.sh          # Auto-tag unprojects tasks as +inbox
│   ├── on-modify.01-project-remove-inbox.sh  # Remove +inbox when project assigned
│   └── on-add.02-effort-reminder.sh    # Remind to set effort on high-priority tasks
├── scripts/
│   └── aliases.sh         # Shell aliases & workflow functions
├── themes/                # Custom color themes (future)
└── backup/                # Config backups created by install.sh
```

---

## Quick Start

### 1. Install

```bash
# If TaskWarrior isn't installed yet:
brew install task

# Or use the setup script which handles everything:
./install.sh
```

### 2. Deploy Configuration

The `install.sh` script will:
- Back up your existing `~/.taskrc` and hooks
- Copy `taskrc` -> `~/.taskrc`
- Deploy hooks to `~/.task/hooks/`
- Print shell integration instructions

```bash
./install.sh
```

### 3. Shell Integration

Add to your `~/.zshrc`:

```bash
source /Users/dnavaria/project/taskwarrior/scripts/aliases.sh
```

Then reload:

```bash
source ~/.zshrc
```

### 4. Learn

Read the comprehensive cheatsheet:

```bash
open docs/cheatsheet.md
# Or in terminal:
# less docs/cheatsheet.md
```

---

## Configuration Highlights

### Custom Reports

| Command | Description |
|---|---|
| `task inbox` | Tasks needing triage (no project, no tags) |
| `task today` | Today's focus tasks |
| `task standup` | Daily standup (completions + active) |
| `task blockers` | Blocked/blocking dependency view |
| `task review` | Weekly review, grouped by project |
| `task hold` | Waiting/on-hold tasks |

### Contexts (Focus Modes)

| Context | Focus Area |
|---|---|
| `task context work` | Work, meetings, oncall |
| `task context personal` | Everything non-work |
| `task context learning` | Learning, reading, courses |
| `task context health` | Health, fitness, medical |
| `task context none` | Clear filter |

### Custom Fields (UDAs)

| Field | Values | Purpose |
|---|---|---|
| `effort` | trivial, small, medium, large, epic | Estimate task size |
| `category` | work, personal, learning, health, finance, admin | Classify tasks |
| `brainpower` | high, medium, low | Energy/focus required |

### Shell Aliases

| Alias | Command | Purpose |
|---|---|---|
| `t` | `task` | Short for task |
| `ta` | `task add` | Add task |
| `tl` | `task next` | List tasks |
| `td` | `task done` | Complete task |
| `tin` |
```