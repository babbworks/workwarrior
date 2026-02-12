# GitHub Two-Way Sync - User Guide

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Command Reference](#command-reference)
4. [Configuration](#configuration)
5. [Workflows](#workflows)
6. [Troubleshooting](#troubleshooting)
7. [FAQ](#faq)

## Introduction

GitHub Two-Way Sync enables bidirectional synchronization between TaskWarrior tasks and GitHub issues. Changes made in either system are automatically reflected in the other, with intelligent conflict resolution.

### Key Features

- **Bidirectional Sync**: Changes sync in both directions (TaskWarrior ↔ GitHub)
- **Field Mapping**: 5 bidirectional fields + 7 pull-only metadata fields
- **Conflict Resolution**: Automatic last-write-wins strategy
- **Annotation/Comment Sync**: Bidirectional with prefixes to prevent loops
- **Error Handling**: Interactive correction for validation errors
- **Batch Operations**: Sync multiple tasks at once
- **Profile Isolation**: Each profile has independent sync state

### What Gets Synced

**Bidirectional (both directions)**:
- Description ↔ Title
- Status ↔ State (pending/started/waiting → OPEN, completed/deleted → CLOSED)
- Priority ↔ Labels (H/M/L → priority:high/medium/low)
- Tags ↔ Labels (system tags excluded)
- Annotations ↔ Comments (with prefixes)

**Pull-Only (GitHub → TaskWarrior)**:
- Issue number → githubissue UDA
- Issue URL → githuburl UDA
- Repository → githubrepo UDA
- Author → githubauthor UDA
- Created date → entry
- Closed date → end
- Updated date → modified

## Getting Started

### Prerequisites

1. **GitHub CLI (`gh`) installed and authenticated**
   ```bash
   # Install (macOS)
   brew install gh
   
   # Authenticate
   gh auth login
   
   # Verify
   gh auth status
   ```

2. **Active Workwarrior Profile**
   ```bash
   source bin/ww
   ww profile use my-profile
   ```

3. **GitHub Repository Access**
   - You need write access to the repository
   - Repository can be public or private

### Quick Start

1. **Create a task in TaskWarrior**
   ```bash
   task add "Implement user authentication" priority:H +feature
   ```

2. **Create an issue on GitHub**
   ```bash
   gh issue create --repo myorg/myproject \
     --title "Implement user authentication" \
     --body "Add OAuth2 authentication"
   ```

3. **Enable sync** (links task to issue)
   ```bash
   # Get task ID
   task list
   
   # Get issue number from GitHub or gh CLI
   gh issue list --repo myorg/myproject
   
   # Enable sync
   github-sync enable 1 42 myorg/myproject
   # Or use shell shortcut:
   i enable-sync 1 42 myorg/myproject
   ```

4. **Make changes and sync**
   ```bash
   # Modify task
   task 1 modify priority:M
   task 1 annotate "Started implementation"
   
   # Push changes to GitHub
   i push 1
   
   # Or sync bidirectionally
   i sync 1
   ```

## Command Reference

### Enable Sync

Link a TaskWarrior task to a GitHub issue.

```bash
github-sync enable <task-id> <issue-number> <repo>
i enable-sync <task-id> <issue-number> <repo>
```

**Example**:
```bash
github-sync enable 42 123 myorg/myproject
```

**What it does**:
- Links task to GitHub issue
- Sets githubsync UDA to "enabled"
- Populates GitHub metadata UDAs
- Performs initial pull from GitHub

### Disable Sync

Unlink a task from GitHub (preserves metadata).

```bash
github-sync disable <task-id>
i disable-sync <task-id>
```

**Example**:
```bash
github-sync disable 42
```

**What it does**:
- Sets githubsync UDA to "disabled"
- Removes sync state
- Preserves GitHub metadata UDAs

### Push

Push task changes to GitHub.

```bash
github-sync push [task-id] [--dry-run]
i push [task-id]
```

**Examples**:
```bash
# Push specific task
i push 42

# Push all synced tasks
i push

# Preview changes (when implemented)
i push --dry-run
```

**What it syncs**:
- Task description → Issue title
- Task status → Issue state
- Task priority → Priority labels
- Task tags → Issue labels
- Task annotations → Issue comments

### Pull

Pull issue changes from GitHub.

```bash
github-sync pull [task-id] [--dry-run]
i pull [task-id]
```

**Examples**:
```bash
# Pull specific task
i pull 42

# Pull all synced tasks
i pull
```

**What it syncs**:
- Issue title → Task description
- Issue state → Task status
- Priority labels → Task priority
- Issue labels → Task tags
- Issue comments → Task annotations
- Issue metadata → Task UDAs

### Sync

Bidirectional sync (detects changes on both sides).

```bash
github-sync sync [task-id] [--dry-run]
i sync [task-id]
```

**Examples**:
```bash
# Sync specific task
i sync 42

# Sync all synced tasks
i sync
```

**What it does**:
- Detects changes on both sides
- Resolves conflicts using last-write-wins
- Pushes or pulls as needed
- Syncs annotations/comments bidirectionally

### Status

Display sync status for all synced tasks.

```bash
github-sync status
i sync-status
```

**Output**:
```
Task: abc123de
  Description: Implement user authentication
  GitHub: myorg/myproject#42
  Last sync: 2024-01-15T10:30:00Z

Total synced tasks: 5
```

### Help

Display help information.

```bash
github-sync help [command]
```

**Examples**:
```bash
# General help
github-sync help

# Command-specific help
github-sync help push
github-sync help enable
```

## Configuration

Configuration is stored per-profile at:
```
$WORKWARRIOR_BASE/.config/github-sync/config.sh
```

### Configuration Options

```bash
# Default repository (optional)
GITHUB_SYNC_DEFAULT_REPO="myorg/myproject"

# Conflict resolution strategy
GITHUB_SYNC_CONFLICT_STRATEGY="last_write_wins"

# Auto-sync on task modification (future feature)
GITHUB_SYNC_AUTO_SYNC="false"

# Fields to sync
GITHUB_SYNC_FIELDS="description,status,priority,tags,annotations"

# Tags to exclude from sync
GITHUB_SYNC_EXCLUDE_TAGS="private,local"

# Labels to exclude from sync
GITHUB_SYNC_EXCLUDE_LABELS="wontfix,duplicate"

# Annotation/comment prefixes
GITHUB_SYNC_TW_PREFIX="[TaskWarrior]"
GITHUB_SYNC_GH_PREFIX="[GitHub"

# Logging
GITHUB_SYNC_LOG_LEVEL="INFO"
GITHUB_SYNC_LOG_MAX_SIZE="10485760"  # 10MB
GITHUB_SYNC_LOG_MAX_AGE="30"  # days

# Rate limiting
GITHUB_SYNC_RATE_LIMIT_DELAY="1"  # seconds between API calls

# Retry settings
GITHUB_SYNC_MAX_RETRIES="3"
GITHUB_SYNC_RETRY_DELAY="5"  # seconds

# Debug mode
GITHUB_SYNC_DEBUG="false"
```

### Editing Configuration

```bash
# Open config file
$EDITOR $WORKWARRIOR_BASE/.config/github-sync/config.sh

# Or use direct path
vim ~/.workwarrior/profiles/my-profile/.config/github-sync/config.sh
```

## Workflows

### Workflow 1: Task-First Development

1. Create task in TaskWarrior
2. Create issue on GitHub
3. Enable sync
4. Work in TaskWarrior, push periodically

```bash
# Create task
task add "Fix login bug" priority:H +bug

# Create issue
ISSUE=$(gh issue create --repo myorg/myproject \
  --title "Fix login bug" --body "Users can't log in" | grep -oP '#\K\d+')

# Enable sync
i enable-sync 1 $ISSUE myorg/myproject

# Work and push
task 1 start
task 1 annotate "Found root cause in auth.js"
i push 1

task 1 done
i push 1
```

### Workflow 2: Issue-First Development

1. Create issue on GitHub
2. Create placeholder task
3. Enable sync (pulls issue data)
4. Work in TaskWarrior

```bash
# Issue already exists on GitHub (#123)

# Create placeholder task
task add "Placeholder" +feature

# Enable sync (will pull issue data)
i enable-sync 1 123 myorg/myproject

# Task now has issue title, labels, etc.
task 1 info
```

### Workflow 3: Batch Sync

Sync multiple tasks at once.

```bash
# Enable sync for multiple tasks
for task_id in 1 2 3 4 5; do
  i enable-sync $task_id $((100 + task_id)) myorg/myproject
done

# Make changes to multiple tasks
task +feature modify priority:H

# Batch push
i push

# Or batch sync
i sync
```

### Workflow 4: Conflict Resolution

When both sides change, last-write-wins resolves conflicts.

```bash
# Modify task
task 1 modify "Updated locally"

# Someone modifies issue on GitHub
# (without syncing)

# Sync (will detect conflict and resolve)
i sync 1

# Check logs to see resolution
cat $WORKWARRIOR_BASE/.task/github-sync/errors.log | \
  jq 'select(.type=="conflict_resolution")'
```

## Troubleshooting

### Common Issues

#### "gh: command not found"

**Problem**: GitHub CLI not installed.

**Solution**:
```bash
# macOS
brew install gh

# Linux
# See https://cli.github.com/
```

#### "gh: authentication required"

**Problem**: GitHub CLI not authenticated.

**Solution**:
```bash
gh auth login
# Follow prompts to authenticate
```

#### "Permission denied"

**Problem**: No write access to repository.

**Solution**:
1. Verify repository access:
   ```bash
   gh repo view myorg/myproject
   ```
2. Check token scopes:
   ```bash
   gh auth status
   ```
3. Refresh token with correct scopes:
   ```bash
   gh auth refresh -s repo
   ```

#### "Task not found"

**Problem**: Invalid task ID or UUID.

**Solution**:
```bash
# List tasks
task list

# Use correct ID or UUID
i push 42
# or
i push abc123de-f456-7890-abcd-ef1234567890
```

#### "No profile active"

**Problem**: WORKWARRIOR_BASE not set.

**Solution**:
```bash
source bin/ww
ww profile use my-profile
```

#### Title truncated

**Problem**: Task description >256 characters.

**Solution**: This is expected. GitHub issue titles have a 256-character limit. The sync system automatically truncates with "..." at the end.

```bash
# Check truncated title
gh issue view 123 --repo myorg/myproject
```

#### Sync state corruption

**Problem**: Sync state database corrupted.

**Solution**:
```bash
# Reset sync state
rm $WORKWARRIOR_BASE/.task/github-sync/state.json

# Re-enable sync for affected tasks
i enable-sync 1 123 myorg/myproject
```

### Viewing Logs

**Sync log** (operation history):
```bash
cat $WORKWARRIOR_BASE/.task/github-sync/sync.log
```

**Error log** (errors and conflicts):
```bash
cat $WORKWARRIOR_BASE/.task/github-sync/errors.log | jq '.'
```

**Recent operations**:
```bash
tail -20 $WORKWARRIOR_BASE/.task/github-sync/sync.log
```

**Recent errors**:
```bash
tail -10 $WORKWARRIOR_BASE/.task/github-sync/errors.log | jq '.'
```

## FAQ

### Q: Can I sync one task to multiple issues?

**A**: No, each task can only be synced to one issue. This is a one-to-one relationship.

### Q: What happens if I delete a task?

**A**: The task status changes to "deleted", which maps to GitHub state "CLOSED". The issue is closed but not deleted.

### Q: What happens if I close an issue?

**A**: The issue state "CLOSED" maps to task status "completed". The task is marked as done.

### Q: Can I sync to private repositories?

**A**: Yes, as long as your GitHub token has access to the repository.

### Q: Do I need bugwarrior?

**A**: No, GitHub two-way sync works independently. However, it coexists with bugwarrior if you have it installed.

### Q: How do I stop syncing a task?

**A**: Use `i disable-sync <task-id>`. This preserves GitHub metadata but stops syncing.

### Q: Can I sync tasks from different profiles to the same repository?

**A**: Yes, each profile has independent sync state. However, be careful about conflicts if multiple profiles sync to the same issues.

### Q: What are system tags?

**A**: System tags are TaskWarrior's internal tags like ACTIVE, READY, PENDING, COMPLETED, etc. These are automatically excluded from sync.

### Q: How do I know which tasks are synced?

**A**: Use `i sync-status` to see all synced tasks and their GitHub issues.

### Q: Can I customize the annotation/comment prefixes?

**A**: Yes, edit the configuration file:
```bash
GITHUB_SYNC_TW_PREFIX="[TW]"
GITHUB_SYNC_GH_PREFIX="[GH"
```

### Q: How does conflict resolution work?

**A**: When both sides change, the system compares timestamps. The most recently modified side wins. If timestamps are equal, GitHub wins (tiebreaker).

### Q: Can I undo a sync?

**A**: No, sync operations are not reversible. However, you can manually revert changes in TaskWarrior or GitHub.

### Q: How do I sync to a different repository?

**A**: Disable sync, then re-enable with the new repository:
```bash
i disable-sync 1
i enable-sync 1 456 neworg/newrepo
```

### Q: What if GitHub API rate limit is exceeded?

**A**: The system will detect rate limit errors and offer to wait. GitHub allows 5000 requests/hour for authenticated users.

## Next Steps

- Read the [Configuration Guide](github-sync-configuration-guide.md) for advanced configuration
- See [Integration Testing Guide](../tests/integration-test-guide.md) for testing
- Check [Troubleshooting Guide](github-sync-troubleshooting.md) for common issues
- Review [Architecture Documentation](github-sync-architecture.md) for developers
