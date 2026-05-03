# Manual Testing Guide - GitHub Two-Way Sync Foundation

This guide walks you through manually testing the foundation components with a real GitHub repository.

## Prerequisites

Before you begin:

1. ✅ Active Workwarrior profile
2. ✅ GitHub CLI (`gh`) installed and authenticated
3. ✅ A GitHub repository where you have write access (for testing)
4. ✅ GitHub sync UDAs added to your .taskrc (the test script does this automatically)

## Setup

### 1. Choose a Test Repository

Pick a GitHub repository where you can safely create/modify test issues. Options:
- Create a new test repository: `gh repo create test-workwarrior-sync --public`
- Use an existing repository you own

For this guide, we'll use the format: `owner/repo`

### 2. Verify Your Environment

```bash
# Check profile is active
echo $WORKWARRIOR_BASE

# Check gh CLI is authenticated
gh auth status

# Source the API wrappers
source lib/github-api.sh
source lib/github-sync-state.sh
source lib/taskwarrior-api.sh
```

## Test 1: GitHub API Wrapper

### Test 1.1: Check gh CLI Availability

```bash
check_gh_cli
# Expected: Returns 0 (success)
```

### Test 1.2: Create a Test Issue (via gh CLI directly)

```bash
# Create a test issue
gh issue create --repo owner/repo --title "Test sync issue" --body "Testing Workwarrior sync"
# Note the issue number (e.g., #123)
```

### Test 1.3: Fetch Issue Details

```bash
# Replace 123 with your issue number
github_get_issue "owner/repo" 123

# Expected: JSON output with issue details
# Should include: number, title, state, labels, comments, etc.
```

### Test 1.4: Update Issue Title

```bash
# Update the issue title
github_update_issue "owner/repo" 123 "Updated test sync issue" ""

# Verify on GitHub or fetch again
github_get_issue "owner/repo" 123 | jq '.title'
# Expected: "Updated test sync issue"
```

### Test 1.5: Update Issue State

```bash
# Close the issue
github_update_issue "owner/repo" 123 "" "CLOSED"

# Verify
github_get_issue "owner/repo" 123 | jq '.state'
# Expected: "CLOSED"

# Reopen it
github_update_issue "owner/repo" 123 "" "OPEN"
```

### Test 1.6: Add Labels

```bash
# Ensure labels exist (creates if needed)
github_ensure_label "owner/repo" "bug"
github_ensure_label "owner/repo" "priority:high"

# Add labels to issue
github_update_labels "owner/repo" 123 "bug,priority:high" ""

# Verify
github_get_issue "owner/repo" 123 | jq '.labels[].name'
# Expected: ["bug", "priority:high"]
```

### Test 1.7: Remove Labels

```bash
# Remove a label
github_update_labels "owner/repo" 123 "" "bug"

# Verify
github_get_issue "owner/repo" 123 | jq '.labels[].name'
# Expected: ["priority:high"]
```

### Test 1.8: Add Comment

```bash
# Add a comment
comment_id=$(github_add_comment "owner/repo" 123 "Test comment from Workwarrior sync")

echo "Comment ID: $comment_id"

# Verify on GitHub or fetch issue
github_get_issue "owner/repo" 123 | jq '.comments[].body'
```

## Test 2: TaskWarrior API Wrapper

### Test 2.1: Create a Test Task

```bash
# Create a task
task add "Test GitHub sync task" priority:H +test

# Get the task ID (e.g., 1)
# Get the UUID
test_uuid=$(task _get 1.uuid)
echo "Task UUID: $test_uuid"
```

### Test 2.2: Get Task Details

```bash
# Fetch task as JSON
tw_get_task "$test_uuid"

# Expected: JSON output with task details
# Should include: uuid, description, status, priority, tags, etc.
```

### Test 2.3: Check Task Exists

```bash
tw_task_exists "$test_uuid"
echo "Exit code: $?"
# Expected: 0 (success)

tw_task_exists "nonexistent-uuid"
echo "Exit code: $?"
# Expected: 1 (not found)
```

### Test 2.4: Update Task Field

```bash
# Add GitHub issue number
tw_update_task "$test_uuid" "githubissue" "123"

# Verify
tw_get_field "$test_uuid" "githubissue"
# Expected: 123
```

### Test 2.5: Update Multiple Fields

```bash
# Update multiple fields at once
tw_update_task_fields "$test_uuid" "githuburl:https://github.com/owner/repo/issues/123" "githubrepo:owner/repo"

# Verify
task "$test_uuid" export | jq '{githuburl, githubrepo}'
```

### Test 2.6: Add Annotation

```bash
# Add an annotation
tw_add_annotation "$test_uuid" "Test annotation from sync"

# Verify
task "$test_uuid" export | jq '.annotations[].description'
# Expected: "Test annotation from sync"
```

### Test 2.7: Find Task by Issue Number

```bash
# Find task by GitHub issue number
found_uuid=$(tw_get_task_by_issue "123")

echo "Found UUID: $found_uuid"
echo "Original UUID: $test_uuid"

# They should match
[[ "$found_uuid" == "$test_uuid" ]] && echo "✓ Match!" || echo "✗ No match"
```

### Test 2.8: Get Synced Tasks

```bash
# Enable sync for the task
tw_update_task "$test_uuid" "githubsync" "enabled"

# Get all synced tasks
tw_get_synced_tasks
# Expected: Should include $test_uuid
```

## Test 3: State Manager

### Test 3.1: Initialize State Database

```bash
# Initialize (creates ~/.task/github-sync/state.json)
init_state_database

# Verify
ls -la "$WORKWARRIOR_BASE/.task/github-sync/state.json"
# Expected: File exists with 600 permissions
```

### Test 3.2: Save Sync State

```bash
# Get current task and issue data
task_data=$(tw_get_task "$test_uuid")
github_data=$(github_get_issue "owner/repo" 123)

# Save sync state
save_sync_state "$test_uuid" "$task_data" "$github_data"

# Verify
cat "$WORKWARRIOR_BASE/.task/github-sync/state.json" | jq .
# Expected: JSON with your task UUID as key
```

### Test 3.3: Get Sync State

```bash
# Retrieve sync state
state=$(get_sync_state "$test_uuid")

echo "$state" | jq .
# Expected: JSON with last_task_state, last_github_state, etc.
```

### Test 3.4: Check If Task Is Synced

```bash
is_task_synced "$test_uuid"
echo "Exit code: $?"
# Expected: 0 (synced)

is_task_synced "nonexistent-uuid"
echo "Exit code: $?"
# Expected: 1 (not synced)
```

### Test 3.5: Get All Synced Tasks

```bash
# List all synced tasks
get_all_synced_tasks
# Expected: List of UUIDs including $test_uuid
```

### Test 3.6: Remove Sync State

```bash
# Remove sync state
remove_sync_state "$test_uuid"

# Verify it's gone
is_task_synced "$test_uuid"
echo "Exit code: $?"
# Expected: 1 (not synced anymore)
```

## Test 4: End-to-End Workflow Simulation

This simulates what a full sync operation would do:

### Step 1: Create Task and Issue

```bash
# Create a new GitHub issue
gh issue create --repo owner/repo --title "E2E test issue" --body "End-to-end test"
# Note the issue number (e.g., 456)

# Create corresponding task
task add "E2E test issue" priority:M +e2e-test
e2e_uuid=$(task _get $(task +e2e-test ids).uuid)
```

### Step 2: Link Task to Issue

```bash
# Set GitHub metadata on task
tw_update_task_fields "$e2e_uuid" \
  "githubissue:456" \
  "githuburl:https://github.com/owner/repo/issues/456" \
  "githubrepo:owner/repo" \
  "githubsync:enabled"

# Verify
task "$e2e_uuid" export | jq '{githubissue, githuburl, githubrepo, githubsync}'
```

### Step 3: Initialize Sync State

```bash
# Get current states
task_data=$(tw_get_task "$e2e_uuid")
github_data=$(github_get_issue "owner/repo" 456)

# Save initial sync state
save_sync_state "$e2e_uuid" "$task_data" "$github_data"

echo "✓ Sync state initialized"
```

### Step 4: Simulate Changes

```bash
# Change task priority
tw_update_task "$e2e_uuid" "priority" "H"

# Change issue title on GitHub
github_update_issue "owner/repo" 456 "E2E test issue - UPDATED" ""

# Add label on GitHub
github_update_labels "owner/repo" 456 "enhancement" ""

# Add annotation to task
tw_add_annotation "$e2e_uuid" "Task updated locally"

# Add comment to issue
github_add_comment "owner/repo" 456 "Issue updated on GitHub"
```

### Step 5: Detect Changes

```bash
# Get current states
current_task=$(tw_get_task "$e2e_uuid")
current_issue=$(github_get_issue "owner/repo" 456)

# Get last known states
last_state=$(get_sync_state "$e2e_uuid")

# Compare (manual inspection for now)
echo "=== Last Task State ==="
echo "$last_state" | jq '.last_task_state'

echo "=== Current Task State ==="
echo "$current_task" | jq '{description, status, priority, tags}'

echo "=== Last GitHub State ==="
echo "$last_state" | jq '.last_github_state'

echo "=== Current GitHub State ==="
echo "$current_issue" | jq '{title, state, labels: [.labels[].name]}'

# You should see differences in:
# - Task priority (changed to H)
# - Issue title (changed to "E2E test issue - UPDATED")
# - Issue labels (added "enhancement")
# - Annotation count (increased by 1)
# - Comment count (increased by 1)
```

### Step 6: Update Sync State

```bash
# After "syncing" (which we'll implement in Week 3), update the state
save_sync_state "$e2e_uuid" "$current_task" "$current_issue"

echo "✓ Sync state updated"
```

## Cleanup

After testing, clean up your test data:

```bash
# Delete test tasks
task "$test_uuid" delete rc.confirmation=off 2>/dev/null
task "$e2e_uuid" delete rc.confirmation=off 2>/dev/null

# Purge deleted tasks
task status:deleted purge rc.confirmation=off 2>/dev/null

# Close/delete test issues on GitHub
gh issue close 123 --repo owner/repo
gh issue close 456 --repo owner/repo

# Or delete them (if you have permissions)
# gh issue delete 123 --repo owner/repo --yes
# gh issue delete 456 --repo owner/repo --yes

# Clear sync state
rm -f "$WORKWARRIOR_BASE/.task/github-sync/state.json"

echo "✓ Cleanup complete"
```

## Troubleshooting

### Issue: "gh CLI not authenticated"

```bash
gh auth login
# Follow the prompts to authenticate
```

### Issue: "Task not found" errors

Make sure you're using the correct UUID format. TaskWarrior accepts short UUIDs:

```bash
# Full UUID
task 827a744e-04be-4d67-ae05-9495e04b844e export

# Short UUID (first 8 chars)
task 827a744e export
```

### Issue: "UDA not defined" errors

Add the GitHub sync UDAs to your .taskrc:

```bash
cat >> "$WORKWARRIOR_BASE/.taskrc" << 'EOF'

# GitHub sync UDAs
uda.githubissue.type=numeric
uda.githubissue.label=GitHub Issue

uda.githuburl.type=string
uda.githuburl.label=GitHub URL

uda.githubrepo.type=string
uda.githubrepo.label=GitHub Repo

uda.githubauthor.type=string
uda.githubauthor.label=GitHub Author

uda.githubsync.type=string
uda.githubsync.label=Sync Enabled
uda.githubsync.values=enabled,disabled
uda.githubsync.default=disabled
EOF
```

### Issue: Permission errors on GitHub

Make sure your GitHub token has the correct scopes:
- `repo` scope for private repositories
- `public_repo` scope for public repositories

Check with:
```bash
gh auth status
```

Refresh if needed:
```bash
gh auth refresh -s repo
```

## Next Steps

Once you've verified all the foundation components work correctly:

1. ✅ State Manager can save/retrieve sync state
2. ✅ GitHub API can fetch/update issues
3. ✅ TaskWarrior API can fetch/update tasks
4. ✅ End-to-end workflow demonstrates the sync concept

You're ready to move on to **Week 3: Core Sync Logic**:
- Field Mapper (transform data between TW and GH formats)
- Change Detector (identify what changed since last sync)
- Conflict Resolver (handle simultaneous changes)

## Questions or Issues?

If you encounter any issues during manual testing, note:
- What command you ran
- What error you got
- What you expected to happen

This will help debug and improve the implementation!
