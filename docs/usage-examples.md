# Usage Examples

## Create and Activate a Profile

```bash
scripts/create-ww-profile.sh work
p-work
```

## Journal Workflows

```bash
# Manage journals via ww lifecycle commands
ww journal add work-log
ww journal rename work-log client-work
ww journal list
ww journal remove client-work

# Default journal
j "Wrapped up feature X"

# Named journal
manage-profiles.sh info work
j work-log "Meeting notes"
```

## Ledger Workflows

```bash
# Manage ledgers via ww lifecycle commands
ww ledger add business
ww ledger rename business biz-main
ww ledger list
ww ledger remove biz-main

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
q help

# Create a new journal template
q new journal

# List templates for journal
q journal
q list

# Use a template
q journal daily_reflection

# Non-interactive delete (automation-friendly)
q delete daily_reflection --yes
```

## Profile Groups

```bash
# Preferred singular namespace for actions
ww group create focus work personal

# Add a profile to a group
ww group add focus client-x

# Show a group
ww group show focus

# List all groups (both forms supported)
ww group list
ww groups
```

## Models Service

```bash
# Preferred singular namespace for actions
ww model list

# Add a provider and model
ww model add-provider openai openai https://api.openai.com/v1 OPENAI_API_KEY
ww model add-model gpt-4o-mini openai gpt-4o-mini "fast"
ww model set-default gpt-4o-mini

# Show required env vars
ww model env

# Check required env vars
ww model check

# Plural bare call lists models
ww models
```

## Journal and Ledger List UX

```bash
# Both forms list journals
ww journal list
ww journals

# Both forms list ledgers
ww ledger list
ww ledgers
```

## Compatibility Nudges (Legacy Forms Still Work)

```bash
# Legacy plural form still runs, but warns with preferred replacement
ww journals list      # prefer: ww journal list
ww ledgers list       # prefer: ww ledger list
ww groups list        # prefer: ww group list
ww models list        # prefer: ww model list
ww profiles           # prefer: ww profile list
ww services           # prefer: ww service list
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

## Extensions Service

```bash
ww extensions taskwarrior refresh
ww extensions taskwarrior list --status active
ww extensions taskwarrior search vim
ww extensions taskwarrior info taskwiki
ww extensions taskwarrior cards

# Standalone (no ww prefix)
extensions taskwarrior list --status active
models
groups
journals
ledgers
find
services
tasks
times
```

## Standalone Help

```bash
ww help
ww help profile
ww help custom
ww help standalone
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

## Profile Backup, Import, and Restore

```bash
# Backup a profile to home directory (default)
ww profile backup work

# Backup to a specific directory
ww profile backup work ~/backups

# Import a backup as a new profile (profile must not already exist)
ww profile import ~/work-backup-20260101120000.tar.gz

# Import under a different name (useful for cloning or migration)
ww profile import ~/work-backup-20260101120000.tar.gz work-copy

# Restore an existing profile from backup (overwrites current data)
# A safety backup is created automatically before any changes are made
ww profile restore work ~/work-backup-20260101120000.tar.gz

# Rolling back after a restore — use the safety backup printed during restore
ww profile restore work ~/work-pre-restore-20260404153000.tar.gz
```

**Import vs restore:**
- `import` — archive becomes a *new* profile; errors if profile already exists
- `restore` — archive *replaces* an existing profile; always creates a safety backup first
