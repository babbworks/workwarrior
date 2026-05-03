# taskgun Limitations Investigation
# Explorer output for TASK-EXT-GUN-001-EXPLORE
# Source: https://github.com/hamzamohdzubair/taskgun (commit inspected Apr 2026)

## Answers to the Five Questions

### 1. Does taskgun read TASKRC/TASKDATA env vars?

**YES — fully supported.**

`src/skip.rs` `find_taskrc()` (line ~130):
```rust
if let Ok(taskrc_env) = std::env::var("TASKRC") {
    return Ok(PathBuf::from(taskrc_env));
}
// Default location: ~/.taskrc
```

`src/taskwarrior.rs` tests explicitly set `TASKDATA` and `TASKRC` env vars before
calling `add_task()`. The `task add` command inherits the process environment, so
both `TASKRC` and `TASKDATA` are passed through correctly.

**ww integration:** No special handling needed. Setting `TASKRC`/`TASKDATA` before
calling `taskgun create` is sufficient. Profile isolation works automatically.

---

### 2. Do project names with spaces work?

**YES — with quoting.**

`src/taskwarrior.rs` `add_task()`:
```rust
cmd.arg("add")
   .arg(description)
   .arg(format!("project:{}", project));
```

Uses `Command::new("task").arg(...)` — each argument is passed as a separate OS
argument, not through a shell. Spaces in project names are handled correctly by
the OS argument passing. `"Design Patterns"` works as a project name.

**Limitation found:** The project name is passed as `project:Design Patterns` which
TaskWarrior interprets as `project:Design` with `Patterns` as a filter. The correct
form is `project:"Design Patterns"`. Since taskgun uses `.arg(format!(...))` without
quoting, **multi-word project names with spaces will be split by TaskWarrior**.

**Workaround:** Use underscores or hyphens: `"Design_Patterns"` or `"design-patterns"`.
ww gun help should document this limitation explicitly.

---

### 3. Does --skip accept arbitrary values or only weekend/bedtime?

**Both — built-in presets AND arbitrary values.**

`src/skip.rs` `SkipPresets::with_defaults()` defines two built-ins:
- `weekend` → Saturday + Sunday
- `bedtime` → 22:00–06:00

`parse_skip_arg()` first checks if the value is a preset name, then falls back to
`parse_skip_value()` which accepts:
- Time ranges: `2200-0600` or `22:00-06:00`
- Day lists: `mon,wed,fri` or `monday,wednesday,friday` (case-insensitive)

Custom presets can also be defined in `.taskrc` via `taskgun.skip.NAME=VALUE`.

**ww integration:** `ww gun` can pass `--skip` values through unchanged. The help
text should document the built-ins and the custom format.

---

### 4. Is there a --dry-run flag?

**NO — not implemented.**

Searched all files in `src/commands/`. No `--dry-run`, `--preview`, or `--simulate`
flag exists anywhere in the codebase. `taskgun create` writes tasks immediately.

**Impact for ww:** `ww gun create` cannot offer a preview mode unless ww implements
one itself (e.g., by printing what would be created without calling taskgun). This
should be noted in the integration doc and the task card updated.

---

### 5. What happens if TASKDATA points to a non-default location?

**Works correctly.**

`add_task()` calls `Command::new("task")` which inherits the full process environment.
TaskWarrior reads `TASKDATA` from environment to locate its data directory. The tests
in `taskwarrior.rs` confirm this pattern explicitly — they set `TASKDATA` to a temp
dir and verify tasks are written there.

**ww integration:** No issues. Standard ww profile activation sets `TASKDATA` and
taskgun respects it.

---

## Summary for TASK-EXT-GUN-001

| Question | Answer | Impact on ww gun |
|---|---|---|
| TASKRC/TASKDATA env vars | ✓ Fully supported | No special handling needed |
| Spaces in project names | ✗ Split by TaskWarrior | Document: use underscores/hyphens |
| --skip values | ✓ Presets + arbitrary time/day | Pass through unchanged |
| --dry-run | ✗ Not implemented | ww gun cannot offer preview |
| Non-default TASKDATA | ✓ Works via env | No issues |

**Recommendation:** TASK-EXT-GUN-001 can proceed. Update the task card to:
1. Document the project name space limitation in the integration doc
2. Remove the --dry-run mention from proposed syntax (not available upstream)
3. Add a note that `ww gun` is a thin passthrough — all taskgun flags work unchanged
