---
layout: doc
title: Weapons
eyebrow: Documentation
description: Task manipulation tools — Gun, Sword, Next, Schedule — and the weapons system.
permalink: /docs/weapons
doc_section: reference
doc_order: 2
---

Weapons are tools that manipulate profile data in special ways — creating, slicing, and packaging tasks. They appear as a weapons bar in the browser sidebar.

## Sword

Splits a single task into N sequential subtasks with dependency chains. Native to ww.

```bash
ww sword <task_id> -p <N>                    # Split into N sequential parts
ww sword <task_id> -p 4 --interval 2d        # 2-day intervals between due dates
ww sword <task_id> -p 3 --prefix "Phase"     # Custom prefix
```

Each subtask receives:
- Description: "Part N of: {original}"
- Parent's project and tags
- Due date offset by N × interval from now
- Dependency on the previous subtask

The chain is strictly sequential — "Part 3" can't be completed until "Part 2" is done. The parent task is archived after the split.

## Gun

Bulk task series generator. Wraps [taskgun](https://github.com/hamzamohdzubair/taskgun) (Rust).

```bash
ww gun <args>    # Arguments passed to taskgun
```

Creates multiple related tasks with deadline spacing. Useful for recurring deliverables, sprint planning, or any N tasks spread across a time range.

## Next

CFS-inspired next-task recommendation.

```bash
ww next
```

Recommends the single optimal task to work on next, weighing urgency scores, deadline proximity, and context signals.

## Schedule

Auto-scheduler for time blocks. Wraps [taskcheck](https://github.com/taskcheck/taskcheck).

```bash
ww schedule
```

Assigns time blocks to tasks based on estimates, deadlines, and available time.

## Planned Weapons

| Weapon | Status |
|--------|--------|
| Bat | Planned |
| Fire | Planned |
| Slingshot | Planned |

## All Weapons Follow These Rules

- Read TASKRC/TASKDATA from environment — profile isolation is always respected
- Work via `POST /cmd` in the browser UI — available from the weapons bar
- Never modify data outside the active profile's scope
- Respond to `--help`
