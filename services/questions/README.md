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
q new journal
q journal daily_reflection
```

## Requirements

- Python 3 is required for JSON parsing.
- A profile must be active (`WORKWARRIOR_BASE` set).
