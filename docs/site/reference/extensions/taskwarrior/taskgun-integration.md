# taskgun Integration

**Upstream:** https://github.com/hamzamohdzubair/taskgun
**Author:** hamzamohdzubair · MIT License · Rust
**Last assessed:** 2026-04-09 (source inspected)

---

## Summary

taskgun generates deadline-spaced task series from a single command. Give it a
project name, number of parts, unit name, start offset, and interval — it creates
all tasks with calculated due dates. Useful for book chapters, lecture series,
practice sets, or any sequential work that needs external deadline pressure.

---

## Profile Isolation

taskgun reads `TASKRC` and `TASKDATA` from environment (confirmed from source).
`ww gun create` passes both explicitly — each profile's tasks are independent.

---

## Known Limitation: Project Names with Spaces

taskgun passes the project name as `project:NAME` to the `task` CLI. TaskWarrior
splits on spaces, so `"Design Patterns"` becomes `project:Design` with `Patterns`
treated as a filter expression.

**Use underscores instead:**
```bash
ww gun create Design_Patterns -p 3,4,2 -u Section --offset 3d --interval 3d
```

TaskWarrior displays `Design_Patterns` cleanly in reports. This is a taskgun
upstream limitation — not fixable without modifying taskgun source.

---

## --skip Values

Two built-in presets:
- `weekend` — skips Saturday and Sunday
- `bedtime` — skips 22:00–06:00 (hour-based scheduling only)

Custom values accepted:
- Time range: `2200-0600` or `22:00-06:00`
- Day list: `mon,wed,fri` or `monday,wednesday,friday`

Custom presets can be defined in `.taskrc`:
```
taskgun.skip.lunchbreak=1200-1300
```

---

## No --dry-run

taskgun has no preview mode. Tasks are written immediately on `ww gun create`.
Plan your series carefully before running — use `task undo` if you need to reverse.

---

## Quick Start

```bash
p-work
ww gun install                    # install via cargo

# 10 ML lectures, one per day starting in 2 days
ww gun create ML_Course -p 10 -u Lecture --offset 2d --interval 1d

# 12 book chapters, one per week, skipping weekends
ww gun create CLRS -p 12 -u Chapter --offset 7d --interval 7d --skip weekend

# 30 exam revision lectures, every 2 hours, skipping bedtime
ww gun create Exam_Prep -p 30 -u Lecture --offset 2h --interval 2h --skip bedtime

# Book with uneven chapters: 3 sections, 4 sections, 2 sections
ww gun create Design_Patterns -p 3,4,2 -u Section --offset 3d --interval 3d
```

---

## Full Flag Reference

All taskgun flags pass through `ww gun create` unchanged:

```bash
taskgun create --help
```

---

## Relationship to ww urgency

Tasks created by taskgun have due dates set. TaskWarrior's urgency scoring
automatically boosts tasks as their due date approaches. Combined with
`ww profile density` (TWDensity), tasks in a dense due-date cluster get
an additional urgency boost — useful when a lecture series has many tasks
due in the same week.
