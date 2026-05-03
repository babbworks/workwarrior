# List Search Guide

The `list` tool is plain‑text; use filters and external search.

## Common patterns
```bash
# View list and filter in shell
list | rg invoice

# Search list files directly
rg invoice ~/ww/profiles/work/list
```

## Tips
- `list` is minimal by design; it doesn’t have a native search DSL.
- Prefer `ww find --type list` for cross‑profile list searches.
