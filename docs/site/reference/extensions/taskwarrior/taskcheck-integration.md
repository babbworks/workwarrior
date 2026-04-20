# taskcheck Integration — ww schedule

**Upstream:** https://github.com/00sapo/taskcheck
**Author:** 00sapo · MIT License · Python
**Binary:** `taskcheck`
**Last assessed:** 2026-04-09 (source inspected)

---

## Summary

taskcheck automatically schedules tasks into working hours around calendar events,
respecting urgency and dependencies. It finds an optimal time for each task and
sets the `scheduled:` field in TaskWarrior. Adds two UDAs: `estimated` (hours to
complete) and `time_map` (which working-hours block to use).

---

## Profile Isolation

taskcheck accepts `--taskrc` to set TASKRC/TASKDATA. ww passes this flag on every
run. However, taskcheck's config file (`taskcheck.toml`) is resolved via
`appdirs.user_config_dir("task")` — a global path that cannot be overridden via CLI.

**ww's solution:** Per-profile config lives at
`profiles/<name>/.config/taskcheck/taskcheck.toml`. Before each `ww schedule run`,
ww copies the profile's config to the global location. Since taskcheck is a
single-user, single-run tool, this is safe.

---

## Toggle System

Each profile has an independent enable/disable toggle:

```
profiles/<name>/.config/taskcheck/enabled      ← presence = enabled
profiles/<name>/.config/taskcheck/taskcheck.toml  ← per-profile config
```

`ww schedule run` checks for the `enabled` file before executing. Disabling
preserves the config — re-enabling resumes with the same settings.

---

## UDAs Added

| UDA | Type | Label | Notes |
|-----|------|-------|-------|
| `estimated` | numeric | Estimated Hours | Expected hours to complete |
| `time_map` | string | Time Map | Working hours key (e.g. `work`, `weekend`) |

Both appear in `ww profile uda list` with `[extension:taskcheck]` badge.

---

## Quick Start

```bash
p-work
ww schedule install           # install taskcheck
ww schedule enable            # enable + create default config
ww schedule config            # edit working hours in taskcheck.toml
task 42 modify estimated:2    # set estimated hours on a task
task 42 modify time_map:work  # assign to work time map
ww schedule run --dry-run     # preview scheduling
ww schedule run               # apply scheduling
```

---

## Config Structure

`taskcheck.toml` defines working hours per time_map:

```toml
[time_maps.work]
monday = [[9, 12.30], [14, 17]]
tuesday = [[9, 12.30], [14, 17]]
wednesday = [[9, 12.30], [14, 17]]
thursday = [[9, 12.30], [14, 17]]
friday = [[9, 12.30], [14, 17]]

[time_maps.weekend]
saturday = [[10, 13]]
sunday = [[10, 13]]
```

Edit with `ww schedule config`.

---

## Note on Maintenance

The upstream author has moved to Super Productivity. taskcheck is stable but
no longer actively developed. The ww integration is a thin wrapper — if taskcheck
stops working with a future Python version, the wrapper can be updated independently.
