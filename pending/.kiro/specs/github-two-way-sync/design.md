# Design Document: GitHub Two-Way Sync

## Overview

This design document specifies the architecture and implementation details for bidirectional synchronization between TaskWarrior and GitHub issues. The system extends the existing one-way bugwarrior sync by adding push capabilities through a custom sync engine that uses the gh CLI tool.

### Key Design Decisions

1. **Hybrid Architecture**: Keep bugwarrior for pull operations, add gh CLI for push operations
2. **Shell-Based Implementation**: Fits Workwarrior's existing shell-based architecture
3. **Single-User Optimization**: Simplified conflict resolution using last-write-wins strategy
4. **Profile Isolation**: Each profile maintains independent sync state
5. **Append-Only Comments**: Annotations and comments are never deleted or edited, only added

### Scope

- **In Scope**: GitHub-only two-way sync, manual sync commands, interactive error correction
- **Out of Scope**: Multi-service sync, automatic background sync daemon (future), GitLab/Jira support

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────┐
│                    GitHub (via gh CLI)                   │
└────────────┬────────────────────────────────┬───────────┘
             │                                │
             │ Pull (gh issue view)           │ Push (gh issue edit)
             │                                │
             ▼                                ▲
┌─────────────────────────────────────────────────────────┐
│              Custom Sync Engine (Shell)                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │    State     │  │   Change     │  │   Conflict   │  │
│  │   Manager    │  │   Detector   │  │   Resolver   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │    Field     │  │    Error     │  │   GitHub     │  │
│  │   Mapper     │  │   Handler    │  │     API      │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└────────────┬────────────────────────────────┬───────────┘
             │                                │
             │ Read (task export)             │ Write (task modify)
             │                                │
             ▼                                ▲
┌─────────────────────────────────────────────────────────┐
│                      TaskWarrior                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │    Tasks     │  │     UDAs     │  │   .taskrc    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Data Flow

#### Push Operation (TaskWarrior → GitHub)
1. User modifies task in TaskWarrior
2. User runs `i push` or `i sync`
3. Sync Engine reads task state via `task export`
4. Change Detector compares with last known state
5. Field Mapper transforms TaskWarrior fields to GitHub format
6. GitHub API wrapper calls `gh issue edit` with updates
7. State Manager updates sync state database
8. Success/error message displayed to user

#### Pull Operation (GitHub → TaskWarrior)
1. User runs `i pull` or `i sync`
2. Sync Engine fetches issue via `gh issue view --json`
3. Change Detector compares with last known state
4. Field Mapper transforms GitHub fields to TaskWarrior format
5. TaskWarrior API wrapper calls `task modify` with updates
6. State Manager updates sync state database
7. Success/error message displayed to user

#### Bidirectional Sync
1. User runs `i sync`
2. Sync Engine fetches both task and issue states
3. Change Detector determines what changed
4. If both changed: Conflict Resolver applies last-write-wins
5. If only one changed: Appropriate push or pull operation
6. State Manager updates sync state database

## Components and Interfaces

### 1. State Manager (`lib/github-sync-state.sh`)

**Purpose**: Manage sync state database for change detection and conflict resolution

**Functions**:
```bash
# Initialize state database
init_state_database()
  Input: profile_base (string)
  Output: Creates state.json if missing
  Returns: 0 on success, 1 on failure

# Get sync state for a task
get_sync_state(task_uuid)
  Input: task_uuid (string)
  Output: JSON object with sync state
  Returns: 0 on success, 1 if not found

# Save sync state for a task
save_sync_state(task_uuid, task_data, github_data)
  Input: task_uuid (string), task_data (JSON), github_data (JSON)
  Output: Updates state.json
  Returns: 0 on success, 1 on failure

# Check if task is synced
is_task_synced(task_uuid)
  Input: task_uuid (string)
  Output: Boolean (0=synced, 1=not synced)
  Returns: 0 if synced, 1 if not

# Get all synced tasks
get_all_synced_tasks()
  Input: None
  Output: Array of task UUIDs
  Returns: 0 on success

# Remove sync state
remove_sync_state(task_uuid)
  Input: task_uuid (string)
  Output: Removes entry from state.json
  Returns: 0 on success, 1 on failure
```

**State Database Schema**:
```json
{
  "task-uuid-1": {
    "github_issue": 123,
    "github_repo": "owner/repo",
    "github_url": "https://github.com/owner/repo/issues/123",
    "sync_enabled": true,
    "last_sync": "2024-01-15T10:30:00Z",
    "last_task_state": {
      "description": "Fix bug",
      "status": "pending",
      "priority": "H",
      "tags": ["bug", "urgent"],
      "annotation_count": 2,
      "modified": "2024-01-15T10:25:00Z"
    },
    "last_github_state": {
      "title": "Fix bug",
      "state": "OPEN",
      "labels": ["bug", "urgent", "priority:high"],
      "comment_count": 3,
      "updated_at": "2024-01-15T10:20:00Z"
    },
    "sync_metadata": {
      "synced_annotations": ["hash1", "hash2"],
      "synced_comments": [123, 456, 789],
      "last_annotation_count": 2,
      "last_comment_count": 3
    },
    "conflict_strategy": "last_write_wins"
  }
}
```

### 2. GitHub API Wrapper (`lib/github-api.sh`)

**Purpose**: Provide shell functions for GitHub operations using gh CLI

**Functions**:
```bash
# Check if gh CLI is installed and authenticated
check_gh_cli()
  Input: None
  Output: Error message if not available
  Returns: 0 if available, 1 if not

# Get issue details
github_get_issue(repo, issue_number)
  Input: repo (string "owner/repo"), issue_number (integer)
  Output: JSON object with issue data
  Returns: 0 on success, 1 on failure

# Update issue title and state
github_update_issue(repo, issue_number, title, state)
  Input: repo, issue_number, title (string), state (OPEN|CLOSED)
  Output: Success/error message
  Returns: 0 on success, 1 on failure

# Add or remove labels
github_update_labels(repo, issue_number, add_labels, remove_labels)
  Input: repo, issue_number, add_labels (array), remove_labels (array)
  Output: Success/error message
  Returns: 0 on success, 1 on failure

# Add comment
github_add_comment(repo, issue_number, body)
  Input: repo, issue_number, body (string)
  Output: Comment ID
  Returns: 0 on success, 1 on failure

# Create label if doesn't exist
github_ensure_label(repo, label_name)
  Input: repo, label_name (string)
  Output: Success/error message
  Returns: 0 on success, 1 on failure

# List all issues (for bulk operations)
github_list_issues(repo, state)
  Input: repo, state (OPEN|CLOSED|ALL)
  Output: JSON array of issues
  Returns: 0 on success, 1 on failure
```

### 3. TaskWarrior API Wrapper (`lib/taskwarrior-api.sh`)

**Purpose**: Provide shell functions for TaskWarrior operations

**Functions**:
```bash
# Get task details
tw_get_task(task_uuid)
  Input: task_uuid (string)
  Output: JSON object with task data
  Returns: 0 on success, 1 on failure

# Update task fields
tw_update_task(task_uuid, updates)
  Input: task_uuid, updates (associative array)
  Output: Success/error message
  Returns: 0 on success, 1 on failure

# Add annotation
tw_add_annotation(task_uuid, text)
  Input: task_uuid, text (string)
  Output: Success/error message
  Returns: 0 on success, 1 on failure

# Get task by GitHub issue number
tw_get_task_by_issue(issue_number)
  Input: issue_number (integer)
  Output: Task UUID
  Returns: 0 on success, 1 if not found

# Check if task exists
tw_task_exists(task_uuid)
  Input: task_uuid (string)
  Output: Boolean (0=exists, 1=not exists)
  Returns: 0 if exists, 1 if not
```

### 4. Field Mapper (`lib/field-mapper.sh`)

**Purpose**: Transform data between TaskWarrior and GitHub formats

**Functions**:
```bash
# Map TaskWarrior status to GitHub state
map_status_to_github(status)
  Input: status (pending|started|waiting|completed|deleted)
  Output: state (OPEN|CLOSED)
  Returns: 0 on success

# Map GitHub state to TaskWarrior status
map_github_to_status(state, stateReason)
  Input: state (OPEN|CLOSED), stateReason (optional)
  Output: status (pending|completed|deleted)
  Returns: 0 on success

# Map TaskWarrior priority to GitHub label
map_priority_to_label(priority)
  Input: priority (H|M|L|"")
  Output: label (priority:high|priority:medium|priority:low|"")
  Returns: 0 on success

# Map GitHub labels to TaskWarrior priority
map_labels_to_priority(labels)
  Input: labels (array)
  Output: priority (H|M|L|"")
  Returns: 0 on success

# Map TaskWarrior tags to GitHub labels
map_tags_to_labels(tags)
  Input: tags (array)
  Output: labels (array, filtered and sanitized)
  Returns: 0 on success

# Map GitHub labels to TaskWarrior tags
map_labels_to_tags(labels)
  Input: labels (array)
  Output: tags (array, filtered)
  Returns: 0 on success

# Sanitize label name for GitHub
sanitize_label_name(name)
  Input: name (string)
  Output: sanitized name (alphanumeric, hyphens, underscores)
  Returns: 0 on success

# Truncate title if too long
truncate_title(title, max_length)
  Input: title (string), max_length (integer, default 256)
  Output: truncated title with "..." suffix if needed
  Returns: 0 on success

# Filter system tags
filter_system_tags(tags)
  Input: tags (array)
  Output: filtered tags (array without system tags)
  Returns: 0 on success
```

**System Tags to Exclude**:
- ACTIVE, READY, PENDING, COMPLETED, DELETED
- WAITING, RECURRING, PARENT, CHILD
- BLOCKED, UNBLOCKED, OVERDUE, TODAY
- TOMORROW, WEEK, MONTH, YEAR
- sync:* (sync metadata tags)

### 5. Change Detector (`lib/sync-detector.sh`)

**Purpose**: Detect what changed since last sync

**Functions**:
```bash
# Detect task changes
detect_task_changes(task_uuid, current_state, last_state)
  Input: task_uuid, current_state (JSON), last_state (JSON)
  Output: JSON object with changed fields
  Returns: 0 if changes detected, 1 if no changes

# Detect GitHub changes
detect_github_changes(issue_number, current_state, last_state)
  Input: issue_number, current_state (JSON), last_state (JSON)
  Output: JSON object with changed fields
  Returns: 0 if changes detected, 1 if no changes

# Check for conflicts
has_conflicts(task_changed, github_changed)
  Input: task_changed (boolean), github_changed (boolean)
  Output: Boolean (0=conflict, 1=no conflict)
  Returns: 0 if conflict, 1 if no conflict

# Determine sync action
determine_sync_action(task_changed, github_changed)
  Input: task_changed (boolean), github_changed (boolean)
  Output: action (push|pull|conflict|none)
  Returns: 0 on success

# Detect new annotations
detect_new_annotations(task_uuid, last_annotation_count)
  Input: task_uuid, last_annotation_count (integer)
  Output: Array of new annotation texts
  Returns: 0 on success

# Detect new comments
detect_new_comments(issue_number, last_comment_count)
  Input: issue_number, last_comment_count (integer)
  Output: Array of new comment objects
  Returns: 0 on success
```

### 6. Conflict Resolver (`lib/conflict-resolver.sh`)

**Purpose**: Resolve conflicts when both sides changed

**Functions**:
```bash
# Resolve conflict using last-write-wins
resolve_conflict_last_write_wins(task_uuid, task_data, github_data)
  Input: task_uuid, task_data (JSON), github_data (JSON)
  Output: action (push|pull)
  Returns: 0 on success

# Compare timestamps
compare_timestamps(task_modified, github_updated)
  Input: task_modified (ISO 8601), github_updated (ISO 8601)
  Output: result (task_newer|github_newer|equal)
  Returns: 0 on success

# Log conflict resolution
log_conflict_resolution(task_uuid, strategy, winner)
  Input: task_uuid, strategy (string), winner (task|github)
  Output: Writes to error log
  Returns: 0 on success
```

### 7. Error Handler (`lib/error-handler.sh`)

**Purpose**: Handle sync errors with interactive correction

**Functions**:
```bash
# Parse GitHub error response
parse_github_error(error_response)
  Input: error_response (JSON)
  Output: Structured error object
  Returns: 0 on success

# Handle title validation error
handle_title_error(task_uuid, current_value, error_message)
  Input: task_uuid, current_value, error_message
  Output: Interactive prompt for correction
  Returns: 0 if corrected, 1 if skipped

# Handle state validation error
handle_state_error(task_uuid, current_value, error_message)
  Input: task_uuid, current_value, error_message
  Output: Interactive prompt for correction
  Returns: 0 if corrected, 1 if skipped

# Handle label validation error
handle_label_error(task_uuid, current_value, error_message)
  Input: task_uuid, current_value, error_message
  Output: Interactive prompt for correction
  Returns: 0 if corrected, 1 if skipped

# Handle permission error
handle_permission_error(task_uuid, operation, error_message)
  Input: task_uuid, operation, error_message
  Output: Display error and suggestions
  Returns: 1 (cannot auto-correct)

# Handle rate limit error
handle_rate_limit_error(error_response)
  Input: error_response (JSON with rate limit info)
  Output: Interactive prompt to wait or skip
  Returns: 0 if waiting, 1 if skipped

# Retry sync with error handling
sync_with_error_handling(task_uuid, operation, max_retries)
  Input: task_uuid, operation (push|pull), max_retries (default 3)
  Output: Success/error message
  Returns: 0 on success, 1 on failure
```

### 8. Sync Operations (`lib/sync-pull.sh`, `lib/sync-push.sh`, `lib/sync-bidirectional.sh`)

**Purpose**: Implement push, pull, and bidirectional sync operations

**Functions in sync-pull.sh**:
```bash
# Pull single issue
sync_pull_issue(task_uuid, issue_number)
  Input: task_uuid, issue_number
  Output: Success/error message
  Returns: 0 on success, 1 on failure

# Pull all synced issues
sync_pull_all()
  Input: None
  Output: Summary of pull operations
  Returns: 0 on success
```

**Functions in sync-push.sh**:
```bash
# Push single task
sync_push_task(task_uuid, issue_number)
  Input: task_uuid, issue_number
  Output: Success/error message
  Returns: 0 on success, 1 on failure

# Push all synced tasks
sync_push_all()
  Input: None
  Output: Summary of push operations
  Returns: 0 on success
```

**Functions in sync-bidirectional.sh**:
```bash
# Sync single task bidirectionally
sync_task_bidirectional(task_uuid)
  Input: task_uuid
  Output: Success/error message
  Returns: 0 on success, 1 on failure

# Sync all tasks bidirectionally
sync_all_tasks()
  Input: None
  Output: Summary of sync operations
  Returns: 0 on success
```

### 9. CLI Interface (`services/custom/github-sync.sh`)

**Purpose**: Provide command-line interface for sync operations

**Functions**:
```bash
# Main entry point
main(args)
  Input: Command-line arguments
  Output: Routes to appropriate subcommand
  Returns: Exit code from subcommand

# Enable sync for a task
cmd_enable(task_uuid, issue_number, repo)
  Input: task_uuid, issue_number, repo (optional)
  Output: Success/error message
  Returns: 0 on success, 1 on failure

# Disable sync for a task
cmd_disable(task_uuid)
  Input: task_uuid
  Output: Success/error message
  Returns: 0 on success, 1 on failure

# Push operation
cmd_push(task_uuid, dry_run)
  Input: task_uuid (optional), dry_run (boolean)
  Output: Success/error message
  Returns: 0 on success, 1 on failure

# Pull operation
cmd_pull(task_uuid, dry_run)
  Input: task_uuid (optional), dry_run (boolean)
  Output: Success/error message
  Returns: 0 on success, 1 on failure

# Bidirectional sync
cmd_sync(task_uuid, dry_run)
  Input: task_uuid (optional), dry_run (boolean)
  Output: Success/error message
  Returns: 0 on success, 1 on failure

# Show sync status
cmd_status()
  Input: None
  Output: Display sync status for all tasks
  Returns: 0 on success

# Show help
cmd_help(subcommand)
  Input: subcommand (optional)
  Output: Display help text
  Returns: 0 on success
```

## Data Models

### Task State Model
```json
{
  "uuid": "abc-123-def-456",
  "description": "Fix authentication bug",
  "status": "pending",
  "priority": "H",
  "tags": ["bug", "urgent", "backend"],
  "annotations": [
    {
      "entry": "20240115T100000Z",
      "description": "Reproduced on staging"
    }
  ],
  "modified": "20240115T103000Z",
  "githubissue": 123,
  "githuburl": "https://github.com/owner/repo/issues/123",
  "githubrepo": "owner/repo",
  "githubauthor": "octocat",
  "githubsync": "enabled"
}
```

### GitHub Issue Model
```json
{
  "number": 123,
  "title": "Fix authentication bug",
  "state": "OPEN",
  "stateReason": null,
  "labels": [
    {"name": "bug"},
    {"name": "urgent"},
    {"name": "backend"},
    {"name": "priority:high"}
  ],
  "comments": [
    {
      "id": 456,
      "author": {"login": "octocat"},
      "body": "Reproduced on staging",
      "createdAt": "2024-01-15T10:00:00Z"
    }
  ],
  "createdAt": "2024-01-15T09:00:00Z",
  "updatedAt": "2024-01-15T10:30:00Z",
  "closedAt": null,
  "url": "https://github.com/owner/repo/issues/123"
}
```

### Field Mapping Table

| TaskWarrior Field | Direction | GitHub Field | Transformation |
|-------------------|-----------|--------------|----------------|
| description | ↔ | title | Direct copy, truncate if >256 chars |
| status | ↔ | state | pending/started/waiting → OPEN, completed/deleted → CLOSED |
| priority | ↔ | labels (priority:*) | H → priority:high, M → priority:medium, L → priority:low |
| tags | ↔ | labels | Filter system tags, sanitize names |
| annotations | ↔ | comments | Prefix with "[TaskWarrior]" or "[GitHub @user]", append-only |
| modified | → | updatedAt | For change detection only |
| githubissue | ← | number | Store issue number |
| githuburl | ← | url | Store issue URL |
| githubrepo | ← | (derived) | Extract from URL |
| githubauthor | ← | author.login | Store author username |
| entry | ← | createdAt | Set on first sync only |
| end | ← | closedAt | Set when issue closed |

## Correctness Properties


*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Core Sync Properties

Property 1: Description/Title Round Trip
*For any* task with a valid description, syncing to GitHub then back to TaskWarrior should preserve the description (modulo truncation for descriptions >256 chars)
**Validates: Requirements 1.1, 1.2**

Property 2: Status/State Round Trip
*For any* task status (pending, started, waiting, completed, deleted), syncing to GitHub then back to TaskWarrior should preserve the semantic meaning (pending/started/waiting → OPEN → pending, completed/deleted → CLOSED → completed)
**Validates: Requirements 1.3, 1.4, 6.1, 6.2**

Property 3: Priority/Label Round Trip
*For any* task priority (H, M, L, or empty), syncing to GitHub then back to TaskWarrior should preserve the priority value
**Validates: Requirements 1.5, 1.6, 6.3, 6.4**

Property 4: Tags/Labels Round Trip
*For any* set of non-system tags, syncing to GitHub then back to TaskWarrior should preserve all tags (excluding system tags like ACTIVE, READY, etc.)
**Validates: Requirements 1.7, 1.8, 6.5, 6.6**

Property 5: Annotation/Comment Append-Only
*For any* task with annotations, syncing to GitHub multiple times should never delete or modify existing comments, only append new ones with "[TaskWarrior]" prefix
**Validates: Requirements 1.9, 15.5, 15.7**

Property 6: Comment/Annotation Append-Only
*For any* GitHub issue with comments, syncing to TaskWarrior multiple times should never delete or modify existing annotations, only append new ones with "[GitHub @username]" prefix
**Validates: Requirements 1.10, 15.6, 15.7**

### Metadata and State Properties

Property 7: Metadata Population
*For any* GitHub issue synced to TaskWarrior, the task should have githubissue, githuburl, githubrepo, and githubauthor UDAs populated with correct values from the issue
**Validates: Requirements 2.1, 2.2, 2.3, 2.4**

Property 8: State Persistence
*For any* task synced with GitHub, the sync state database should contain the last known task state and GitHub state after sync completes
**Validates: Requirements 3.1, 3.2**

Property 9: Annotation/Comment Idempotence
*For any* annotation or comment, syncing it multiple times should not create duplicates (tracked by hash for annotations, ID for comments)
**Validates: Requirements 3.3, 3.4, 15.1, 15.2, 15.3, 15.4**

Property 10: Profile Isolation
*For any* two different profiles, their sync state databases should be independent and stored in separate profile-specific paths
**Validates: Requirements 3.6, 11.2, 11.4**

### Change Detection Properties

Property 11: Field Change Detection
*For any* task or issue, if any of the synced fields (description/title, status/state, priority/labels, tags/labels, annotation count/comment count) changes, the change detector should identify it
**Validates: Requirements 4.1, 4.2**

Property 12: Sync Action Determination
*For any* task-issue pair, the sync engine should determine the correct action: push if only task changed, pull if only issue changed, conflict resolution if both changed, skip if neither changed
**Validates: Requirements 4.3, 4.4, 4.5, 4.6**

Property 13: Last-Write-Wins Conflict Resolution
*For any* conflict where both task and issue changed, the conflict resolver should compare timestamps and apply the more recent change
**Validates: Requirements 5.1, 5.2, 5.3**

### Field Mapping Properties

Property 14: System Tag Exclusion
*For any* task with system tags (ACTIVE, READY, PENDING, COMPLETED, DELETED, WAITING, RECURRING, BLOCKED, OVERDUE, TODAY, TOMORROW, WEEK, MONTH, YEAR, sync:*), those tags should not be synced to GitHub labels
**Validates: Requirements 6.5**

Property 15: Priority Label Exclusion
*For any* GitHub issue with labels, priority:* labels should not be synced to TaskWarrior tags (they map to priority field instead)
**Validates: Requirements 6.6**

Property 16: Title Truncation
*For any* task description exceeding 256 characters, the field mapper should truncate it to 253 characters plus "..." when syncing to GitHub
**Validates: Requirements 6.7**

Property 17: Annotation/Comment Prefix
*For any* annotation synced to GitHub, the resulting comment should start with "[TaskWarrior]" prefix; for any comment synced to TaskWarrior, the resulting annotation should start with "[GitHub @username]" prefix
**Validates: Requirements 6.8, 6.9, 15.5, 15.6**

### Sync Operation Properties

Property 18: Batch Push Completeness
*For any* set of changed tasks, running "i push" should attempt to push all of them, continuing even if some fail
**Validates: Requirements 7.1, 18.2**

Property 19: Batch Pull Completeness
*For any* set of changed issues, running "i pull" should attempt to pull all of them, continuing even if some fail
**Validates: Requirements 7.2, 18.2**

Property 20: Bidirectional Sync Completeness
*For any* set of synced tasks, running "i sync" should process all of them bidirectionally
**Validates: Requirements 7.3**

Property 21: Sync Success Feedback
*For any* successful sync operation, the sync engine should display a success message
**Validates: Requirements 7.7**

Property 22: Sync Error Feedback
*For any* failed sync operation, the sync engine should display an error message and log details to the error log
**Validates: Requirements 7.8, 13.2, 13.5**

### Enablement and Configuration Properties

Property 23: Sync Eligibility
*For any* task with a githubissue UDA, the sync engine should consider it eligible for syncing
**Validates: Requirements 8.1**

Property 24: Sync Enablement UDA
*For any* task linked to GitHub, the githubsync UDA should be set to "enabled"; for any task unlinked, it should be set to "disabled"
**Validates: Requirements 8.4, 8.5**

Property 25: Initial Pull on Enable
*For any* task when sync is enabled, the sync engine should perform an initial pull to populate task fields from the GitHub issue
**Validates: Requirements 8.6**

Property 26: Configuration Defaults
*For any* profile without a configuration file, the sync engine should use default values for all settings
**Validates: Requirements 12.2**

Property 27: Tag Exclusion Configuration
*For any* tags listed in the configuration's exclude list, those tags should not be synced to GitHub labels
**Validates: Requirements 12.6**

Property 28: Label Exclusion Configuration
*For any* labels listed in the configuration's exclude list, those labels should not be synced to TaskWarrior tags
**Validates: Requirements 12.7**

### Error Handling Properties

Property 29: Error Display Completeness
*For any* field validation error, the error handler should display the current value, error message, and requirements
**Validates: Requirements 9.1**

Property 30: Retry Logic
*For any* corrected error, the sync engine should automatically retry the sync operation up to 3 times before giving up
**Validates: Requirements 9.7, 9.8**

### Logging Properties

Property 31: Operation Logging
*For any* sync operation, the sync engine should log the task UUID, operation type, result, and duration to the sync log
**Validates: Requirements 13.1, 13.3, 13.4**

Property 32: Error Logging
*For any* sync error, the sync engine should log the error category, field, and GitHub response to the error log in JSON format
**Validates: Requirements 13.2, 13.5, 13.6**

Property 33: Conflict Logging
*For any* conflict resolution, the conflict resolver should log the resolution strategy and winner to the error log
**Validates: Requirements 5.5**

### Integration Properties

Property 34: Bugwarrior Coexistence
*For any* task created by bugwarrior, the sync engine should not interfere with bugwarrior's operation and should preserve all bugwarrior UDAs
**Validates: Requirements 14.1, 14.3**

Property 35: Bugwarrior Task Detection
*For any* task created by bugwarrior (has bugwarrior UDAs), the sync engine should detect it and initialize sync state
**Validates: Requirements 14.2**

Property 36: Shell Command Routing
*For any* i() function call, the function should route "push", "pull", and "sync" to the sync engine, and "custom" to the configuration tool
**Validates: Requirements 19.1, 19.5**

Property 37: Profile Requirement
*For any* sync command, the i() function should check that a profile is active before executing
**Validates: Requirements 11.3, 19.4**

### Dry-Run Properties

Property 38: Dry-Run Immutability
*For any* sync operation with --dry-run flag, no changes should be made to TaskWarrior tasks, GitHub issues, or the state database
**Validates: Requirements 17.1, 17.2, 17.3, 17.4, 17.5, 17.6**

Property 39: Dry-Run Display
*For any* sync operation with --dry-run flag, the sync engine should display all planned operations without executing them
**Validates: Requirements 17.1, 17.2, 17.3**

### Batch Operation Properties

Property 40: Sequential Processing
*For any* batch sync operation, tasks should be processed sequentially (one at a time) to avoid rate limiting
**Validates: Requirements 18.1**

Property 41: Batch Summary
*For any* completed batch operation, the sync engine should display a summary showing the count of successes and failures
**Validates: Requirements 18.3**

Property 42: Rate Limit Respect
*For any* batch operation, if GitHub API rate limit is approached, the sync engine should pause to avoid exceeding the limit
**Validates: Requirements 18.5**

## Error Handling

### Error Categories

1. **Validation Errors**: Field values that don't meet GitHub API requirements
   - Title too long (>256 chars)
   - Invalid label format
   - Invalid state value
   - Empty required fields

2. **Permission Errors**: GitHub API access denied
   - No write access to repository
   - Cannot assign users
   - Cannot create labels
   - Token lacks required scopes

3. **Rate Limit Errors**: GitHub API rate limiting
   - Primary rate limit exceeded (5000 requests/hour)
   - Secondary rate limit exceeded
   - Abuse detection triggered

4. **Network Errors**: Connection failures
   - Timeout
   - Connection refused
   - DNS resolution failure
   - SSL certificate error

5. **Conflict Errors**: Simultaneous changes on both sides
   - Task modified since last sync
   - Issue modified since last sync
   - Both modified (requires resolution)

### Error Handling Strategy

**Interactive Correction**:
- Display current value, error message, and requirements
- Suggest fixes when possible (truncation, sanitization)
- Prompt user for correction
- Validate corrected value
- Automatically retry after correction

**Retry Logic**:
- Maximum 3 retry attempts per operation
- Exponential backoff for network errors
- Immediate retry for corrected validation errors
- Skip task after max retries exceeded

**Error Logging**:
- All errors logged to `$WORKWARRIOR_BASE/.task/github-sync/errors.log`
- JSON format for structured logging
- Include timestamp, task UUID, error category, field, message, and GitHub response

**Field-Specific Handlers**:
- `handle_title_error()`: Title validation and truncation
- `handle_state_error()`: State mapping correction
- `handle_label_error()`: Label format sanitization
- `handle_permission_error()`: Permission troubleshooting
- `handle_rate_limit_error()`: Rate limit wait/skip options

### Error Recovery

**State Corruption**:
- If state database is corrupted or missing, initialize new state
- Log warning about state re-initialization
- Perform full sync to rebuild state

**Partial Sync Failures**:
- Continue processing remaining tasks in batch
- Display summary of successes and failures
- Offer interactive correction for failed tasks

**GitHub API Failures**:
- Retry with exponential backoff for transient errors
- Display helpful error messages for permanent errors
- Suggest solutions (check permissions, refresh token, etc.)

## Testing Strategy

### Dual Testing Approach

The testing strategy uses both unit tests and property-based tests to ensure comprehensive coverage:

**Unit Tests**: Verify specific examples, edge cases, and error conditions
- Specific field mapping examples (H → priority:high)
- Edge cases (empty description, 256-char title)
- Error conditions (missing gh CLI, invalid token)
- Integration points (bugwarrior coexistence)

**Property-Based Tests**: Verify universal properties across all inputs
- Round-trip properties (description ↔ title)
- Idempotence properties (duplicate prevention)
- Invariant properties (system tag exclusion)
- Conflict resolution properties (last-write-wins)

### Property-Based Testing Configuration

**Library**: Use `bats` (Bash Automated Testing System) with custom property test helpers

**Test Configuration**:
- Minimum 100 iterations per property test
- Each test tagged with feature name and property number
- Tag format: `# Feature: github-two-way-sync, Property N: <property text>`

**Test Data Generation**:
- Random task descriptions (various lengths, special characters)
- Random statuses (pending, started, waiting, completed, deleted)
- Random priorities (H, M, L, empty)
- Random tags (including system tags to test filtering)
- Random GitHub states (OPEN, CLOSED)
- Random labels (including priority labels)
- Random timestamps (for conflict resolution)

### Unit Test Coverage

**Component Tests**:
- State Manager: CRUD operations on state database
- GitHub API: Mock gh CLI responses
- TaskWarrior API: Mock task export/modify
- Field Mapper: All mapping functions
- Change Detector: All change detection scenarios
- Conflict Resolver: All resolution strategies
- Error Handler: All error categories

**Integration Tests**:
- Full push cycle (task → GitHub)
- Full pull cycle (GitHub → task)
- Bidirectional sync cycle
- Conflict resolution flow
- Error correction flow
- Batch operations

**Edge Case Tests**:
- Empty description (should fail validation)
- 256-character title (boundary case)
- 257-character title (should truncate)
- Task with all system tags (should sync nothing)
- Issue with only priority labels (should map to priority, not tags)
- Simultaneous changes with equal timestamps (GitHub wins)
- Missing state database (should initialize)
- Corrupted state database (should re-initialize)

### Test Environment

**Mock GitHub API**:
- Use `gh` CLI with mock responses
- Test data stored in `tests/fixtures/github/`
- Mock rate limiting scenarios
- Mock error responses

**Test TaskWarrior**:
- Isolated test profile in `tests/fixtures/profiles/test-profile/`
- Clean state before each test
- Verify task modifications
- Check UDA values

**Test State Database**:
- Temporary state database per test
- Verify state persistence
- Test state corruption recovery

### Continuous Integration

**Pre-commit Hooks**:
- Run unit tests
- Run property tests (reduced iterations for speed)
- Check shell script syntax
- Verify no hardcoded paths

**CI Pipeline**:
- Run full test suite (100 iterations per property)
- Test on multiple shell versions (bash 4.x, 5.x)
- Test with different TaskWarrior versions
- Test with different gh CLI versions
- Generate coverage report

### Manual Testing Checklist

**Before Release**:
- [ ] Test with real GitHub repository
- [ ] Test with multiple profiles
- [ ] Test conflict resolution with real timing
- [ ] Test error correction flow interactively
- [ ] Test batch operations with 10+ tasks
- [ ] Test rate limiting with rapid syncs
- [ ] Test bugwarrior coexistence
- [ ] Test profile switching
- [ ] Verify all help text displays correctly
- [ ] Verify all error messages are helpful

## Implementation Notes

### Dependencies

**Required**:
- `bash` 4.0 or later
- `jq` for JSON parsing
- `gh` CLI (GitHub CLI) authenticated
- `task` (TaskWarrior) 2.6.0 or later

**Optional**:
- `bugwarrior` for pull-only sync (existing functionality)

### File Structure

```
lib/
├── github-sync-state.sh       # State management
├── github-api.sh              # GitHub API wrapper
├── taskwarrior-api.sh         # TaskWarrior API wrapper
├── field-mapper.sh            # Field transformations
├── sync-detector.sh           # Change detection
├── conflict-resolver.sh       # Conflict resolution
├── error-handler.sh           # Interactive error correction
├── sync-pull.sh               # Pull operations
├── sync-push.sh               # Push operations
└── sync-bidirectional.sh      # Bidirectional sync

services/custom/
└── github-sync.sh             # CLI interface

$WORKWARRIOR_BASE/.task/github-sync/
├── state.json                 # Sync state database
├── sync.log                   # Operation log
└── errors.log                 # Error log

$WORKWARRIOR_BASE/.config/github-sync/
└── config.sh                  # Configuration file
```

### Configuration File Format

```bash
# GitHub Two-Way Sync Configuration
# Location: $WORKWARRIOR_BASE/.config/github-sync/config.sh

# Default repository (owner/repo format)
GITHUB_DEFAULT_REPO="owner/repo"

# Conflict resolution strategy
# Options: last_write_wins, github_wins, task_wins, manual
GITHUB_SYNC_STRATEGY="last_write_wins"

# Auto-sync on task modify (future feature)
GITHUB_AUTO_SYNC=false

# Fields to sync (comma-separated)
GITHUB_SYNC_FIELDS="description,status,priority,tags,annotations"

# Tags to exclude from syncing (comma-separated)
GITHUB_EXCLUDE_TAGS="ACTIVE,READY,PENDING,COMPLETED,DELETED,WAITING,RECURRING,BLOCKED,OVERDUE,TODAY,TOMORROW,WEEK,MONTH,YEAR,sync:*"

# Labels to exclude from syncing (comma-separated)
GITHUB_EXCLUDE_LABELS="sync:*"

# Annotation/comment prefixes
GITHUB_ANNOTATION_PREFIX="[TaskWarrior]"
GITHUB_COMMENT_PREFIX="[GitHub"

# Logging
GITHUB_LOG_LEVEL="INFO"  # DEBUG, INFO, WARN, ERROR
```

### Performance Considerations

**Rate Limiting**:
- GitHub API: 5000 requests/hour for authenticated users
- Batch operations process sequentially to avoid hitting limits
- Pause and wait if rate limit approached

**State Database Size**:
- JSON file grows with number of synced tasks
- Typical size: ~1KB per task
- 1000 tasks ≈ 1MB
- Consider periodic cleanup of old state

**Sync Performance**:
- Single task sync: ~1-2 seconds (network latency)
- Batch sync: ~1-2 seconds per task (sequential)
- 100 tasks: ~2-3 minutes

### Security Considerations

**GitHub Token**:
- Requires `repo` scope for private repositories
- Requires `public_repo` scope for public repositories
- Token stored by gh CLI (secure credential storage)
- Never log or display token

**State Database**:
- Contains task UUIDs and issue numbers (not sensitive)
- Stored in profile directory (user-only access)
- No passwords or tokens stored

**Error Logs**:
- May contain task descriptions and GitHub responses
- Stored in profile directory (user-only access)
- Rotate logs periodically to limit size

### Future Enhancements

**Phase 2 Features** (out of scope for MVP):
- Automatic background sync daemon
- TaskWarrior hooks for real-time sync
- Multi-service support (GitLab, Jira)
- Assignee mapping
- Milestone mapping
- Due date mapping
- Custom field mappings
- Webhook support for instant GitHub → TaskWarrior sync

**Optimization Opportunities**:
- Parallel batch operations (with rate limit awareness)
- Incremental state updates (only changed fields)
- State database indexing for faster lookups
- Caching GitHub API responses
