# Extensions Service

The Extensions service maintains registries for external tool extensions.

## Taskwarrior extensions

```bash
ww extensions taskwarrior refresh
ww extensions taskwarrior list --status active
ww extensions taskwarrior search vim
ww extensions taskwarrior info taskwiki
ww extensions taskwarrior cards
```

Registry location:
`WW_BASE/config/extensions.taskwarrior.yaml`

### Filters

- `--category`
- `--status` (active|stale|dormant)
- `--language`
- `--owner`
- `--limit`
- `--format json`

### Overview Cards

Use `cards` to print cached overview cards (description + synopsis + link).
