# GitHub Two-Way Sync - Implementation Plan

## Executive Summary

This plan outlines the implementation of bidirectional synchronization between TaskWarrior and GitHub issues, focusing on single-user workflows (increasingly common with AI agents). We'll leverage the `gh` CLI tool for GitHub operations while building a custom sync engine.

## Use Case: Single-User AI-Assisted Workflow

**Scenario:** Developer + AI agents working on personal/team projects
- Developer creates issues in GitHub
- AI agents update issue status, add comments
- Developer works in TaskWarrior for task management
- Changes flow bidirectionally without manual intervention

**Key Assumption:** Single user/agent context reduces conflict complexity significantly

## Architecture Decision: `gh` CLI vs Bugwarrior

### Option 1: Extend Bugwarrior (Modify Existing)

**How Bugwarrior Works:**
```python
# Bugwarrior's current flow
1. Read bugwarriorrc config
2. For each service:
   - Fetch issues via service API
   - Convert to TaskWarrior format
   - Create/update tasks via `task` command
3. Store state in TaskWarrior UDAs
```

**Pros:**
- Already handles GitHub API
- Existing field mappings
- UDA management built-in
- Multi-service architecture

**Cons:**
- Python codebase (adds dependency)
- Not designed for push operations
- Would require significant refactoring
- Harder to maintain as fork
- Complex codebase to modify

### Option 2: Use `gh` CLI (Recommended)

**How `gh` CLI Works:**
```bash
# GitHub CLI capabilities
gh issue list                    # List issues
gh issue view 123                # Get issue details
gh issue create --title "..."    # Create issue
gh issue edit 123 --state closed # Update issue
gh issue comment 123 --body "..." # Add comment
```

**Pros:**
- Simple, well-documented CLI
- Official GitHub tool
- JSON output for parsing
- Handles authentication
- Active maintenance
- Shell-friendly

**Cons:**
- GitHub-only (but that's our scope)
- Requires `gh` installed
- No built-in state management

### Decision: Use `gh` CLI + Custom Sync Engine

**Rationale:**
1. **Simplicity**: Shell scripts easier to maintain than Python fork
2. **Focus**: GitHub-only scope matches `gh` perfectly
3. **Integration**: Fits Workwarrior's shell-based architecture
4. **Maintenance**: Official tool, no fork to maintain
5. **Flexibility**: Full control over sync logic

**Architecture:**
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
└────────────┬────────────────────────────────┬───────────┘
             │                                │
             │ Read (task export)             │ Write (task modify)
             │                                │
             ▼                                ▲
┌─────────────────────────────────────────────────────────┐
│                      TaskWarrior                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │    Tasks     │  │     Hooks    │  │     UDAs     │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Implementation Strategy

### Phase 1: Foundation (Week 1-2)

#### 1.1 State Management
**File:** `lib/github-sync-state.sh`

```bash
# State stored in JSON
~/.task/github-sync/
├── state.json          # Sync state per task
├── queue/              # Pending operations
│   ├── push/          # Changes to push
│   └── pull/          # Changes to pull
└── conflicts/          # Manual resolution needed
```

**State Schema:**
```json
{
  "task-uuid": {
    "github_issue": 123,
    "github_repo": "owner/repo",
    "last_sync": "2024-01-15T10:30:00Z",
    "last_task_state": {
      "description": "Fix bug",
      "status": "pending",
      "modified": "2024-01-15T10:25:00Z"
    },
    "last_github_state": {
      "title": "Fix bug",
      "state": "open",
      "updated_at": "2024-01-15T10:20:00Z"
    },
    "sync_enabled": true,
    "conflict_strategy": "last_write_wins"
  }
}
```

#### 1.2 GitHub Integration
**File:** `lib/github-api.sh`

```bash
# Wrapper functions for gh CLI
github_get_issue()      # Fetch issue details
github_update_issue()   # Update issue
github_create_issue()   # Create new issue
github_add_comment()    # Add comment
github_list_issues()    # List issues
```

#### 1.3 TaskWarrior Integration
**File:** `lib/taskwarrior-api.sh`

```bash
# TaskWarrior operations
tw_get_task()          # Get task details
tw_update_task()       # Update task
tw_create_task()       # Create task
tw_add_annotation()    # Add annotation
```

### Phase 2: Core Sync Logic (Week 2-3)

#### 2.1 Change Detection
**File:** `lib/sync-detector.sh`

```bash
detect_task_changes()     # Compare task states
detect_github_changes()   # Compare GitHub states
has_conflicts()           # Check for conflicts
```

**Logic:**
```bash
# Detect what changed
if task_modified_after_last_sync; then
    local_changes="detected"
fi

if github_updated_after_last_sync; then
    remote_changes="detected"
fi

# Determine action
if [[ -n "$local_changes" && -z "$remote_changes" ]]; then
    action="push"
elif [[ -z "$local_changes" && -n "$remote_changes" ]]; then
    action="pull"
elif [[ -n "$local_changes" && -n "$remote_changes" ]]; then
    action="conflict"
else
    action="none"
fi
```

#### 2.2 Field Mapping
**File:** `lib/field-mapper.sh`

```bash
# TaskWarrior → GitHub
map_status_to_github()      # pending→open, completed→closed
map_priority_to_labels()    # H→priority:high
map_tags_to_labels()        # tags→labels
map_annotations_to_comments() # annotations→comments

# GitHub → TaskWarrior
map_github_to_status()      # open→pending, closed→completed
map_labels_to_priority()    # priority:high→H
map_labels_to_tags()        # labels→tags
map_comments_to_annotations() # comments→annotations
```

**Mapping Table:**
```
TaskWarrior          GitHub
-----------          ------
description    ←→    title
status         ←→    state (open/closed)
priority       ←→    labels (priority:*)
tags           ←→    labels
annotations    ←→    comments
modified       ←→    updated_at
uuid           ←→    UDA: githubissue
```

#### 2.3 Conflict Resolution
**File:** `lib/conflict-resolver.sh`

```bash
resolve_conflict_last_write_wins()  # Compare timestamps
resolve_conflict_github_wins()      # GitHub authoritative
resolve_conflict_task_wins()        # TaskWarrior authoritative
resolve_conflict_manual()           # Prompt user
```

**Single-User Optimization:**
Since we assume single-user context, conflicts are rare:
- Most conflicts are timing issues (rapid edits)
- Can use simple "last write wins"
- Manual resolution for edge cases

### Phase 3: Sync Operations (Week 3-4)

#### 3.1 Pull Operation
**File:** `lib/sync-pull.sh`

```bash
sync_pull_issue() {
    local task_uuid="$1"
    local issue_number="$2"
    
    # 1. Fetch GitHub issue
    local github_data=$(gh issue view "$issue_number" --json title,state,labels,comments,updatedAt)
    
    # 2. Get current task state
    local task_data=$(task "$task_uuid" export)
    
    # 3. Check for conflicts
    if has_conflicts "$task_data" "$github_data"; then
        resolve_conflict "$task_uuid" "$task_data" "$github_data"
        return $?
    fi
    
    # 4. Map GitHub → TaskWarrior
    local tw_updates=$(map_github_to_task "$github_data")
    
    # 5. Update TaskWarrior
    task "$task_uuid" modify $tw_updates
    
    # 6. Update sync state
    save_sync_state "$task_uuid" "$task_data" "$github_data"
}
```

#### 3.2 Push Operation
**File:** `lib/sync-push.sh`

```bash
sync_push_task() {
    local task_uuid="$1"
    local issue_number="$2"
    
    # 1. Get current task state
    local task_data=$(task "$task_uuid" export)
    
    # 2. Fetch GitHub issue
    local github_data=$(gh issue view "$issue_number" --json title,state,labels,updatedAt)
    
    # 3. Check for conflicts
    if has_conflicts "$task_data" "$github_data"; then
        resolve_conflict "$task_uuid" "$task_data" "$github_data"
        return $?
    fi
    
    # 4. Map TaskWarrior → GitHub
    local gh_updates=$(map_task_to_github "$task_data")
    
    # 5. Update GitHub
    gh issue edit "$issue_number" \
        --title "$gh_updates[title]" \
        --state "$gh_updates[state]"
    
    # Add labels
    gh issue edit "$issue_number" --add-label "$gh_updates[labels]"
    
    # Add comments for new annotations
    for comment in "$gh_updates[comments]"; do
        gh issue comment "$issue_number" --body "$comment"
    done
    
    # 6. Update sync state
    save_sync_state "$task_uuid" "$task_data" "$github_data"
}
```

#### 3.3 Bidirectional Sync
**File:** `lib/sync-bidirectional.sh`

```bash
sync_task_bidirectional() {
    local task_uuid="$1"
    
    # Get sync state
    local sync_state=$(get_sync_state "$task_uuid")
    local issue_number=$(echo "$sync_state" | jq -r '.github_issue')
    
    # Get current states
    local task_data=$(task "$task_uuid" export)
    local github_data=$(gh issue view "$issue_number" --json title,state,labels,comments,updatedAt)
    
    # Detect changes
    local task_changed=$(task_changed_since_last_sync "$task_data" "$sync_state")
    local github_changed=$(github_changed_since_last_sync "$github_data" "$sync_state")
    
    # Determine action
    if [[ "$task_changed" == "true" && "$github_changed" == "false" ]]; then
        # Only task changed - push
        sync_push_task "$task_uuid" "$issue_number"
        
    elif [[ "$task_changed" == "false" && "$github_changed" == "true" ]]; then
        # Only GitHub changed - pull
        sync_pull_issue "$task_uuid" "$issue_number"
        
    elif [[ "$task_changed" == "true" && "$github_changed" == "true" ]]; then
        # Both changed - resolve conflict
        resolve_conflict "$task_uuid" "$task_data" "$github_data"
        
    else
        # No changes
        log_debug "No changes for task $task_uuid"
    fi
}
```

### Phase 4: TaskWarrior Hook Integration (Week 4)

#### 4.1 On-Modify Hook
**File:** `~/.task/hooks/on-modify-github-sync`

```bash
#!/usr/bin/env bash
# TaskWarrior on-modify hook for GitHub sync

# Read old and new task from stdin
read old_task
read new_task

# Extract UUID
task_uuid=$(echo "$new_task" | jq -r '.uuid')

# Check if task is synced with GitHub
if is_github_synced "$task_uuid"; then
    # Queue push operation (async)
    queue_push_operation "$task_uuid" &
fi

# Return new task (required by TaskWarrior)
echo "$new_task"
```

#### 4.2 Sync Daemon (Optional)
**File:** `services/daemons/github-sync-daemon.sh`

```bash
#!/usr/bin/env bash
# Background daemon for periodic sync

SYNC_INTERVAL=300  # 5 minutes

while true; do
    # Get all synced tasks
    synced_tasks=$(get_all_synced_tasks)
    
    for task_uuid in $synced_tasks; do
        # Sync each task
        sync_task_bidirectional "$task_uuid"
    done
    
    # Process queued operations
    process_push_queue
    process_pull_queue
    
    sleep "$SYNC_INTERVAL"
done
```

### Phase 5: CLI Interface (Week 4-5)

#### 5.1 Main Command
**File:** `services/custom/github-sync.sh`

```bash
#!/usr/bin/env bash
# GitHub two-way sync service

cmd_enable() {
    # Enable sync for a task
    local task_uuid="$1"
    local issue_number="$2"
    local repo="${3:-$(get_default_repo)}"
    
    enable_github_sync "$task_uuid" "$issue_number" "$repo"
}

cmd_disable() {
    # Disable sync for a task
    local task_uuid="$1"
    disable_github_sync "$task_uuid"
}

cmd_sync() {
    # Manually trigger sync
    local task_uuid="$1"
    
    if [[ -z "$task_uuid" ]]; then
        # Sync all
        sync_all_tasks
    else
        # Sync specific task
        sync_task_bidirectional "$task_uuid"
    fi
}

cmd_status() {
    # Show sync status
    show_sync_status
}

cmd_conflicts() {
    # List pending conflicts
    list_conflicts
}

cmd_resolve() {
    # Resolve a conflict
    local task_uuid="$1"
    local strategy="${2:-manual}"
    
    resolve_conflict_interactive "$task_uuid" "$strategy"
}

cmd_config() {
    # Configure sync settings
    configure_github_sync
}
```

#### 5.2 Integration with `i` Command
**Update:** `lib/shell-integration.sh`

```bash
i() {
    # ... existing code ...
    
    # Add sync commands
    case "${args[0]}" in
        sync)
            # Two-way sync operations
            shift
            github-sync.sh sync "$@"
            ;;
        enable-sync)
            # Enable two-way sync
            shift
            github-sync.sh enable "$@"
            ;;
        disable-sync)
            # Disable two-way sync
            shift
            github-sync.sh disable "$@"
            ;;
        *)
            # Existing bugwarrior commands
            bugwarrior "${args[@]}"
            ;;
    esac
}
```

## Data Flow Examples

### Example 1: Task Status Changed

```
User Action: task abc-123 done

1. TaskWarrior on-modify hook triggered
2. Hook detects task is synced (has githubissue UDA)
3. Hook queues push operation
4. Sync engine processes queue:
   a. Reads task state: status=completed
   b. Maps to GitHub: state=closed
   c. Calls: gh issue edit 42 --state closed
   d. Updates sync state
5. GitHub issue #42 now closed
```

### Example 2: GitHub Issue Updated

```
External Action: Issue #42 title changed

1. Periodic sync daemon runs (every 5 min)
2. For each synced task:
   a. Fetch GitHub issue
   b. Compare with last known state
   c. Detect title change
   d. Map to TaskWarrior: description
   e. Call: task abc-123 modify description:"New title"
   f. Update sync state
3. TaskWarrior task updated
```

### Example 3: Conflict (Rare in Single-User)

```
Scenario: Rapid edits on both sides

1. User modifies task description
2. AI agent modifies GitHub title simultaneously
3. Sync engine detects both changed
4. Applies conflict resolution:
   - Last write wins: Compare timestamps
   - Most recent change applied
   - Other change logged
5. Both sides now consistent
```

## Configuration

### GitHub Sync Config
**File:** `~/.task/github-sync.conf`

```bash
# Default repository
GITHUB_DEFAULT_REPO="owner/repo"

# Sync strategy
GITHUB_SYNC_STRATEGY="last_write_wins"  # last_write_wins, github_wins, task_wins, manual

# Sync interval (seconds)
GITHUB_SYNC_INTERVAL=300

# Auto-sync on task modify
GITHUB_AUTO_SYNC=true

# Fields to sync
GITHUB_SYNC_FIELDS="description,status,priority,tags,annotations"

# Conflict notification
GITHUB_NOTIFY_CONFLICTS=true
```

### Per-Task Configuration (UDAs)

```bash
# TaskWarrior UDAs for GitHub sync
uda.githubissue.type=numeric
uda.githubissue.label=GitHub Issue
uda.githubrepo.type=string
uda.githubrepo.label=GitHub Repo
uda.githubsync.type=string
uda.githubsync.label=Sync Enabled
uda.githubsync.values=enabled,disabled
```

## Testing Strategy

### Unit Tests
```bash
tests/
├── test-state-manager.sh
├── test-field-mapper.sh
├── test-conflict-resolver.sh
├── test-github-api.sh
└── test-taskwarrior-api.sh
```

### Integration Tests
```bash
tests/integration/
├── test-pull-sync.sh
├── test-push-sync.sh
├── test-bidirectional-sync.sh
└── test-conflict-resolution.sh
```

### Test Scenarios
1. **Simple Pull**: GitHub issue updated → TaskWarrior task updated
2. **Simple Push**: TaskWarrior task updated → GitHub issue updated
3. **Conflict Resolution**: Both updated → Last write wins applied
4. **New Task**: Create task → Create GitHub issue
5. **Delete Task**: Delete task → Close GitHub issue
6. **Bulk Sync**: Sync 100 tasks → All synced correctly

## Rollout Plan

### Week 1-2: Foundation
- [ ] State management
- [ ] GitHub API wrapper
- [ ] TaskWarrior API wrapper
- [ ] Basic tests

### Week 3: Core Logic
- [ ] Change detection
- [ ] Field mapping
- [ ] Conflict resolution
- [ ] Integration tests

### Week 4: Sync Operations
- [ ] Pull implementation
- [ ] Push implementation
- [ ] Bidirectional sync
- [ ] Hook integration

### Week 5: Polish
- [ ] CLI interface
- [ ] Configuration
- [ ] Documentation
- [ ] User testing

### Week 6: Beta Release
- [ ] Beta user program (5-10 users)
- [ ] Gather feedback
- [ ] Fix bugs
- [ ] Iterate

## Success Metrics

### Technical Metrics
- Sync success rate > 95%
- Average sync latency < 5s
- Conflict rate < 5%
- Zero data loss

### User Metrics
- 10+ active users
- Positive feedback
- Daily usage
- Feature requests

## Risk Mitigation

### Risk 1: Data Loss
**Mitigation:**
- Backup before every sync
- Dry-run mode
- Extensive logging
- Rollback capability

### Risk 2: API Rate Limiting
**Mitigation:**
- Batch operations
- Respect rate limits
- Cache GitHub data
- Queue management

### Risk 3: Conflicts
**Mitigation:**
- Single-user assumption reduces conflicts
- Clear conflict resolution strategy
- Manual resolution option
- Conflict history

### Risk 4: `gh` CLI Dependency
**Mitigation:**
- Check for `gh` on startup
- Clear installation instructions
- Fallback to manual sync
- Document requirements

## Next Steps

1. **Review this plan** - Gather feedback
2. **Create spec** - Formal requirements document
3. **Prototype** - Build minimal version (Week 1-2)
4. **Test** - Validate with real data
5. **Iterate** - Refine based on testing
6. **Beta** - Release to small group
7. **Evaluate** - Decide on full rollout

## Questions for Review

1. **Scope**: Is GitHub-only sufficient for MVP?
2. **Conflict Strategy**: Is "last write wins" acceptable for single-user?
3. **Sync Frequency**: Is 5-minute interval appropriate?
4. **Hook vs Daemon**: Should we use hooks, daemon, or both?
5. **Field Coverage**: Which fields are most important to sync?
6. **Error Handling**: How aggressive should retry logic be?
7. **User Experience**: What CLI commands are most intuitive?

## Conclusion

This plan provides a pragmatic approach to GitHub two-way sync:
- **Focused**: GitHub-only reduces complexity
- **Practical**: Leverages `gh` CLI for simplicity
- **Safe**: Extensive state management and conflict resolution
- **Incremental**: Phased rollout with testing
- **Realistic**: 5-6 week timeline for MVP

The single-user assumption significantly simplifies conflict resolution, making this more feasible than a general multi-user solution.

**Ready to proceed with implementation?**
