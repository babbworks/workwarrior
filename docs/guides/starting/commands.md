# Commands

Everything routes through `ww`, but shell functions provide shortcuts for the most common operations.

## Shell Functions

Available after profile activation (injected by `ww-init.sh`):

| Function | What it does |
|----------|-------------|
| `p-<name>` | Activate a profile |
| `task [args]` | TaskWarrior with profile isolation |
| `timew [args]` | TimeWarrior with profile isolation |
| `j [journal] "entry"` | Write to journal |
| `l [args]` | Hledger with profile ledger |
| `i [args]` | Issue sync (bugwarrior + github-sync) |
| `q [args]` | Questions service |
| `list [args]` | List management |
| `search [args]` | Cross-profile search |

## The ww Command

### Profile Management
```bash
ww profile create/list/info/delete/backup/import/restore
ww profile uda list/add/remove/group/perm
ww profile urgency
ww profile density
```

### Data Services
```bash
ww journal add/list/remove/rename
ww ledger add/list/remove/rename
ww find <term>
ww export
```

### System Services
```bash
ww service list/info/help
ww group list/create/show/add/remove/delete
ww model list/providers/show/add-provider/set-default
ww ctrl status/ai-on/ai-off/ai-status
ww shortcut list/info/add/remove
ww extensions taskwarrior list/search/info
ww deps install/check
ww q / ww questions
```

### Weapons
```bash
ww gun <args>                  # Bulk task series
ww sword <id> -p <parts>      # Split task into subtasks
ww next                        # Next-task recommendation
ww schedule                    # Auto-scheduler
```

### Issue Sync
```bash
ww issues sync/push/pull/status/enable/disable/custom
```

### Browser and Build
```bash
ww browser [--port N] [--no-open] [stop|status]
ww compile-heuristics [--verbose] [--digest]
ww remove <profile> [--keep|--all|--archive-all|--delete-all|--dry-run]
```

## Scope Flags

Some commands support targeting a profile without activating it:

```bash
j --profile work "Entry"       # Write to work's journal directly
l --global balance             # Use global ledger
task --profile work list       # List work's tasks
```

## Standalone Commands

These work without the `ww` prefix:

```bash
extensions taskwarrior list
models
groups
journals
ledgers
find
services
tasks
times
```
