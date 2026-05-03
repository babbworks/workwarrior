---
layout: doc
title: Profiles
eyebrow: Documentation
description: Complete reference for the Workwarrior profile model — isolation, multiple resources, UDAs, backup, groups.
permalink: /docs/profiles
doc_section: basics
doc_order: 2
---

A profile is a directory containing everything for one work context. Complete isolation — no data shared between profiles, no tool aware of any other profile's existence.

## Structure

```
profiles/<name>/
  .taskrc              TaskWarrior config (UDAs, reports, urgency)
  .task/               Task database
  .timewarrior/        Time tracking database
  journals/            Journal files (multiple named journals supported)
  ledgers/             Hledger ledger files (multiple named ledgers)
  jrnl.yaml            Journal name → file mapping
  ledgers.yaml         Ledger name → file mapping
  .config/             Service configs (bugwarrior, taskcheck)
```

## Activation

```bash
p-work             # Activate the 'work' profile
```

Behind the scenes, this exports:
- `WARRIOR_PROFILE=work`
- `WORKWARRIOR_BASE=~/ww/profiles/work`
- `TASKRC=~/ww/profiles/work/.taskrc`
- `TASKDATA=~/ww/profiles/work/.task`
- `TIMEWARRIORDB=~/ww/profiles/work/.timewarrior`

Every tool reads these variables automatically. Switching profiles is instant — just environment variable changes.

## Lifecycle

```bash
ww profile create <name>       # Create
ww profile list                # List all
ww profile info <name>         # Details and resource inventory
ww profile delete <name>       # Delete (creates safety backup first)
ww profile backup <name>       # Archive to tar.gz
ww profile import <archive>    # Create from archive
ww profile restore <archive>   # Replace existing from archive
```

`ww remove <name>` goes further than `profile delete` — it scrubs the profile from all config references, removes aliases from shell rc files, and optionally deletes or archives the data directory.

## Multiple Named Resources

One profile can have multiple journals and ledgers:

```bash
ww journal add strategy
ww journal add engineering
ww journal add standup

j strategy "Board discussed the Q3 roadmap"
j engineering "Refactored the auth module — removed 200 lines"
j standup "Blocked on the API rate limit issue"
```

Same for ledgers:

```bash
ww ledger add business
ww ledger add personal

l business balance
l personal register
```

The browser UI shows a dropdown selector when multiple resources exist. Switching resources updates the panel data immediately.

## Profile Groups

Group profiles for batch operations:

```bash
ww group create clients
ww group add clients acme
ww group add clients globex

ww export --group clients     # Export all client profiles
ww profile backup --group clients
```

## UDA Management

User Defined Attributes extend every task in the profile with typed custom fields:

```bash
ww profile uda list            # All UDAs — source badges show [github] [extension] [custom]
ww profile uda add client      # Interactive creation wizard
ww profile uda group work      # Apply a UDA template group
ww profile uda perm client nosync   # Exclude field from GitHub sync
```

## Urgency Tuning

```bash
ww profile urgency             # Interactive coefficient tuner
```

Adjusts how TaskWarrior's urgency algorithm weights due date, priority, age, project, tags, and custom UDAs for this profile. Different profiles can have completely different urgency models.

## Backup Policy

Profile backups are self-contained `.tar.gz` archives of the entire profile directory. `ww profile import <archive>` reconstructs the profile including all data, config, and resource mappings. Safety backups are created automatically before deletion.
