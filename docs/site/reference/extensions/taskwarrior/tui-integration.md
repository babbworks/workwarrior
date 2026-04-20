# TUI Integration: taskwarrior-tui

**Upstream:** https://github.com/kdheepak/taskwarrior-tui
**Author:** Karthikeyan Singaravelan (@kdheepak)
**License:** MIT
**Version assessed:** 0.26.12 (latest as of 2026-04-08)
**Stars:** 1982 · Last push: 2026-04-08 (actively maintained)

---

## Summary

`taskwarrior-tui` is a Rust-based full-screen terminal UI for TaskWarrior built on ratatui.
It integrates into workwarrior with **zero source modification** — profile isolation works
automatically through ww's existing `TASKRC`/`TASKDATA` environment variables.

---

## Profile Isolation — How It Works

ww exports these env vars on profile activation:

```
TASKRC    = ~/ww/profiles/<name>/.taskrc
TASKDATA  = ~/ww/profiles/<name>/.task
```

`taskwarrior-tui` accepts `--taskrc` and `--taskdata` CLI flags (maps directly to these vars)
and also inherits parent environment for any subprocesses it spawns. ww passes both flags
explicitly at launch:

```bash
exec taskwarrior-tui --taskrc "$TASKRC" --taskdata "$TASKDATA"
```

TUI-specific config lives in each profile's `.taskrc` via the `uda.taskwarrior-tui.*`
prefix — it follows the profile automatically with no extra wiring.

---

## Integration Decision: No Modification

| Factor | Assessment |
|--------|------------|
| License | MIT — permissive, no restrictions on integration |
| Profile isolation | Native via env vars and `--taskrc`/`--taskdata` flags |
| Config scoping | Per-profile via `uda.taskwarrior-tui.*` in `.taskrc` |
| Subprocess env pass-through | Yes — `Command::new("task")` inherits parent env |
| Source modification required | **No** |
| Binary delivery | System-wide via `brew install taskwarrior-tui` |
| Upstream maintenance | Active (push today) |

Decision: **wrap the unmodified binary**. ww owns the profile handoff; the binary does the rest.

---

## What ww Adds

- `ww tui` — launch TUI for active profile (checks profile + binary)
- `ww tui install` — install via brew (fallback: cargo)
- `ww tui help` — usage + attribution
- Profile guard (clear error if no profile active)
- Binary guard (clear error + install hint if not found)
- Attribution line visible in scroll buffer after TUI exits

---

## Attribution

Attribution is surfaced in two places:

1. **`ww tui help`** — full credit line:
   > Powered by taskwarrior-tui · Karthikeyan Singaravelan (@kdheepak)
   > https://github.com/kdheepak/taskwarrior-tui · MIT License

2. **On TUI exit** — printed to scroll buffer before `exec` (persists in terminal history
   after alt-screen restore):
   > `taskwarrior-tui · @kdheepak · MIT · github.com/kdheepak/taskwarrior-tui`

---

## Key Capabilities (from README)

- Vim-like navigation (`j`/`k`/`gg`/`G`)
- Live filter with instant updates
- Add, modify, complete, delete, log tasks
- Multiple task selection
- Tab completion for task attributes
- Colours follow TaskWarrior theme settings
- TimeWarrior start/stop integration (`s` key)

---

## Per-Profile TUI Config

Users can customise keybindings and appearance per profile by adding UDAs to the profile's
`.taskrc`. Example (added by user or via `ww custom tasks`):

```ini
uda.taskwarrior-tui.keyconfig.quit = q
uda.taskwarrior-tui.keyconfig.refresh = r
uda.taskwarrior-tui.task-report.next.filter = status:pending
```

Since these live in the profile `.taskrc`, they are automatically scoped to the profile.

---

## Future Considerations

- `ww custom tasks` could offer a TUI config wizard (add common UDA keybinds)
- Shell function `tt` could be added to shell-integration.sh as a convenience alias for `ww tui`
- If a profile-specific TUI report or layout becomes common, a ww profile template could
  seed the relevant `uda.taskwarrior-tui.*` defaults in new profiles

---

## Rejected Alternatives

| Option | Rejected Because |
|--------|-----------------|
| Fork and patch source | Zero benefit; upstream maintained; creates maintenance debt |
| Embed binary in ww repo | Licensing allows it but adds binary bloat; brew is cleaner |
| Build from source in ww install | Too heavy; brew handles versioning |
| Symlink to profile TASKRC in default location | Fragile; env var approach is already correct |
