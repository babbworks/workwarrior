# GitHub Two-Way Sync - Troubleshooting Guide

## Quick Diagnostics

Run these commands to diagnose common issues:

```bash
# Check GitHub CLI
gh auth status

# Check profile
echo $WORKWARRIOR_BASE

# Check sync state
ls -la $WORKWARRIOR_BASE/.task/github-sync/

# Check recent errors
tail -20 $WORKWARRIOR_BASE/.task/github-sync/errors.log | jq '.'

# Check synced tasks
i sync-status
```

## Common Problems

### Installation & Setup Issues

#### Problem: `gh: command not found`

**Symptoms**:
```
Error: gh CLI not found
```

**Solution**:
```bash
# macOS
brew install gh

# Linux (Debian/Ubuntu)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh

# Or see: https://cli.github.com/
```

#### Problem: `gh: authentication required`

**Symptoms**:
```
Error: gh CLI not authenticated
```

**Solution**:
```bash
# Authenticate
gh auth login

# Follow prompts:
# 1. Choose GitHub.com
# 2. Choose HTTPS
# 3. Authenticate with browser or token
# 4. Choose scopes (ensure 'repo' is included)

# Verify
gh auth status
```

#### Problem: `No profile active`

**Symptoms**:
```
Error: No profile active. Please activate a profile first.
```

**Solution**:
```bash
# Source Workwarrior
source bin/ww

# List profiles
ww profile list

# Use profile
ww profile use my-profile

# Or create new profile
ww profile create test-profile
ww profile use test-profile

# Verify
echo $WORKWARRIOR_BASE
```

### Permission & Access Issues

#### Problem: `Permission denied` when pushing

**Symptoms**:
```
Error: Failed to update issue #123
Permission denied
```

**Causes**:
- No write access to repository
- GitHub token lacks required scopes
- Repository is archived or read-only

**Solution**:
```bash
# 1. Check repository access
gh repo view myorg/myrepo

# 2. Check token scopes
gh auth status

# 3. Refresh token with correct scopes
gh auth refresh -s repo

# 4. Verify you have write access
gh issue create --repo myorg/myrepo --title "Test" --body "Test"
gh issue close 1 --repo myorg/myrepo
gh issue delete 1 --repo myorg/myrepo --yes

# 5. If still failing, check repository settings on GitHub
# - Is it archived?
# - Do you have write access?
# - Are issues enabled?
```

#### Problem: `Rate limit exceeded`

**Symptoms**:
```
Error: GitHub API rate limit exceeded
```

**Solution**:
```bash
# Check rate limit status
gh api rate_limit

# Wait for reset (shown in output)
# Or use authenticated requests (5000/hour vs 60/hour)

# The sync system will offer to wait automatically
```

### Sync Issues

#### Problem: Task not syncing

**Symptoms**:
- Changes in TaskWarrior don't appear on GitHub
- Or vice versa

**Diagnosis**:
```bash
# 1. Check if task is synced
i sync-status

# 2. Check sync state
cat $WORKWARRIOR_BASE/.task/github-sync/state.json | jq '.'

# 3. Check recent errors
tail -20 $WORKWARRIOR_BASE/.task/github-sync/errors.log | jq '.'

# 4. Check task UDAs
task <task-id> export | jq '.[0] | {githubsync, githubissue, githubrepo}'
```

**Solutions**:

**If task not in sync state**:
```bash
# Re-enable sync
i enable-sync <task-id> <issue-number> <repo>
```

**If githubsync UDA is "disabled"**:
```bash
# Re-enable
i enable-sync <task-id> <issue-number> <repo>
```

**If sync state corrupted**:
```bash
# Reset sync state
rm $WORKWARRIOR_BASE/.task/github-sync/state.json

# Re-enable all tasks
# (You'll need to know which tasks were synced)
i enable-sync <task-id> <issue-number> <repo>
```

#### Problem: Conflicts not resolving

**Symptoms**:
- Sync command runs but changes don't appear
- Conflict messages in logs

**Diagnosis**:
```bash
# Check conflict log
cat $WORKWARRIOR_BASE/.task/github-sync/errors.log | \
  jq 'select(.type=="conflict_resolution")'
```

**Solution**:
```bash
# Conflicts are resolved automatically using last-write-wins
# The most recently modified side wins

# To force a specific direction:
# Force push (TaskWarrior → GitHub)
i push <task-id>

# Force pull (GitHub → TaskWarrior)
i pull <task-id>

# Check timestamps
task <task-id> export | jq '.[0].modified'
gh issue view <issue-number> --repo <repo> --json updatedAt
```

#### Problem: Annotations/comments duplicating

**Symptoms**:
- Same annotation appears multiple times
- Comments sync back and forth

**Cause**: Prefix detection not working

**Diagnosis**:
```bash
# Check annotations
task <task-id> export | jq '.[0].annotations'

# Check comments
gh issue view <issue-number> --repo <repo> --json comments
```

**Solution**:
```bash
# This should not happen - the system uses prefixes to prevent loops
# If it does happen:

# 1. Check configuration
cat $WORKWARRIOR_BASE/.config/github-sync/config.sh | grep PREFIX

# 2. Manually remove duplicates
task <task-id> edit
# Remove duplicate annotations

# 3. Report bug with logs
```

### Data Issues

#### Problem: Title truncated

**Symptoms**:
```
Warning: Title truncated from 300 to 256 characters
```

**Cause**: GitHub issue titles have a 256-character limit

**Solution**:
```bash
# This is expected behavior
# Shorten task description if needed
task <task-id> modify "Shorter description"
i push <task-id>

# Or accept truncation (title will end with "...")
```

#### Problem: Tags not syncing

**Symptoms**:
- Task tags don't appear as GitHub labels
- Or vice versa

**Diagnosis**:
```bash
# Check task tags
task <task-id> export | jq '.[0].tags'

# Check issue labels
gh issue view <issue-number> --repo <repo> --json labels

# Check excluded tags
cat $WORKWARRIOR_BASE/.config/github-sync/config.sh | grep EXCLUDE_TAGS
```

**Solutions**:

**If tags are system tags**:
```bash
# System tags (ACTIVE, READY, etc.) are automatically excluded
# This is expected behavior
```

**If tags have invalid characters**:
```bash
# Tags are sanitized for GitHub labels
# Spaces → hyphens
# Special characters removed
# Max 50 characters

# Example: "my tag!" → "my-tag"
```

**If tags in exclusion list**:
```bash
# Edit configuration
vim $WORKWARRIOR_BASE/.config/github-sync/config.sh

# Remove from GITHUB_SYNC_EXCLUDE_TAGS
```

#### Problem: Priority not syncing

**Symptoms**:
- Task priority doesn't create GitHub label
- Or GitHub priority label doesn't set task priority

**Diagnosis**:
```bash
# Check task priority
task <task-id> export | jq '.[0].priority'

# Check issue labels
gh issue view <issue-number> --repo <repo> --json labels | \
  jq '.labels[] | select(.name | test("priority"))'
```

**Solution**:
```bash
# Priority mapping:
# H → priority:high
# M → priority:medium
# L → priority:low
# (empty) → no label

# If not working:
# 1. Check labels exist on GitHub
gh label list --repo <repo> | grep priority

# 2. Create labels if missing
gh label create "priority:high" --repo <repo> --color "d73a4a"
gh label create "priority:medium" --repo <repo> --color "fbca04"
gh label create "priority:low" --repo <repo> --color "0e8a16"

# 3. Re-sync
i sync <task-id>
```

### Performance Issues

#### Problem: Sync is slow

**Symptoms**:
- Batch sync takes >5 minutes for 10 tasks
- Single task sync takes >10 seconds

**Diagnosis**:
```bash
# Time a sync operation
time i sync <task-id>

# Check API calls in logs
grep "API call" $WORKWARRIOR_BASE/.task/github-sync/sync.log | tail -20
```

**Solutions**:

**If network is slow**:
```bash
# Check network
ping github.com

# Check GitHub status
curl https://www.githubstatus.com/api/v2/status.json
```

**If too many API calls**:
```bash
# This might indicate a bug
# Check logs for repeated calls
grep "github_get_issue" $WORKWARRIOR_BASE/.task/github-sync/sync.log | \
  sort | uniq -c | sort -rn
```

**If rate limited**:
```bash
# Check rate limit
gh api rate_limit

# Wait for reset or reduce sync frequency
```

### Log Issues

#### Problem: Logs growing too large

**Symptoms**:
```bash
ls -lh $WORKWARRIOR_BASE/.task/github-sync/
# sync.log is >100MB
```

**Solution**:
```bash
# Logs should auto-rotate at 10MB
# If not:

# 1. Check configuration
cat $WORKWARRIOR_BASE/.config/github-sync/config.sh | grep LOG_MAX_SIZE

# 2. Manually rotate
mv $WORKWARRIOR_BASE/.task/github-sync/sync.log \
   $WORKWARRIOR_BASE/.task/github-sync/sync.log.old
touch $WORKWARRIOR_BASE/.task/github-sync/sync.log

# 3. Clean old logs
find $WORKWARRIOR_BASE/.task/github-sync/ -name "*.log.*" -mtime +30 -delete
```

#### Problem: Can't find logs

**Symptoms**:
```bash
cat $WORKWARRIOR_BASE/.task/github-sync/sync.log
# No such file or directory
```

**Solution**:
```bash
# Logs are created on first sync
# If missing:

# 1. Check profile
echo $WORKWARRIOR_BASE

# 2. Check directory exists
ls -la $WORKWARRIOR_BASE/.task/github-sync/

# 3. Create directory if missing
mkdir -p $WORKWARRIOR_BASE/.task/github-sync/

# 4. Run a sync to create logs
i sync <task-id>
```

## Advanced Troubleshooting

### Debug Mode

Enable debug mode for verbose logging:

```bash
# Edit configuration
vim $WORKWARRIOR_BASE/.config/github-sync/config.sh

# Set debug mode
GITHUB_SYNC_DEBUG="true"

# Run sync
i sync <task-id>

# Check detailed logs
tail -50 $WORKWARRIOR_BASE/.task/github-sync/sync.log
```

### Manual State Inspection

```bash
# View entire sync state
cat $WORKWARRIOR_BASE/.task/github-sync/state.json | jq '.'

# View specific task state
cat $WORKWARRIOR_BASE/.task/github-sync/state.json | \
  jq '.["<task-uuid>"]'

# View all synced tasks
cat $WORKWARRIOR_BASE/.task/github-sync/state.json | jq 'keys'
```

### Manual State Repair

```bash
# Backup state
cp $WORKWARRIOR_BASE/.task/github-sync/state.json \
   $WORKWARRIOR_BASE/.task/github-sync/state.json.backup

# Edit state manually
vim $WORKWARRIOR_BASE/.task/github-sync/state.json

# Or reset completely
rm $WORKWARRIOR_BASE/.task/github-sync/state.json

# Re-enable sync for all tasks
# (You'll need to know which tasks were synced)
```

### Testing with Dry-Run

```bash
# Preview changes without syncing (when implemented)
i push --dry-run
i pull --dry-run
i sync --dry-run
```

## Getting Help

### Collect Diagnostic Information

```bash
# Create diagnostic report
cat > /tmp/github-sync-diagnostic.txt <<EOF
=== System Information ===
OS: $(uname -a)
Shell: $SHELL
Profile: $WORKWARRIOR_BASE

=== GitHub CLI ===
$(gh --version)
$(gh auth status 2>&1)

=== TaskWarrior ===
$(task --version)

=== Sync Status ===
$(i sync-status 2>&1)

=== Recent Errors ===
$(tail -20 $WORKWARRIOR_BASE/.task/github-sync/errors.log 2>&1)

=== Recent Operations ===
$(tail -20 $WORKWARRIOR_BASE/.task/github-sync/sync.log 2>&1)

=== Configuration ===
$(cat $WORKWARRIOR_BASE/.config/github-sync/config.sh 2>&1)
EOF

cat /tmp/github-sync-diagnostic.txt
```

### Report Issues

When reporting issues, include:
1. Diagnostic report (above)
2. Steps to reproduce
3. Expected vs actual behavior
4. Relevant log excerpts

## See Also

- [User Guide](github-sync-user-guide.md) - General usage
- [Configuration Guide](github-sync-configuration-guide.md) - Configuration options
- [Integration Testing](../tests/integration-test-guide.md) - Testing procedures
