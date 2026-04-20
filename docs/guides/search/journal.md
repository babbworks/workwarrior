# Journal Search Guide

JRNL supports tag and text searches with date ranges.

## Common patterns
```bash
# Text search
jrnl -contains "invoice"

# Tag filters
jrnl @work -and @client-x

# Date ranges
jrnl -from "last month" -to "today"
```

## Tips
- Use `--config-file <jrnl.yaml>` to target a specific profile.
- Combine tags and `-contains` for precise results.
