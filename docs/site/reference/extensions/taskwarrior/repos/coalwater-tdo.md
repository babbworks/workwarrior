# coalwater/tdo

**URL:** https://github.com/coalwater/tdo  
**Stars:** 0  
**Language:** Go  
**Last push:** 2026-04-03  
**Archived:** No  
**Topics:** taskwarrior, todoist  

## Description

TaskWarrior-compatible CLI backed by Todoist. Cloud sync, mobile access, with the CLI you know.

## Category

Sync

## Workwarrior Integration Rating

**Score:** 12  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +2: Urgency coefficients are a ww UDA focus area
- +3: UDAs — core to ww service model
- +1: Shell scripting — matches ww stack
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration

## README excerpt

```
# tdo

TaskWarrior-compatible CLI backed by Todoist. Cloud sync, mobile access — with the CLI you know.

## Why

TaskWarrior has the best CLI for task management. Todoist has the best cloud sync, mobile app, and collaboration. `tdo` gives you both — TaskWarrior's command grammar with Todoist as the backend. No local database, no sync conflicts.

## Install

Download the latest binary from [GitHub Releases](https://github.com/coalwater/tdo/releases), or build from source:

```bash
go install github.com/abushady/tdo@latest
```

## Setup

Set your Todoist API token:

```bash
export TODOIST_API_KEY="your-token-here"
```

Get your token from [Todoist Settings > Integrations > Developer](https://app.todoist.com/app/settings/integrations/developer).

## Usage

If you know TaskWarrior, you know `tdo`. The ID goes before the command:

```bash
# List tasks
tdo list
tdo next

# Add a task
tdo add "Fix login bug" project:Backend priority:H due:tomorrow +urgent

# Task operations
tdo <id> info
tdo <id> done
tdo <id> modify priority:M due:today
tdo <id> start        # focus on this task
tdo <id> stop         # unfocus
tdo <id> annotate "Found the root cause"
tdo <id> delete

# Filter
tdo list project:Work +urgent priority:H
tdo list due.before:tomorrow

# Meta
tdo projects
tdo tags
```

### IDs

`tdo` uses Todoist's native IDs. After any `list` or `next` command, you can also use the positional number:

```bash
tdo list
#  ID                 Content              Pri  Due     Project
1  6gHh7gqw22hw8Q7w   Fix login bug         H   today   Backend
2  6g2hCVh7fQc57QvJ   Write API docs        M   +3d     Backend

tdo 1 done          # completes "Fix login bug"
```

### Attributes

```
project:<name>       # assign project
priority:H|M|L       # set priority
due:<date>           # natural language date
recur:<interval>     # daily, weekly, every 3 days
+<tag>               # add label
-<tag>               # remove label (modify only)
description:<text>   # task notes
```

### Urgency

Tasks are sorted by urgency using TaskWarrior's exact scoring algorithm — priority, due date, age, active status, tags, annotations, and project all factor in.

## Configuration

| Variable | Required | Default | Description |
|---|---|---|---|
| `TODOIST_API_KEY` | Yes | — | Todoist API token |
| `TDO_CACHE_TTL` | No | 300 | Task cache TTL in seconds |
| `TDO_NOW_LABEL` | No | "now" | Label used for `start`/`stop` |

## Differences from TaskWarrior

`tdo` aims to feel familiar, not to be a clone. Key differences:

- **IDs** are Todoist's alphanumeric IDs (positional numbers work after listing)
- **No local database** — everything lives in Todoist
- **No contexts, reports, UDAs, dependencies, or undo** (yet)
- **Recurrence** uses Todoist's natural language (`recur:every monday`)

## License

Apache 2.0 — see [LICENSE](LICENSE).

```