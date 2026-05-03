# Task Search Guide

Taskwarrior uses filters and pattern searches.

## Common patterns
```bash
# Keyword search
task /invoice/ list

# Attribute filters
task project:Work status:pending list

# Combine filters
task project:Work and /meeting/ list
```

## Tips
- Regex search requires `regex=on` in Taskwarrior config.
- Use `rc.verbose=nothing` to reduce output noise.
