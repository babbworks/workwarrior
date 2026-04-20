# Weapons

Weapons are tools that manipulate profile data in special ways — creating, slicing, and packaging tasks. They appear in the browser sidebar as a weapons bar.

## Gun

Bulk task series generator. Wraps [taskgun](https://github.com/hamzamohdzubair/taskgun) (Rust).

Creates a series of tasks with deadline spacing — useful for recurring deliverables, sprint planning, or any situation where you need N tasks spread across a time range.

```bash
ww gun <args>
```

## Sword

Task splitting into sequential subtasks with dependency chains. Native to ww (no external binary).

Takes a single task and splits it into N parts, each depending on the previous one:

```bash
ww sword 5 -p 3                    # Split task 5 into 3 parts
ww sword 5 -p 4 --interval 2d     # 2-day intervals between parts
ww sword 12 -p 2 --prefix "Phase" # Custom prefix
```

Each subtask gets:
- Description: "Part N of: <original description>"
- The parent task's project and tags
- A due date offset by N × interval from now
- A dependency on the previous subtask (sequential chain)

## Next

CFS-inspired scheduler that recommends the optimal next task based on urgency, deadlines, and context. Wraps the `next` binary.

```bash
ww next
```

## Schedule

Auto-scheduler that assigns time blocks to tasks. Wraps [taskcheck](https://github.com/taskcheck/taskcheck).

```bash
ww schedule
```

## Design Principles

All weapons:
- Read TASKRC/TASKDATA from environment (profile isolation)
- Respect the active resource selection
- Work through `POST /cmd` in the browser UI
- Never modify data outside the active profile's scope

## Planned Weapons

| Weapon | Status |
|--------|--------|
| Bat | Planned |
| Fire | Planned |
| Slingshot | Planned |
