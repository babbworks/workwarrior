# TWDensity Integration

**Upstream:** https://github.com/00sapo/TWDensity
**Author:** 00sapo · MIT License · Python
**Last assessed:** 2026-04-09

---

## Summary

TWDensity adds a `density` UDA to TaskWarrior that counts how many tasks share
a similar due-date window. Urgency coefficients are assigned per density level,
so tasks in a crowded due-date cluster get a higher urgency boost — preventing
the common problem where many tasks pile up on the same date and all appear
equally urgent.

---

## Profile Isolation

TWDensity reads `TASKRC` and `TASKDATA` from environment. ww exports both on
profile activation. `ww profile density run` passes them explicitly — each
profile's density values are independent.

---

## Extension UDA Citation Pattern

This integration establishes the canonical pattern for citing extension-sourced UDAs
in ww. Any extension that adds UDAs follows this pattern:

1. **`service-uda-registry.yaml`** — add an `extensions:` section entry with:
   - `upstream` URL
   - `upstream_author` with license
   - `install` command
   - `known_udas` list with name, type, label, notes

2. **`profile-uda.sh`** — add UDA names to `_is_service_uda()` and `_uda_service()`
   returning `extension:<name>` as the service tag

3. **`ww profile uda list`** — extension UDAs appear in the Service-managed section
   with badge `[extension:twdensity]` instead of `[bugwarrior]` or `[github-sync]`

4. **Attribution** — upstream URL + author + license in: service script help,
   install output, integration doc, CSSOT `upstream_author` field

---

## UDAs Added

| UDA | Type | Label | Notes |
|-----|------|-------|-------|
| `density` | numeric | Due Density | Count of tasks with similar due dates |
| `densitywindow` | numeric | Density Window | Window size in days (default: 5) |

Urgency coefficients `urgency.uda.density.0..30.coefficient` are written to
`.taskrc` on install, scaling from 0.00 to 5.00 across 30 density levels.

---

## Quick Start

```bash
p-work
ww profile density install    # install twdensity + write UDAs
ww profile density run        # update density values
task list                     # density column now visible if added to report
```

---

## Keeping Density Current

Density values are static until you run `twdensity` again. Options:

- Manual: `ww profile density run` before planning sessions
- Routine: add to `ww routines` (TASK-EXT-CRON-001) once that's implemented
- Shell alias: `alias plan='ww profile density run && task next'`

---

## Customising the Window

The default density window is 5 days. To change it per-task:

```bash
task <id> modify densitywindow:3
```

Or change the default in `.taskrc`:
```
uda.densitywindow.default=7
```

---

## Relationship to ww urgency surface

`ww profile urgency` (TASK-URG-001) manages `urgency.uda.*` coefficients
interactively. The density coefficients written by `ww profile density install`
appear in `ww profile urgency show` and can be tuned via `ww profile urgency tune`.
The two surfaces are complementary — density install writes the initial coefficients,
urgency tune lets you adjust them.
