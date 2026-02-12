# Two-Way Issue Sync Service - Exploration

**Status**: Experimental Concept (NOT IMPLEMENTED)

This document explores the design and implementation of a bidirectional sync service that would allow TaskWarrior changes to propagate back to external issue trackers (GitHub, Jira, etc.).

## Executive Summary

A two-way sync service would extend the current one-way bugwarrior integration to support:
- Pushing TaskWarrior changes back to external services
- Conflict detection and resolution
- Real-time or scheduled bidirectional synchronization
- Field mapping between TaskWarrior and external services

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    External Services                         │
│  (GitHub, GitLab, Jira, Trello, etc.)                       │
└────────────┬────────────────────────────────┬────────────────┘
             │                                │
             │ Pull (Read)                    │ Push (Write)
             │                                │
             ▼                                ▲
┌─────────────────────────────────────────────────────────────┐
│              Sync Engine (New Component)                     │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Change    │  │   Conflict   │  │    Field     │       │
│  │  Detector   │  │  Resolver    │  │   Mapper     │       │
│  └─────────────┘  └──────────────┘  └──────────────┘       │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │    State    │  │     Queue    │  │   Webhook    │       │
│  │  Database   │  │   Manager    │  │   Handler    │       │
│  └─────────────┘  └──────────────┘  └──────────────┘       │
└────────────┬────────────────────────────────┬────────────────┘
             │                                │
             │ Read                           │ Write
             │                                │
             ▼                                ▲
┌─────────────────────────────────────────────────────────────┐
│                      TaskWarrior                             │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │    Tasks    │  │     Hooks    │  │     UDAs     │       │
│  └─────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Change Detector
Monitors TaskWarrior for modifications and determines what changed.

**Responsibilities:**
- Hook into TaskWarrior's on-modify hook
- Detect field changes (status, description, priority, etc.)
- Identify which external service the task belongs to
- Queue changes for processing

### 2. Conflict Resolver
Handles simultaneous modifications from both sides.

**Strategies:**
- **Last Write Wins**: Most recent change takes precedence
- **External Authoritative**: External service always wins
- **Manual Resolution**: Prompt user for conflicts
- **Field-Level Merge**: Merge non-conflicting fields

### 3. Field Mapper
Translates between TaskWarrior and external service data models.

**Mappings:**
- TaskWarrior status ↔ GitHub issue state
- TaskWarrior priority ↔ Jira priority
- TaskWarrior tags ↔ GitHub labels
- TaskWarrior annotations ↔ Issue comments

### 4. State Database
Tracks sync state for each task.

**Stored Data:**
- Last sync timestamp
- Last known state (both sides)
- Sync direction (pull/push)
- Conflict history
- Field checksums

### 5. Queue Manager
Manages async operations and retries.

**Features:**
- Batch operations
- Rate limiting
- Retry logic with exponential backoff
- Priority queuing
- Dead letter queue for failures

### 6. Webhook Handler
Receives real-time updates from external services.

**Capabilities:**
- GitHub webhooks
- GitLab webhooks
- Jira webhooks
- Webhook signature verification
- Event filtering

## Data Flow

### Pull Flow (External → TaskWarrior)
```
1. External service changes issue
2. Webhook notifies sync engine (or scheduled poll)
3. Sync engine fetches updated issue
4. Field mapper converts to TaskWarrior format
5. State database checks for conflicts
6. If no conflict: Update TaskWarrior task
7. If conflict: Invoke conflict resolver
8. Update state database with new state
```

### Push Flow (TaskWarrior → External)
```
1. User modifies task in TaskWarrior
2. on-modify hook triggers change detector
3. Change detector identifies modified fields
4. Queue manager adds to push queue
5. Field mapper converts to external format
6. State database checks for conflicts
7. If no conflict: Push to external service API
8. If conflict: Invoke conflict resolver
9. Update state database with new state
```

## Conflict Resolution Strategies

### Strategy 1: Last Write Wins (Simple)
```python
def resolve_conflict(local_task, remote_issue, state):
    if local_task.modified > remote_issue.updated:
        return "push"  # Push local changes
    else:
        return "pull"  # Pull remote changes
```

**Pros:** Simple, deterministic
**Cons:** Can lose data

### Strategy 2: Field-Level Merge (Smart)
```python
def resolve_conflict(local_task, remote_issue, state):
    merged = {}
    
    for field in ALL_FIELDS:
        local_val = getattr(local_task, field)
        remote_val = getattr(remote_issue, field)
        last_known = state.get_field(field)
        
        if local_val == remote_val:
            merged[field] = local_val  # No conflict
        elif local_val == last_known:
            merged[field] = remote_val  # Remote changed
        elif remote_val == last_known:
            merged[field] = local_val  # Local changed
        else:
            # Both changed - need resolution
            merged[field] = resolve_field_conflict(
                field, local_val, remote_val
            )
    
    return merged
```

**Pros:** Preserves more changes
**Cons:** Complex, may still have conflicts

### Strategy 3: Manual Resolution (Safe)
```python
def resolve_conflict(local_task, remote_issue, state):
    conflicts = detect_conflicts(local_task, remote_issue, state)
    
    if conflicts:
        # Present to user
        choice = prompt_user(
            f"Conflict detected for task {local_task.uuid}:\n"
            f"Local: {conflicts['local']}\n"
            f"Remote: {conflicts['remote']}\n"
            f"Choose: [L]ocal, [R]emote, [M]erge, [S]kip"
        )
        
        return apply_user_choice(choice, local_task, remote_issue)
    
    return auto_merge(local_task, remote_issue)
```

**Pros:** No data loss, user control
**Cons:** Requires user interaction

## Field Mapping Examples

### GitHub Issue ↔ TaskWarrior Task

```yaml
# Bidirectional field mappings
mappings:
  github:
    # Simple 1:1 mappings
    title: description
    state: status
    
    # Complex mappings with transformation
    labels:
      to_taskwarrior: tags
      transform: "label.name.lower()"
    
    priority:
      to_taskwarrior: priority
      transform:
        high: H
        medium: M
        low: L
    
    # Read-only fields (pull only)
    number: githubid
    html_url: githuburl
    created_at: githubcreated
    
    # Write-only fields (push only)
    assignees:
      from_taskwarrior: githubassignee
      transform: "[{'login': value}]"
    
    # Computed fields
    body:
      to_taskwarrior: annotations
      transform: "convert_markdown_to_annotations()"
      from_taskwarrior: annotations
      transform: "convert_annotations_to_markdown()"
```

### Jira Issue ↔ TaskWarrior Task

```yaml
mappings:
  jira:
    summary: description
    
    status:
      to_taskwarrior: status
      transform:
        "To Do": pending
        "In Progress": started
        "Done": completed
      from_taskwarrior:
        pending: "To Do"
        started: "In Progress"
        completed: "Done"
    
    priority:
      to_taskwarrior: priority
      transform:
        Highest: H
        High: H
        Medium: M
        Low: L
        Lowest: L
    
    labels: tags
    
    assignee:
      to_taskwarrior: jiraassignee
      from_taskwarrior: jiraassignee
      transform: "{'accountId': lookup_jira_user(value)}"
```

## State Database Schema

```sql
-- Sync state for each task
CREATE TABLE sync_state (
    task_uuid TEXT PRIMARY KEY,
    service_type TEXT NOT NULL,  -- github, jira, etc.
    service_id TEXT NOT NULL,    -- issue number, ticket key
    
    -- Timestamps
    last_sync_time TIMESTAMP NOT NULL,
    last_pull_time TIMESTAMP,
    last_push_time TIMESTAMP,
    
    -- State snapshots (JSON)
    last_local_state TEXT,       -- TaskWarrior state at last sync
    last_remote_state TEXT,      -- External state at last sync
    
    -- Checksums for quick comparison
    local_checksum TEXT,
    remote_checksum TEXT,
    
    -- Conflict tracking
    conflict_count INTEGER DEFAULT 0,
    last_conflict_time TIMESTAMP,
    conflict_resolution TEXT,    -- how last conflict was resolved
    
    -- Metadata
    sync_direction TEXT,         -- pull, push, bidirectional
    sync_enabled BOOLEAN DEFAULT TRUE,
    
    UNIQUE(service_type, service_id)
);

-- Change queue for async processing
CREATE TABLE change_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_uuid TEXT NOT NULL,
    change_type TEXT NOT NULL,   -- create, update, delete
    direction TEXT NOT NULL,      -- pull, push
    
    -- Change details (JSON)
    changes TEXT NOT NULL,        -- what changed
    
    -- Queue management
    status TEXT DEFAULT 'pending', -- pending, processing, completed, failed
    priority INTEGER DEFAULT 5,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    scheduled_at TIMESTAMP,
    processed_at TIMESTAMP,
    
    -- Error tracking
    error_message TEXT,
    
    FOREIGN KEY (task_uuid) REFERENCES sync_state(task_uuid)
);

-- Conflict history
CREATE TABLE conflict_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_uuid TEXT NOT NULL,
    
    -- Conflict details
    conflict_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    conflict_fields TEXT,        -- JSON array of conflicting fields
    local_values TEXT,           -- JSON of local values
    remote_values TEXT,          -- JSON of remote values
    
    -- Resolution
    resolution_strategy TEXT,    -- last_write_wins, manual, merge
    resolution_time TIMESTAMP,
    resolved_values TEXT,        -- JSON of final values
    
    FOREIGN KEY (task_uuid) REFERENCES sync_state(task_uuid)
);
```

## Implementation Phases

### Phase 1: Foundation (MVP)
- [ ] State database setup
- [ ] Change detection via TaskWarrior hooks
- [ ] Basic field mapping (status, description only)
- [ ] Simple conflict resolution (last write wins)
- [ ] GitHub push support only
- [ ] Manual sync trigger (`i push`)

### Phase 2: Core Features
- [ ] Automatic sync daemon
- [ ] Full field mapping for GitHub
- [ ] Queue management with retries
- [ ] Conflict detection and logging
- [ ] GitLab support
- [ ] Sync status reporting

### Phase 3: Advanced Features
- [ ] Webhook support for real-time sync
- [ ] Field-level conflict resolution
- [ ] Jira support
- [ ] Manual conflict resolution UI
- [ ] Sync history and rollback
- [ ] Performance optimization

### Phase 4: Production Ready
- [ ] Comprehensive error handling
- [ ] Monitoring and alerting
- [ ] Multi-service support (25+ services)
- [ ] Configuration UI
- [ ] Documentation and examples
- [ ] Test coverage

## Technical Challenges

### 1. Race Conditions
**Problem:** User modifies task while sync is in progress
**Solution:** 
- Lock tasks during sync
- Use optimistic locking with version numbers
- Queue changes that occur during sync

### 2. API Rate Limiting
**Problem:** External services limit API calls
**Solution:**
- Batch operations
- Implement exponential backoff
- Cache frequently accessed data
- Use webhooks instead of polling

### 3. Data Loss Prevention
**Problem:** Conflicts could cause data loss
**Solution:**
- Always backup before applying changes
- Maintain conflict history
- Allow rollback to previous state
- Require explicit user confirmation for destructive operations

### 4. Partial Failures
**Problem:** Push succeeds but state update fails
**Solution:**
- Use transactions where possible
- Implement idempotent operations
- Maintain operation log for recovery
- Implement reconciliation process

### 5. Schema Evolution
**Problem:** External services change their APIs
**Solution:**
- Version field mappings
- Graceful degradation
- API version detection
- Migration tools

## Security Considerations

### 1. Credential Management
- Store write tokens separately from read tokens
- Use more restrictive permissions for write operations
- Implement token rotation
- Audit all write operations

### 2. Data Validation
- Validate all data before pushing
- Sanitize user input
- Prevent injection attacks
- Rate limit operations per user

### 3. Webhook Security
- Verify webhook signatures
- Use HTTPS only
- Implement replay attack prevention
- Whitelist webhook sources

## Performance Considerations

### 1. Sync Frequency
- Real-time: Immediate but high overhead
- Scheduled: Lower overhead but delayed
- Hybrid: Real-time for critical changes, scheduled for others

### 2. Batch Operations
- Group multiple changes into single API call
- Reduce network overhead
- Improve throughput

### 3. Caching
- Cache external service data
- Reduce API calls
- Implement cache invalidation strategy

### 4. Indexing
- Index state database properly
- Optimize queries
- Use connection pooling

## User Experience

### Configuration
```bash
# Enable two-way sync for a service
i config github --sync bidirectional

# Configure conflict resolution strategy
i config github --conflict-strategy manual

# Set sync frequency
i config github --sync-interval 5m

# Enable specific field syncing
i config github --sync-fields status,priority,tags
```

### Monitoring
```bash
# View sync status
i sync status

# View recent syncs
i sync history

# View conflicts
i sync conflicts

# Resolve pending conflict
i sync resolve <task-uuid>
```

### Manual Operations
```bash
# Push specific task
i push <task-uuid>

# Pull specific task
i pull <task-uuid>

# Force sync (ignore conflicts)
i sync force <task-uuid>

# Dry run
i push --dry-run
```

## Comparison with Existing Solutions

### vs. Bugwarrior (Current)
**Pros:**
- Bidirectional sync
- Real-time updates
- Conflict resolution

**Cons:**
- Much more complex
- Higher risk of data corruption
- Requires write permissions
- More maintenance overhead

### vs. Commercial Tools (Unito, Zapier)
**Pros:**
- Open source
- Integrated with Workwarrior
- Customizable
- No subscription fees

**Cons:**
- More setup required
- Less polished UI
- Fewer pre-built integrations
- Self-hosted maintenance

## Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Data loss from conflicts | High | Medium | Backup before sync, conflict history |
| API rate limiting | Medium | High | Batch operations, caching |
| Service API changes | Medium | Medium | Version mappings, graceful degradation |
| Security vulnerabilities | High | Low | Audit logs, token management |
| Performance degradation | Medium | Medium | Optimize queries, async processing |
| User confusion | Low | High | Clear documentation, dry-run mode |

## Decision: Should We Build This?

### Arguments FOR:
1. **User Demand**: Many users want bidirectional sync
2. **Competitive Feature**: Commercial tools offer this
3. **Workflow Improvement**: Reduces context switching
4. **Technical Challenge**: Interesting problem to solve

### Arguments AGAINST:
1. **Complexity**: Significantly more complex than one-way
2. **Maintenance Burden**: Ongoing maintenance for 25+ services
3. **Risk**: Higher risk of data corruption
4. **Scope Creep**: Could become a full-time project
5. **Alternative Solutions**: Users can use service CLIs/APIs

### Recommendation

**Start with a LIMITED PROTOTYPE:**
1. Implement for GitHub only
2. Support only status and description fields
3. Use simple "last write wins" conflict resolution
4. Manual sync trigger only (no daemon)
5. Extensive logging and dry-run mode

**Success Criteria:**
- Zero data loss in testing
- Positive user feedback
- Manageable maintenance burden
- Clear use cases

**If successful, expand to:**
- More services (GitLab, Jira)
- More fields
- Better conflict resolution
- Automatic sync

**If unsuccessful:**
- Document limitations
- Provide alternative workflows
- Focus on improving one-way sync
- Build helper tools for manual updates

## Next Steps

1. **Gather Requirements**: Survey users about specific needs
2. **Prototype**: Build minimal GitHub-only version
3. **Test**: Extensive testing with real data
4. **Evaluate**: Assess complexity vs. value
5. **Decide**: Go/no-go decision based on prototype results

## Conclusion

A two-way sync service is **technically feasible** but **significantly complex**. The key challenges are conflict resolution, data integrity, and ongoing maintenance. A phased approach starting with a limited prototype is recommended to validate the concept before committing to full implementation.

The current one-way sync with manual updates via service APIs/CLIs may be sufficient for most users, but a well-designed two-way sync could be a compelling feature for power users.

---

**Status**: Exploration complete - awaiting decision on prototype development
