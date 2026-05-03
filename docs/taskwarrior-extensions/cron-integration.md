# allgreed/cron integration (`ww routines`)

`ww routines` integrates [allgreed/cron](https://github.com/allgreed/cron) as a profile-scoped recurring task workflow.

## What it does

- Uses Python routine definition files to generate TaskWarrior tasks.
- Runs with active profile isolation via `TASKRC` and `TASKDATA`.
- Stores routine files and runtime state per profile.

## Storage layout

For active profile `<name>`:

- `profiles/<name>/.config/routines/*.py` - routine definitions
- `profiles/<name>/.config/routines/cron.py` - linked runtime shim
- `profiles/<name>/.config/routines/.ww-routines-state.json` - last-run metadata

Runtime source is installed at:

- `$WW_BASE/tools/extensions/cron`

## Commands

```bash
ww routines list
ww routines add "<desc>" --frequency weekly [--name <name>]
ww routines new <name>
ww routines edit <name>
ww routines run [name]
ww routines status
ww routines install
ww routines help
```

## Typical flow

```bash
# 1) Install or update upstream runtime
ww routines install

# 2) Create a new template
ww routines new clean_room

# 2b) Or generate directly from a description
ww routines add "Clean room" --frequency weekly

# 3) Run all routines
ww routines run

# 4) Inspect state
ww routines status
```

## Notes

- `ww routines install` requires `git`.
- Running routines requires `python3`.
- `new` creates a cron-style template and opens the file in `$EDITOR` (set `WW_ROUTINES_NO_EDIT=1` to skip editor launch in automation/tests).

## Attribution

Powered by `allgreed/cron` by allgreed:
https://github.com/allgreed/cron
