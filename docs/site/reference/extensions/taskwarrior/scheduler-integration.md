# scheduler Integration — ww next

**Upstream:** https://github.com/ftapajos/scheduler
**Author:** Flávio Tapajós (ftapajos) · GPL-3.0 · Python
**Binary:** `next` (installed via `pipx install taskwarrior-scheduler`)
**Last assessed:** 2026-04-09

---

## Summary

`taskwarrior-scheduler` recommends which task to work on next by combining
TaskWarrior urgency with TimeWarrior time-already-spent. Inspired by the Linux
CFS (Completely Fair Scheduler) — prevents high-urgency tasks from monopolising
all attention by factoring in how much time has already been spent on each task's
tags.

---

## Profile Isolation

`tasklib.TaskWarrior()` (used internally) reads `TASKRC` and `TASKDATA` from
environment when no explicit `data_location` is passed — confirmed from source
and test fixtures. `ww next` passes `TASKRC`, `TASKDATA`, and `TIMEWARRIORDB`
explicitly. Each profile's recommendation is independent.

The TimeWarrior on-modify hook (already installed per profile by ww) is required
for time data to be available. Without it, the scheduler falls back to pure urgency.

---

## How It Works

1. Reads pending tasks from TaskWarrior (filtered by any args passed)
2. Reads time tracking data from TimeWarrior for each task's tags
3. Computes a "virtual time" — how much time each task *should* have received
   based on its urgency share
4. Compares virtual time to actual time spent
5. Recommends the task most "behind" relative to its urgency share

If no TimeWarrior data exists yet, falls back to the most urgent task.

---

## Quick Start

```bash
p-work
ww next install       # install taskwarrior-scheduler
ww next               # get recommendation
ww next +work         # filter to +work tagged tasks
ww next project:dev   # filter to dev project
```

---

## License Note

taskwarrior-scheduler is GPL-3.0 (not MIT). ww wraps it as an external binary —
no source is incorporated into ww. The GPL applies to the scheduler binary itself,
not to ww. Users who install it accept the GPL-3.0 terms for that binary.

---

## Relationship to ww profile density

`ww profile density` (TWDensity) adjusts urgency based on due-date clustering.
`ww next` uses urgency as one input. Running `ww profile density run` before
`ww next` gives the scheduler more accurate urgency scores to work with.

Suggested workflow:
```bash
ww profile density run && ww next
```
