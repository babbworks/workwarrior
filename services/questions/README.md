# Service: questions

The Questions Service provides templated question workflows for consistent data capture.

## Key Files

- `q.sh` - Main Questions Service interface
- `templates/` - Template JSON files (per service type)
- `handlers/` - Service-specific answer processors
- `bin/` - Utility scripts for template management

## Typical Usage

```bash
q
q help
q new journal
q journal daily_reflection
q list
q edit daily_reflection
q delete daily_reflection --yes
```

## Requirements

- Python 3 is required for JSON parsing.
- A profile must be active (`WORKWARRIOR_BASE` set).

## Behavior Notes

- Template lists are deterministic (sorted).
- Template names accept: letters, numbers, dot (`.`), underscore (`_`), hyphen (`-`).
- `q delete <template>` is interactive by default; use `--yes` for non-interactive deletion.
- Actionable errors are returned with next-step hints (`q help`, `q new <service>`, `q edit <template>`).
