# GitHub Two-Way Sync - Configuration Guide

## Configuration File Location

Configuration is stored per-profile at:
```
$WORKWARRIOR_BASE/.config/github-sync/config.sh
```

Example path:
```
~/.workwarrior/profiles/my-profile/.config/github-sync/config.sh
```

## Default Configuration

The configuration file is automatically created from a template on first use. Here's the default configuration with explanations:

```bash
#!/usr/bin/env bash
# GitHub Sync Configuration

# ============================================================================
# Repository Settings
# ============================================================================

# Default repository (optional)
# If set, you can omit the repo parameter in commands
# Format: owner/repo
GITHUB_SYNC_DEFAULT_REPO=""

# ============================================================================
# Sync Behavior
# ============================================================================

# Conflict resolution strategy
# Options: last_write_wins (only option currently)
GITHUB_SYNC_CONFLICT_STRATEGY="last_write_wins"

# Auto-sync on task modification (future feature)
# When enabled, tasks will sync automatically when modified
GITHUB_SYNC_AUTO_SYNC="false"

# Fields to sync (comma-separated)
# Available: description,status,priority,tags,annotations
GITHUB_SYNC_FIELDS="description,status,priority,tags,annotations"

# ============================================================================
# Filtering
# ============================================================================

# Tags to exclude from sync (comma-separated)
# These tags will not be synced to GitHub labels
# System tags (ACTIVE, READY, etc.) are always excluded
GITHUB_SYNC_EXCLUDE_TAGS=""

# Labels to exclude from sync (comma-separated)
# These labels will not be synced to TaskWarrior tags
GITHUB_SYNC_EXCLUDE_LABELS=""

# ============================================================================
# Annotation/Comment Settings
# ============================================================================

# Prefix for TaskWarrior annotations synced to GitHub
# Used to identify comments that came from TaskWarrior
GITHUB_SYNC_TW_PREFIX="[TaskWarrior]"

# Prefix for GitHub comments synced to TaskWarrior
# Format: "[GitHub @username]" (username is added automatically)
GITHUB_SYNC_GH_PREFIX="[GitHub"

# ============================================================================
# Logging
# ============================================================================

# Log level
# Options: DEBUG, INFO, WARNING, ERROR
GITHUB_SYNC_LOG_LEVEL="INFO"

# Maximum log file size (bytes)
# Logs rotate when they reach this size
# Default: 10485760 (10MB)
GITHUB_SYNC_LOG_MAX_SIZE="10485760"

# Maximum log age (days)
# Old log files are deleted after this many days
GITHUB_SYNC_LOG_MAX_AGE="30"

# ============================================================================
# Rate Limiting
# ============================================================================

# Delay between API calls (seconds)
# Helps avoid rate limiting
GITHUB_SYNC_RATE_LIMIT_DELAY="1"

# ============================================================================
# Retry Settings
# ============================================================================

# Maximum number of retries for failed operations
GITHUB_SYNC_MAX_RETRIES="3"

# Delay between retries (seconds)
GITHUB_SYNC_RETRY_DELAY="5"

# ============================================================================
# Debug
# ============================================================================

# Debug mode (enables verbose logging)
# Options: true, false
GITHUB_SYNC_DEBUG="false"
```

## Configuration Examples

### Example 1: Single Repository Setup

For users who primarily work with one repository:

```bash
# Set default repository
GITHUB_SYNC_DEFAULT_REPO="myorg/myproject"

# Now you can omit the repo parameter:
# Instead of: i enable-sync 1 42 myorg/myproject
# You can use: i enable-sync 1 42
```

### Example 2: Exclude Private Tags

Prevent certain tags from syncing to GitHub:

```bash
# Exclude private and local tags
GITHUB_SYNC_EXCLUDE_TAGS="private,local,personal,draft"

# These tags will stay in TaskWarrior only
task add "Secret project" +private +feature
# The 'private' tag won't sync, but 'feature' will
```

### Example 3: Exclude GitHub Labels

Prevent certain labels from syncing to TaskWarrior:

```bash
# Exclude GitHub-specific labels
GITHUB_SYNC_EXCLUDE_LABELS="wontfix,duplicate,invalid,good first issue"

# These labels won't create tags in TaskWarrior
```

### Example 4: Custom Prefixes

Customize annotation/comment prefixes:

```bash
# Shorter prefixes
GITHUB_SYNC_TW_PREFIX="[TW]"
GITHUB_SYNC_GH_PREFIX="[GH"

# Or more descriptive
GITHUB_SYNC_TW_PREFIX="[From TaskWarrior]"
GITHUB_SYNC_GH_PREFIX="[From GitHub"
```

### Example 5: Debug Mode

Enable verbose logging for troubleshooting:

```bash
# Enable debug mode
GITHUB_SYNC_DEBUG="true"

# Reduce log rotation threshold for testing
GITHUB_SYNC_LOG_MAX_SIZE="1048576"  # 1MB

# Keep logs for shorter period
GITHUB_SYNC_LOG_MAX_AGE="7"  # 7 days
```

### Example 6: Conservative Rate Limiting

For users concerned about API rate limits:

```bash
# Increase delay between API calls
GITHUB_SYNC_RATE_LIMIT_DELAY="2"

# Reduce retries
GITHUB_SYNC_MAX_RETRIES="2"
GITHUB_SYNC_RETRY_DELAY="10"
```

### Example 7: Selective Field Sync

Sync only specific fields:

```bash
# Sync only description and status (no tags, priority, annotations)
GITHUB_SYNC_FIELDS="description,status"

# Or sync everything except annotations
GITHUB_SYNC_FIELDS="description,status,priority,tags"
```

## Advanced Configuration

### Per-Repository Configuration

While not directly supported, you can create wrapper scripts for different repositories:

```bash
# ~/bin/sync-work
#!/bin/bash
export GITHUB_SYNC_DEFAULT_REPO="myorg/work-project"
github-sync "$@"

# ~/bin/sync-personal
#!/bin/bash
export GITHUB_SYNC_DEFAULT_REPO="myusername/personal-project"
github-sync "$@"
```

### Environment Variable Overrides

Configuration can be overridden with environment variables:

```bash
# Override default repo for one command
GITHUB_SYNC_DEFAULT_REPO="other/repo" i push

# Override debug mode
GITHUB_SYNC_DEBUG="true" i sync 1

# Override rate limit delay
GITHUB_SYNC_RATE_LIMIT_DELAY="5" i push
```

### Profile-Specific Configuration

Each profile has its own configuration:

```bash
# Profile 1: Work
p-work
vim $WORKWARRIOR_BASE/.config/github-sync/config.sh
# Set GITHUB_SYNC_DEFAULT_REPO="myorg/work-project"

# Profile 2: Personal
p-personal
vim $WORKWARRIOR_BASE/.config/github-sync/config.sh
# Set GITHUB_SYNC_DEFAULT_REPO="myusername/personal-project"
```

## Configuration Validation

The system validates configuration on load. Invalid values will trigger warnings:

```bash
# Invalid log level
GITHUB_SYNC_LOG_LEVEL="INVALID"
# Warning: Invalid log level 'INVALID', using 'INFO'

# Invalid conflict strategy
GITHUB_SYNC_CONFLICT_STRATEGY="invalid"
# Warning: Invalid conflict strategy 'invalid', using 'last_write_wins'
```

## Reloading Configuration

Configuration is loaded when the sync command starts. To reload:

```bash
# Edit configuration
vim $WORKWARRIOR_BASE/.config/github-sync/config.sh

# Run any sync command (configuration is reloaded)
i sync 1
```

## Configuration Best Practices

### 1. Start with Defaults

Don't change configuration until you understand the defaults:

```bash
# Use defaults for first few syncs
# Then adjust based on your needs
```

### 2. Document Your Changes

Add comments to explain why you changed settings:

```bash
# Exclude 'draft' tag because we use it for work-in-progress tasks
# that shouldn't be visible on GitHub yet
GITHUB_SYNC_EXCLUDE_TAGS="draft"
```

### 3. Test Configuration Changes

After changing configuration, test with a single task:

```bash
# Edit config
vim $WORKWARRIOR_BASE/.config/github-sync/config.sh

# Test with one task
i sync 1

# Check logs
tail -20 $WORKWARRIOR_BASE/.task/github-sync/sync.log
```

### 4. Backup Configuration

Before major changes, backup your configuration:

```bash
cp $WORKWARRIOR_BASE/.config/github-sync/config.sh \
   $WORKWARRIOR_BASE/.config/github-sync/config.sh.backup
```

### 5. Use Version Control

Consider tracking your configuration in git:

```bash
cd $WORKWARRIOR_BASE/.config/github-sync/
git init
git add config.sh
git commit -m "Initial configuration"
```

## Troubleshooting Configuration

### Configuration Not Loading

```bash
# Check file exists
ls -la $WORKWARRIOR_BASE/.config/github-sync/config.sh

# Check file is readable
cat $WORKWARRIOR_BASE/.config/github-sync/config.sh

# Check for syntax errors
bash -n $WORKWARRIOR_BASE/.config/github-sync/config.sh
```

### Configuration Not Taking Effect

```bash
# Verify configuration is loaded
GITHUB_SYNC_DEBUG="true" i sync 1
# Check logs for "Loading configuration from..."

# Check environment variables aren't overriding
env | grep GITHUB_SYNC
```

### Reset to Defaults

```bash
# Delete configuration file
rm $WORKWARRIOR_BASE/.config/github-sync/config.sh

# Run sync (will recreate from template)
i sync 1

# Or manually copy template
cp resources/config-files/github-sync-config.sh \
   $WORKWARRIOR_BASE/.config/github-sync/config.sh
```

## See Also

- [User Guide](github-sync-user-guide.md) - General usage
- [Troubleshooting Guide](github-sync-troubleshooting.md) - Common issues
- [Architecture Documentation](github-sync-architecture.md) - Technical details
