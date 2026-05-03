---
layout: doc
title: Getting Started
eyebrow: Documentation
description: Install Workwarrior, create your first profile, and start using all five tools in under 10 minutes.
permalink: /docs/getting-started
doc_section: basics
doc_order: 1
---

## Install

Requires bash or zsh on macOS or Linux. Python 3 for the browser UI.

```bash
git clone https://github.com/babbworks/ww ~/ww
cd ~/ww
./install.sh
source ~/.bashrc   # or source ~/.zshrc
```

The installer checks for each dependency and on macOS can install missing tools via Homebrew automatically. Each tool gets a version card showing installed vs required.

```bash
ww deps check      # Show dependency status
ww deps install    # Install any missing tools
```

## Create Your First Profile

A profile is an isolated workspace — its own task database, time tracking, journals, ledgers, and config.

```bash
ww profile create work
```

## Activate It

```bash
p-work
```

This sets five environment variables that all tools read. You're now in the `work` context. Every subsequent `task`, `timew`, `j`, and `l` command writes to this profile.

## Run Your First Commands

```bash
# Tasks
task add "Review the design doc" project:api priority:H due:friday
task list

# Time tracking (starts automatically when you start a task)
task 1 start
timew summary

# Journal
j "First day using workwarrior — profile model makes sense"

# Ledger
l balance
```

## Launch the Browser UI

```bash
ww browser
```

Opens `http://localhost:7777` — 15+ panels, dark terminal aesthetic, no npm, no cloud.

## Create More Profiles

```bash
ww profile create personal
ww profile create freelance

p-personal   # Switch to personal — all tools follow
p-work       # Back to work
```

Profiles are completely isolated. `p-work` tasks never appear in `p-personal` views. Backup is `tar`. Restore is `untar`.

## What's Next

- [Profiles](profiles) — multiple journals, ledgers, UDAs, backup/restore, groups
- [Browser UI](browser-ui) — the web interface in detail
- [Heuristic Engine](heuristics) — natural language commands without AI
- [Services](services) — all 25+ service domains
- [GitHub Sync](github-sync) — two-way task ↔ issue sync
