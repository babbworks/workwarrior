# Usage Examples

## Create and Activate a Profile

```bash
scripts/create-ww-profile.sh work
p-work
```

## Journal Workflows

```bash
# Default journal
j "Wrapped up feature X"

# Named journal
manage-profiles.sh info work
j work-log "Meeting notes"
```

## Ledger Workflows

```bash
# Default ledger
l balance
l add
```

## Global or Profile Scopes

```bash
# Use global workspace without activating a profile
list --global
l --global balance
task --global add "Global task"

# Target a profile directly
list --profile work
j --profile work "Weekly review"
timew --profile work summary
```

## Custom Configuration Shortcuts

```bash
# Profile-scoped custom configuration
j custom
l custom

# With explicit profile target
j --profile work custom
l --profile work custom
```

## Questions Service

```bash
# Show help and available services
q

# Create a new journal template
q new journal

# List templates for journal
q journal

# Use a template
q journal daily_reflection
```

## Profile Groups

```bash
# Create a group
ww groups create focus work personal

# Add a profile to a group
ww groups add focus client-x

# Show a group
ww groups show focus

# List all groups
ww groups list
```

## Models Service

```bash
# List configured models
ww models list

# Add a provider and model
ww models add-provider openai openai https://api.openai.com/v1 OPENAI_API_KEY
ww models add-model gpt-4o-mini openai gpt-4o-mini "fast"
ww models set-default gpt-4o-mini

# Show required env vars
ww models env

# Check required env vars
ww models check
```

## Find Service

```bash
# Search across all profiles
ww find invoice

# Search a specific profile and type
ww find --profile work --type journal meeting

# Include global workspace
ww find --global --type ledger rent

# Advanced query with boolean logic and filters
ww find --query '(invoice OR receipt) AND NOT draft'
ww find --query 'type:journal profile:work "weekly review" | group type'
ww find --case-sensitive Invoice
ww find --regex 'inv(oi)?ce'
ww find --exclude '*/archive/*' invoice

# Use native tool search
ww find --type task --native invoice
ww find --type time --native @client-x :week
ww find --type ledger --native 'desc:invoice'
```

## Search Guides

- `docs/search-guides/task.md`
- `docs/search-guides/time.md`
- `docs/search-guides/journal.md`
- `docs/search-guides/ledger.md`
- `docs/search-guides/list.md`

## Shortcut Reference

```bash
# List all shortcuts
ww shortcut list

# Show details for a shortcut
ww shortcut info j

# Add a user shortcut override
ww shortcut add x "Example" global "Example command" "echo hi" false

# Remove a user shortcut override
ww shortcut remove x
```

## Profile Backup and Restore

```bash
# Backup
scripts/manage-profiles.sh backup work ~/backups

# Restore (example)
tar -xzf work-backup-YYYYMMDDHHMMSS.tar.gz
mv profiles/work ~/ww/profiles/
```
