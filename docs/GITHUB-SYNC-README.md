# GitHub Two-Way Sync for Workwarrior

Bidirectional synchronization between TaskWarrior tasks and GitHub issues.

## Features

✅ **Bidirectional Sync** - Changes sync in both directions (TaskWarrior ↔ GitHub)  
✅ **Smart Conflict Resolution** - Automatic last-write-wins strategy  
✅ **Annotation/Comment Sync** - Bidirectional with loop prevention  
✅ **Error Handling** - Interactive correction for validation errors  
✅ **Batch Operations** - Sync multiple tasks at once  
✅ **Profile Isolation** - Each profile has independent sync state  
✅ **Bugwarrior Compatible** - Works alongside existing bugwarrior setup  

## Quick Start

```bash
# 1. Authenticate with GitHub
gh auth login

# 2. Activate a profile
source bin/ww
ww profile use my-profile

# 3. Enable sync for a task
i enable-sync 1 42 myorg/myrepo
#              │  │  └─ GitHub repository
#              │  └──── GitHub issue number
#              └─────── TaskWarrior task ID

# 4. Make changes and sync
task 1 modify priority:H
i push 1

# Or sync bidirectionally
i sync 1
```

## What Gets Synced

### Bidirectional (Both Directions)

| TaskWarrior | GitHub | Notes |
|-------------|--------|-------|
| Description | Title | Auto-truncated to 256 chars |
| Status | State | pending/started/waiting → OPEN<br>completed/deleted → CLOSED |
| Priority | Labels | H → priority:high<br>M → priority:medium<br>L → priority:low |
| Tags | Labels | System tags excluded |
| Annotations | Comments | Prefixed to prevent loops |

### Pull-Only (GitHub → TaskWarrior)

| GitHub Field | TaskWarrior UDA | Notes |
|--------------|-----------------|-------|
| Issue number | githubissue | |
| Issue URL | githuburl | |
| Repository | githubrepo | |
| Author | githubauthor | |
| Created date | entry | On first sync |
| Closed date | end | When issue closed |
| Updated date | modified | |

## Commands

### Enable/Disable Sync

```bash
# Enable sync (links task to issue)
i enable-sync <task-id> <issue-number> <repo>

# Disable sync (preserves metadata)
i disable-sync <task-id>
```

### Sync Operations

```bash
# Push: TaskWarrior → GitHub
i push [task-id]

# Pull: GitHub → TaskWarrior
i pull [task-id]

# Sync: Bidirectional (auto-resolves conflicts)
i sync [task-id]

# Status: View sync status
i sync-status
```

### Examples

```bash
# Sync specific task
i sync 42

# Sync all synced tasks
i sync

# Push all tasks
i push

# Pull all tasks
i pull
```

## Installation

### Prerequisites

1. **GitHub CLI**
   ```bash
   brew install gh  # macOS
   gh auth login
   ```

2. **jq** (JSON processor)
   ```bash
   brew install jq  # macOS
   ```

3. **TaskWarrior 2.6.0+**
   ```bash
   brew install task  # macOS
   ```

### Setup

The GitHub sync feature is included in Workwarrior. No additional installation needed.

## Configuration

Configuration is stored per-profile at:
```
$WORKWARRIOR_BASE/.config/github-sync/config.sh
```

### Common Configuration Options

```bash
# Default repository (optional)
GITHUB_SYNC_DEFAULT_REPO="myorg/myproject"

# Tags to exclude from sync
GITHUB_SYNC_EXCLUDE_TAGS="private,local"

# Labels to exclude from sync
GITHUB_SYNC_EXCLUDE_LABELS="wontfix,duplicate"

# Debug mode
GITHUB_SYNC_DEBUG="false"
```

See [Configuration Guide](github-sync-configuration-guide.md) for all options.

## Workflows

### Workflow 1: Task-First

```bash
# 1. Create task
task add "Fix login bug" priority:H +bug

# 2. Create issue
ISSUE=$(gh issue create --repo myorg/myproject \
  --title "Fix login bug" | grep -oP '#\K\d+')

# 3. Enable sync
i enable-sync 1 $ISSUE myorg/myproject

# 4. Work and sync
task 1 start
task 1 annotate "Found root cause"
i push 1

task 1 done
i push 1
```

### Workflow 2: Issue-First

```bash
# 1. Issue already exists (#123)

# 2. Create placeholder task
task add "Placeholder"

# 3. Enable sync (pulls issue data)
i enable-sync 1 123 myorg/myproject

# 4. Task now has issue title, labels, etc.
task 1 info
```

### Workflow 3: Batch Sync

```bash
# Enable sync for multiple tasks
for i in {1..5}; do
  i enable-sync $i $((100 + i)) myorg/myproject
done

# Make changes
task +feature modify priority:H

# Batch sync
i sync
```

## Conflict Resolution

When both sides change, the system uses **last-write-wins**:

1. Compares modification timestamps
2. Most recent change wins
3. If equal, GitHub wins (tiebreaker)
4. Conflict is logged

```bash
# View conflict log
cat $WORKWARRIOR_BASE/.task/github-sync/errors.log | \
  jq 'select(.type=="conflict_resolution")'
```

## Troubleshooting

### Common Issues

**"gh: command not found"**
```bash
brew install gh
```

**"gh: authentication required"**
```bash
gh auth login
```

**"Permission denied"**
```bash
gh auth refresh -s repo
```

**"Task not syncing"**
```bash
# Check sync status
i sync-status

# Check logs
tail -20 $WORKWARRIOR_BASE/.task/github-sync/sync.log
```

See [Troubleshooting Guide](github-sync-troubleshooting.md) for more.

## Documentation

- **[User Guide](github-sync-user-guide.md)** - Complete usage guide
- **[Configuration Guide](github-sync-configuration-guide.md)** - Configuration options
- **[Troubleshooting Guide](github-sync-troubleshooting.md)** - Common issues and solutions
- **[Integration Testing](../tests/integration-test-guide.md)** - Testing procedures
- **[Architecture](github-sync-architecture.md)** - Technical details

## Logs

Logs are stored per-profile:

```bash
# Sync operations log
$WORKWARRIOR_BASE/.task/github-sync/sync.log

# Error log (JSON format)
$WORKWARRIOR_BASE/.task/github-sync/errors.log

# View recent operations
tail -20 $WORKWARRIOR_BASE/.task/github-sync/sync.log

# View recent errors
tail -10 $WORKWARRIOR_BASE/.task/github-sync/errors.log | jq '.'
```

## Limitations

- One task can only sync to one issue (one-to-one relationship)
- Title truncated to 256 characters (GitHub limit)
- System tags (ACTIVE, READY, etc.) are not synced
- Dry-run mode not fully implemented (shows warning)

## FAQ

**Q: Can I sync to private repositories?**  
A: Yes, as long as your GitHub token has access.

**Q: Do I need bugwarrior?**  
A: No, GitHub two-way sync works independently.

**Q: What happens if I delete a task?**  
A: The issue is closed (not deleted).

**Q: Can I undo a sync?**  
A: No, but you can manually revert changes.

**Q: How do I stop syncing a task?**  
A: Use `i disable-sync <task-id>`

See [User Guide FAQ](github-sync-user-guide.md#faq) for more questions.

## Performance

- Single task sync: <5 seconds
- Batch sync (10 tasks): <60 seconds
- API rate limit: 5000 requests/hour (authenticated)

## Requirements

- bash 4.0+
- jq
- gh CLI (authenticated)
- TaskWarrior 2.6.0+
- GitHub repository with write access

## Testing

```bash
# Set test repository
export GITHUB_TEST_REPO="username/test-repo"

# Run automated tests
./tests/run-integration-tests.sh

# Or follow manual testing guide
cat tests/integration-test-guide.md
```

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[License information]

## Support

- **Issues**: Report bugs and request features
- **Documentation**: See docs/ directory
- **Testing**: See tests/ directory

## Version

Current version: 1.0.0

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

---

**Made with ❤️ for Workwarrior users**
