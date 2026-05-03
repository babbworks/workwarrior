# Weapons

Workwarrior Weapons are tools that manipulate data from the four main functions
(tasks, times, journals, ledgers) in special ways — creating, slicing, packaging,
and altering data.

## Design Principle

Each weapon operates on profile-scoped data via the standard environment variables
(TASKRC, TASKDATA, TIMEWARRIORDB, journal_file, ledger_file). Weapons respect the
active resource selection (non-default tasklists, journals, etc.).

## Weapons Registry

| Weapon | Icon | Type | Description | Source |
|--------|------|------|-------------|--------|
| Gun | 🔫 | Extension | Bulk task series generator with deadline spacing | taskgun · hamzamohdzubair · MIT · Rust |
| Sword | ⚔ | Native | Task splitting into sequential subtasks with dependencies | ww-native (cmd_sword in bin/ww) |
| Bat | 🏏 | Planned | TBD | — |
| Fire | 🔥 | Planned | TBD | — |
| Slingshot | 🏹 | Planned | TBD | — |

## Architecture

Weapons are invoked via `ww <weapon> <args>` and dispatched from `bin/ww`.

- **Extension weapons** (Gun): thin passthrough to an external binary. The binary
  is installed separately (cargo, brew, pipx). ww adds profile env and attribution.
  Config and docs live in `weapons/<name>/`.

- **Native weapons** (Sword): implemented directly in `bin/ww` as `cmd_<weapon>()`.
  No external binary needed. Config and docs live in `weapons/<name>/`.

## Profile Data Treatment

All weapons must:
1. Read TASKRC/TASKDATA from environment (set by profile activation)
2. Respect the active resource selection from `get_profile_paths()`
3. Work with non-default tasklists, journals, ledgers, and timew instances
4. Not modify data outside the active profile's scope

## Browser UI

Weapons appear in the sidebar weapons bar. Each has a dedicated section with a form.
The browser routes weapon commands through `POST /cmd` → `ww <weapon> <args>`.

## Adding a New Weapon

1. Create `weapons/<name>/README.md` with description and attribution
2. Add `cmd_<name>()` to `bin/ww` (or passthrough to external binary)
3. Add to ALLOWED_SUBCOMMANDS in `services/browser/server.py`
4. Add HTML section and JS handler in browser static files
5. Add to the weapons bar in `index.html`
6. Update this README's registry table

## LLM Integration (Optional)

Weapons can optionally use LLM for intelligent operations (e.g., Sword with `--ai`
for semantic task splitting). The mechanism:
1. Check `config/ai.yaml` for enabled providers and access mode
2. Use the same provider resolution as CMD AI (`config/models.yaml`)
3. Fall back to mechanical operation if no LLM available
4. User controls AI access via CTRL panel: off / local-only / local+remote
