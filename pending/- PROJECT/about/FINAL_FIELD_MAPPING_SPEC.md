# Final Field Mapping Specification - Phase 1 MVP

## Approved for Implementation

This document specifies the exact field mappings to be implemented in Phase 1.

---

## Phase 1: Core Bidirectional Mappings

### 1. Description ↔ Title
```yaml
TaskWarrior Field: description
GitHub Field: title
Direction: ↔️ Bidirectional
Priority: CRITICAL

Transformation:
  TW → GH:
    - Direct copy
    - Truncate if > 256 chars
    - Warn user if truncated
  
  GH → TW:
    - Direct copy
    - No length limit in TaskWarrior

Validation:
  - Not empty
  - Max 256 chars for GitHub
  - Strip leading/trailing whitespace

Example:
  TW: description:"Fix login bug"
  GH: title:"Fix login bug"
```

### 2. Status ↔ State
```yaml
TaskWarrior Field: status
GitHub Field: state
Direction: ↔️ Bidirectional
Priority: CRITICAL

Transformation:
  TW → GH:
    pending   → OPEN
    started   → OPEN
    waiting   → OPEN
    recurring → OPEN
    completed → CLOSED
    deleted   → CLOSED
  
  GH → TW:
    OPEN      → pending (default)
    OPEN      → started (if task.start exists)
    CLOSED    → completed (default)
    CLOSED    → deleted (if stateReason="NOT_PLANNED")

Validation:
  - Must be valid TaskWarrior status
  - Must be valid GitHub state (OPEN/CLOSED)

Example:
  TW: status:completed
  GH: state:CLOSED

Notes:
  - Preserve task.start when pulling OPEN
  - Use stateReason to distinguish completed vs deleted
```

### 3. Priority ↔ Labels (priority:*)
```yaml
TaskWarrior Field: priority
GitHub Field: labels (with prefix "priority:")
Direction: ↔️ Bidirectional
Priority: HIGH

Transformation:
  TW → GH:
    H         → priority:high
    M         → priority:medium
    L         → priority:low
    (empty)   → (remove priority labels)
  
  GH → TW:
    priority:high    → H
    priority:medium  → M
    priority:low     → L
    (no label)       → (empty)

Validation:
  - Only one priority label at a time
  - Remove old priority label when changing
  - Case-insensitive matching

Example:
  TW: priority:H
  GH: labels:[priority:high]

Implementation:
  - Search for labels matching "priority:*"
  - Remove all priority labels before adding new one
  - Create label if doesn't exist
```

### 4. Tags ↔ Labels
```yaml
TaskWarrior Field: tags
GitHub Field: labels
Direction: ↔️ Bidirectional
Priority: HIGH

Transformation:
  TW → GH:
    - Convert each tag to label
    - Exclude system tags (ACTIVE, READY, etc.)
    - Exclude sync metadata tags (sync:*)
    - Create labels if don't exist
    - Preserve label colors from GitHub
  
  GH → TW:
    - Convert each label to tag
    - Exclude priority labels (priority:*)
    - Exclude sync metadata labels (sync:*)
    - Lowercase for consistency

Validation:
  - Label names: alphanumeric, hyphens, underscores
  - Max 50 chars per label
  - No spaces (convert to hyphens)

Example:
  TW: tags:bug,urgent,frontend
  GH: labels:[bug, urgent, frontend]

Exclusions:
  TW System Tags (don't sync):
    - ACTIVE, READY, PENDING, COMPLETED, DELETED
    - WAITING, RECURRING, PARENT, CHILD
    - BLOCKED, UNBLOCKED, OVERDUE, TODAY
    - TOMORROW, WEEK, MONTH, YEAR
  
  Sync Metadata (don't sync):
    - sync:enabled, sync:disabled
    - sync:conflict, sync:error
    - priority:* (handled separately)

Implementation:
  - Filter tags before syncing
  - Sanitize tag names for GitHub
  - Track which labels were created by sync
```

### 5. Annotations ↔ Comments
```yaml
TaskWarrior Field: annotations
GitHub Field: comments
Direction: ↔️ Bidirectional (append-only)
Priority: HIGH

Transformation:
  TW → GH:
    - New annotations → new comments
    - Prefix: "[TaskWarrior] "
    - Include timestamp
    - Track which annotations already synced
  
  GH → TW:
    - New comments → new annotations
    - Prefix: "[GitHub @username] "
    - Include timestamp
    - Track which comments already synced

Validation:
  - Not empty
  - Max 65536 chars per comment (GitHub limit)
  - Truncate if needed

Example:
  TW: annotation:"Fixed the authentication issue"
  GH: comment:"[TaskWarrior] Fixed the authentication issue"

Sync Strategy:
  - Append-only (never delete/edit existing)
  - Track sync state to avoid duplicates
  - Store last synced annotation/comment count
  - Only sync new items since last sync

State Tracking:
  {
    "last_annotation_count": 3,
    "last_comment_count": 5,
    "synced_annotations": ["hash1", "hash2", "hash3"],
    "synced_comments": [123, 456, 789]
  }

Implementation:
  - Hash annotation text to track uniqueness
  - Use comment ID to track GitHub comments
  - Compare counts to detect new items
  - Sync only delta since last sync

Notes:
  - Bidirectional can create echo if not careful
  - Use prefixes to identify source
  - Consider rate limiting for bulk comments
```

---

## Phase 1: Pull-Only Metadata

### 6. Issue Number → UDA
```yaml
TaskWarrior Field: githubissue (UDA)
GitHub Field: number
Direction: 📥 Pull-Only
Priority: CRITICAL

Transformation:
  GH → TW:
    - Store issue number as integer
    - Used for linking back to GitHub

Example:
  TW: githubissue:123
  GH: number:123

UDA Definition:
  uda.githubissue.type=numeric
  uda.githubissue.label=GitHub Issue
```

### 7. Issue URL → UDA
```yaml
TaskWarrior Field: githuburl (UDA)
GitHub Field: url
Direction: 📥 Pull-Only
Priority: HIGH

Transformation:
  GH → TW:
    - Store full URL
    - Used for opening in browser

Example:
  TW: githuburl:"https://github.com/owner/repo/issues/123"
  GH: url:"https://github.com/owner/repo/issues/123"

UDA Definition:
  uda.githuburl.type=string
  uda.githuburl.label=GitHub URL
```

### 8. Repository → UDA
```yaml
TaskWarrior Field: githubrepo (UDA)
GitHub Field: (derived from URL)
Direction: 📥 Pull-Only
Priority: HIGH

Transformation:
  GH → TW:
    - Extract "owner/repo" from URL
    - Store for multi-repo support

Example:
  TW: githubrepo:"owner/repo"
  GH: (derived from context)

UDA Definition:
  uda.githubrepo.type=string
  uda.githubrepo.label=GitHub Repo
```

### 9. Author → UDA
```yaml
TaskWarrior Field: githubauthor (UDA)
GitHub Field: author.login
Direction: 📥 Pull-Only
Priority: MEDIUM

Transformation:
  GH → TW:
    - Store author username

Example:
  TW: githubauthor:"octocat"
  GH: author.login:"octocat"

UDA Definition:
  uda.githubauthor.type=string
  uda.githubauthor.label=GitHub Author
```

### 10. Created Date → Entry
```yaml
TaskWarrior Field: entry
GitHub Field: createdAt
Direction: 📥 Pull-Only (initial sync only)
Priority: MEDIUM

Transformation:
  GH → TW:
    - Use GitHub creation date as task entry
    - Only on first sync (don't overwrite)
    - Convert ISO 8601 to TaskWarrior format

Example:
  TW: entry:20240115T100000Z
  GH: createdAt:"2024-01-15T10:00:00Z"

Notes:
  - Only set during initial sync
  - Preserves original creation time
```

### 11. Closed Date → End
```yaml
TaskWarrior Field: end
GitHub Field: closedAt
Direction: 📥 Pull-Only
Priority: MEDIUM

Transformation:
  GH → TW:
    - Set end date when issue closed
    - Only if task status becomes completed
    - Convert ISO 8601 to TaskWarrior format

Example:
  TW: end:20240115T150000Z
  GH: closedAt:"2024-01-15T15:00:00Z"

Notes:
  - Only set when status changes to completed
  - Preserves completion time
```

### 12. Updated Date → Sync State
```yaml
TaskWarrior Field: modified (comparison only)
GitHub Field: updatedAt
Direction: 📥 Pull-Only (for change detection)
Priority: CRITICAL

Transformation:
  GH → TW:
    - Store in sync state for comparison
    - Don't overwrite TaskWarrior's modified field
    - Used for detecting changes

Example:
  Sync State: last_github_updated:"2024-01-15T10:30:00Z"
  GH: updatedAt:"2024-01-15T10:30:00Z"

Notes:
  - Used for change detection
  - Not directly synced to task
  - Stored in sync state database
```

---

## Required UDAs

### UDA Definitions for .taskrc
```bash
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
```

---

## Sync State Schema

### State Database: `~/.task/github-sync/state.json`
```json
{
  "task-uuid": {
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

---

## Field Priority Summary

### Critical (Must Work)
1. ✅ description ↔ title
2. ✅ status ↔ state
3. ✅ githubissue ← number
4. ✅ modified ↔ updatedAt (for change detection)

### High (Core Features)
5. ✅ priority ↔ labels (priority:*)
6. ✅ tags ↔ labels
7. ✅ annotations ↔ comments
8. ✅ githuburl ← url
9. ✅ githubrepo ← (derived)

### Medium (Nice to Have)
10. ✅ githubauthor ← author
11. ✅ entry ← createdAt
12. ✅ end ← closedAt

---

## Implementation Order

### Week 1-2: Foundation
1. State management system
2. UDA definitions
3. Basic field mapper (description, status)
4. GitHub API wrapper (gh CLI)
5. TaskWarrior API wrapper

### Week 3: Core Fields
6. Priority mapping (with labels)
7. Tags mapping (with filtering)
8. Metadata fields (issue #, URL, repo, author)
9. Date fields (entry, end)

### Week 4: Annotations
10. Annotation → Comment (push)
11. Comment → Annotation (pull)
12. Duplicate detection
13. Sync state tracking

### Week 5: Polish
14. Error handling for each field
15. Validation
16. Testing
17. Documentation

---

## Validation Rules

### Per-Field Validation

```yaml
description/title:
  - Not empty
  - Max 256 chars (GitHub)
  - Strip whitespace

status/state:
  - Valid TaskWarrior status
  - Valid GitHub state

priority:
  - H, M, L, or empty
  - Only one priority label

tags/labels:
  - Alphanumeric, hyphens, underscores
  - Max 50 chars per label
  - No spaces

annotations/comments:
  - Not empty
  - Max 65536 chars (GitHub)
```

---

## Error Handling

### Field-Specific Errors

Each field has dedicated error handler:
- `handle_title_error()` - Title validation
- `handle_state_error()` - State validation
- `handle_label_error()` - Label validation
- `handle_comment_error()` - Comment validation

See ERROR_HANDLING_DESIGN.md for details.

---

## Testing Requirements

### Unit Tests (Per Field)
- Test each transformation (TW → GH)
- Test each transformation (GH → TW)
- Test validation rules
- Test error cases

### Integration Tests
- Test full sync cycle
- Test conflict resolution
- Test annotation sync
- Test with real GitHub repo

---

## Configuration

### Profile-Level Config: `~/.task/github-sync.conf`
```bash
# Core mappings (always enabled in Phase 1)
SYNC_DESCRIPTION=true
SYNC_STATUS=true
SYNC_PRIORITY=true
SYNC_TAGS=true
SYNC_ANNOTATIONS=true

# Metadata (always enabled)
SYNC_METADATA=true

# Tag filtering
SYNC_EXCLUDE_TAGS="ACTIVE,READY,PENDING,COMPLETED,DELETED,WAITING,RECURRING,BLOCKED,OVERDUE,TODAY,TOMORROW,WEEK,MONTH,YEAR,sync:*"

# Label filtering
SYNC_EXCLUDE_LABELS="sync:*"

# Annotation sync settings
SYNC_ANNOTATION_PREFIX="[TaskWarrior]"
SYNC_COMMENT_PREFIX="[GitHub"
```

---

## Summary

### Phase 1 MVP Includes:

**Bidirectional (5 fields):**
1. description ↔ title
2. status ↔ state
3. priority ↔ labels (priority:*)
4. tags ↔ labels
5. annotations ↔ comments

**Pull-Only (7 fields):**
6. githubissue ← number
7. githuburl ← url
8. githubrepo ← (derived)
9. githubauthor ← author
10. entry ← createdAt
11. end ← closedAt
12. modified ← updatedAt (for change detection)

**Total: 12 field mappings in Phase 1**

---

## Approval Status

✅ **APPROVED FOR IMPLEMENTATION**

- Annotations included in Phase 1
- All field mappings reviewed
- Ready to begin coding

**Next Step:** Begin Week 1 implementation (Foundation)
