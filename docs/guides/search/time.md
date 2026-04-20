# Time Search Guide

Timewarrior searches by intervals and tags.

## Common patterns
```bash
# This week summary
timew summary :week

# Filter by tag
timew summary :week @client-x

# Explicit range
timew summary 2025-01-01 - 2025-01-07 @deepwork
```

## Tips
- Timewarrior does not do full‑text search; use tags and intervals.
- For a specific interval ID, use `timew summary ID`.
