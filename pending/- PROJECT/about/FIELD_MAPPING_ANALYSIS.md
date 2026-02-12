# TaskWarrior ↔ GitHub Issues: Complete Field Mapping Analysis

## Overview

This document analyzes ALL possible field mappings between TaskWarrior and GitHub Issues for the two-way sync implementation.

## Field Categories

### ✅ Direct Mappings (Bidirectional)
Fields that map cleanly between both systems

### ⚠️ Partial Mappings (Bidirectional with Transformation)
Fields that require transformation but can sync both ways

### 📥 Pull-Only Mappings (GitHub → TaskWarrior)
Fields that only make sense to pull from GitHub

### 📤 Push-Only Mappings (TaskWarrior → GitHub)
Fields that only make sense to push to GitHub

### ❌ No Mapping
Fields that cannot or should not be synced

---

## Complete Field Inventory

### GitHub Issue Fields (from `gh issue view --json`)

```json
{
  "assignees": [],           // Array of user objects
  "author": {},              // User object
  "body": "",                // Markdown text
  "closed": false,           // Boolean
  "closedAt": null,          // ISO timestamp
  "comments": [],            // Array of comment objects
  "createdAt": "",           // ISO timestamp
  "id": "",                  // GitHub internal ID
  "isPinned": false,         // Boolean
  "labels": [],              // Array of label objects
  "milestone": {},           // Milestone object
  "number": 123,             // Issue number
  "projectCards": [],        // Array of project card objects
  "projectItems": [],        // Array of project item objects
  "reactionGroups": [],      // Array of reaction objects
  "state": "OPEN",           // OPEN or CLOSED
  "stateReason": "",         // Reason for state change
  "title": "",               // Issue title
  "updatedAt": "",           // ISO timestamp
  "url": ""                  // Issue URL
}
```

### TaskWarrior Task Fields (Core)

```
UUID Fields:
  uuid                       // Unique identifier

Description Fields:
  description                // Task description

Status Fields:
  status                     // pending, completed, deleted, waiting, recurring

Priority Fields:
  priority                   // H, M, L, or empty

Project Fields:
  project                    // Project name (hierarchical)

Tags Fields:
  tags                       // Array of tags

Date Fields:
  entry                      // Creation timestamp
  modified                   // Last modification timestamp
  start                      // Start timestamp (when started)
  end                        // Completion timestamp
  due                        // Due date
  wait                       // Wait until date
  scheduled                  // Scheduled date
  until                      // Expiration date

Dependency Fields:
  depends                    // Array of dependent task UUIDs

Urgency Fields:
  urgency                    // Calculated urgency score

Annotation Fields:
  annotations                // Array of annotation objects
                            // Each: {entry: timestamp, description: text}

Recurrence Fields:
  recur                      // Recurrence pattern
  parent                     // Parent task UUID (for recurring)
  imask                      // Recurrence mask

User Defined Attributes (UDAs):
  (Custom fields defined by user)
```

---

## Proposed Field Mappings

### Category 1: ✅ Direct Bidirectional Mappings

#### 1.1 Title/Description
```yaml
Mapping:
  TaskWarrior: description
  GitHub: title
  
Direction: ↔️ Bidirectional

Transformation: None (direct string copy)

Example:
  TW: "Fix login bug"
  GH: "Fix login bug"

Notes:
  - Most fundamental mapping
  - No transformation needed
  - Character limit: GitHub title max 256 chars
```

#### 1.2 Status/State
```yaml
Mapping:
  TaskWarrior: status
  GitHub: state
  
Direction: ↔️ Bidirectional

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
    CLOSED    → deleted (if stateReason = "NOT_PLANNED")

Example:
  TW: status:completed
  GH: state:CLOSED

Notes:
  - Core functionality
  - Handle edge cases (waiting, recurring)
  - Consider stateReason for better mapping
```

#### 1.3 Tags/Labels
```yaml
Mapping:
  TaskWarrior: tags
  GitHub: labels
  
Direction: ↔️ Bidirectional

Transformation:
  TW → GH:
    - Filter out system tags (ACTIVE, READY, etc.)
    - Create labels if they don't exist
    - Preserve label colors from GitHub
  
  GH → TW:
    - Convert all labels to tags
    - Exclude special labels (priority:*, sync:*)
    - Lowercase for consistency

Example:
  TW: tags:bug,urgent,frontend
  GH: labels:[bug, urgent, frontend]

Notes:
  - Exclude system tags: ACTIVE, READY, PENDING, COMPLETED, DELETED, etc.
  - Exclude sync metadata tags: sync:enabled, sync:conflict, etc.
  - GitHub labels are case-sensitive, TW tags typically lowercase
```

---

### Category 2: ⚠️ Partial Bidirectional Mappings

#### 2.1 Priority/Labels (priority:*)
```yaml
Mapping:
  TaskWarrior: priority
  GitHub: labels (with prefix "priority:")
  
Direction: ↔️ Bidirectional

Transformation:
  TW → GH:
    H → priority:high
    M → priority:medium
    L → priority:low
    (empty) → (no priority label)
  
  GH → TW:
    priority:high   → H
    priority:medium → M
    priority:low    → L
    (no label)      → (empty)

Example:
  TW: priority:H
  GH: labels:[priority:high]

Notes:
  - Use label prefix to avoid conflicts
  - Only one priority label at a time
  - Remove old priority label when changing
```

#### 2.2 Annotations/Comments
```yaml
Mapping:
  TaskWarrior: annotations
  GitHub: comments
  
Direction: ⚠️ Partial Bidirectional (with caveats)

Transformation:
  TW → GH:
    - New annotations → new comments
    - Track which annotations already synced
    - Prefix with "[TaskWarrior]" for identification
  
  GH → TW:
    - New comments → new annotations
    - Track which comments already synced
    - Prefix with "[GitHub @username]" for identification
    - Include timestamp

Example:
  TW: annotation:"Fixed the issue"
  GH: comment:"[TaskWarrior] Fixed the issue"

Notes:
  - Append-only (don't delete/edit existing)
  - Track sync state to avoid duplicates
  - Consider sync direction preference
  - May want to make this opt-in due to verbosity

Recommendation: Start with PULL-ONLY, add push later
```

#### 2.3 Project/Milestone
```yaml
Mapping:
  TaskWarrior: project
  GitHub: milestone
  
Direction: ⚠️ Partial Bidirectional (with configuration)

Transformation:
  TW → GH:
    - Map project name to milestone title
    - Create milestone if doesn't exist (optional)
    - Handle hierarchical projects (use top-level)
  
  GH → TW:
    - Map milestone title to project name
    - Preserve existing project hierarchy

Example:
  TW: project:myapp.backend.auth
  GH: milestone:"myapp"

Notes:
  - TaskWarrior projects are hierarchical (dot-separated)
  - GitHub milestones are flat
  - May want to use only top-level project
  - Consider making this opt-in

Recommendation: Start with PULL-ONLY
```

#### 2.4 Due Date
```yaml
Mapping:
  TaskWarrior: due
  GitHub: milestone.dueOn (if milestone exists)
  
Direction: ⚠️ Partial (GitHub milestone due date only)

Transformation:
  TW → GH:
    - Not directly supported (GitHub issues don't have due dates)
    - Could use milestone due date if task has milestone
    - Could use label like "due:2024-01-15"
  
  GH → TW:
    - Use milestone.dueOn if milestone assigned
    - Parse "due:YYYY-MM-DD" labels if present

Example:
  TW: due:2024-01-15
  GH: milestone.dueOn:2024-01-15 OR label:"due:2024-01-15"

Notes:
  - GitHub issues don't have native due dates
  - Milestone due dates are per-milestone, not per-issue
  - Label-based approach more flexible but non-standard

Recommendation: Start with PULL-ONLY from milestone, consider label-based push later
```

---

### Category 3: 📥 Pull-Only Mappings (GitHub → TaskWarrior)

#### 3.1 Issue Number → UDA
```yaml
Mapping:
  TaskWarrior: githubissue (UDA)
  GitHub: number
  
Direction: 📥 Pull-Only

Transformation:
  GH → TW:
    - Store issue number in UDA
    - Used for linking back to GitHub

Example:
  TW: githubissue:123
  GH: number:123

Notes:
  - Essential for sync tracking
  - Never push (GitHub assigns numbers)
```

#### 3.2 Issue URL → UDA
```yaml
Mapping:
  TaskWarrior: githuburl (UDA)
  GitHub: url
  
Direction: 📥 Pull-Only

Transformation:
  GH → TW:
    - Store full URL for easy access

Example:
  TW: githuburl:"https://github.com/owner/repo/issues/123"
  GH: url:"https://github.com/owner/repo/issues/123"

Notes:
  - Convenience for opening in browser
  - Never push (GitHub generates URLs)
```

#### 3.3 Repository → UDA
```yaml
Mapping:
  TaskWarrior: githubrepo (UDA)
  GitHub: (derived from URL)
  
Direction: 📥 Pull-Only

Transformation:
  GH → TW:
    - Extract "owner/repo" from URL
    - Store for multi-repo support

Example:
  TW: githubrepo:"owner/repo"
  GH: (derived from context)

Notes:
  - Needed for multi-repo scenarios
  - Never push (context-dependent)
```

#### 3.4 Author → UDA
```yaml
Mapping:
  TaskWarrior: githubauthor (UDA)
  GitHub: author.login
  
Direction: 📥 Pull-Only

Transformation:
  GH → TW:
    - Store author username

Example:
  TW: githubauthor:"octocat"
  GH: author.login:"octocat"

Notes:
  - Useful for filtering/reporting
  - Never push (GitHub tracks authorship)
```

#### 3.5 Created Date → Entry
```yaml
Mapping:
  TaskWarrior: entry
  GitHub: createdAt
  
Direction: 📥 Pull-Only (on initial sync)

Transformation:
  GH → TW:
    - Use GitHub creation date as task entry date
    - Only on first sync (don't overwrite)

Example:
  TW: entry:2024-01-15T10:00:00Z
  GH: createdAt:2024-01-15T10:00:00Z

Notes:
  - Preserves original creation time
  - Only set once during initial sync
```

#### 3.6 Updated Date → Modified
```yaml
Mapping:
  TaskWarrior: modified
  GitHub: updatedAt
  
Direction: 📥 Pull-Only (for comparison)

Transformation:
  GH → TW:
    - Used for change detection
    - Don't directly set (TaskWarrior manages this)
    - Store in sync state for comparison

Example:
  Sync State: last_github_updated:2024-01-15T10:30:00Z
  GH: updatedAt:2024-01-15T10:30:00Z

Notes:
  - Used for detecting changes
  - Don't overwrite TaskWarrior's modified field
```

#### 3.7 Assignees → UDA
```yaml
Mapping:
  TaskWarrior: githubassignees (UDA)
  GitHub: assignees[].login
  
Direction: 📥 Pull-Only (for now)

Transformation:
  GH → TW:
    - Store comma-separated list of usernames
    - Could map to tags like "assigned:username"

Example:
  TW: githubassignees:"alice,bob"
  GH: assignees:[{login:"alice"}, {login:"bob"}]

Notes:
  - TaskWarrior doesn't have native assignee field
  - Could use tags or UDA
  - Push support could be added later

Recommendation: Pull-only initially, consider push later
```

#### 3.8 Body → Annotation (Initial)
```yaml
Mapping:
  TaskWarrior: annotation (first one)
  GitHub: body
  
Direction: 📥 Pull-Only (initial sync)

Transformation:
  GH → TW:
    - Add issue body as first annotation
    - Only on initial sync
    - Prefix with "[GitHub Body]"

Example:
  TW: annotation:"[GitHub Body] This is the issue description..."
  GH: body:"This is the issue description..."

Notes:
  - Provides context in TaskWarrior
  - Only sync once (don't update)
  - Consider truncating long bodies

Recommendation: Optional feature, off by default
```

#### 3.9 Closed Date → End
```yaml
Mapping:
  TaskWarrior: end
  GitHub: closedAt
  
Direction: 📥 Pull-Only

Transformation:
  GH → TW:
    - Set end date when issue closed
    - Only if task status becomes completed

Example:
  TW: end:2024-01-15T15:00:00Z
  GH: closedAt:2024-01-15T15:00:00Z

Notes:
  - Preserves completion time
  - Only set when status changes to completed
```

#### 3.10 State Reason → Tag
```yaml
Mapping:
  TaskWarrior: tag (e.g., "not-planned")
  GitHub: stateReason
  
Direction: 📥 Pull-Only

Transformation:
  GH → TW:
    COMPLETED     → (no special tag)
    NOT_PLANNED   → tag:not-planned
    REOPENED      → tag:reopened

Example:
  TW: tags:not-planned
  GH: stateReason:"NOT_PLANNED"

Notes:
  - Provides context for closure
  - Could map NOT_PLANNED to status:deleted
```

---

### Category 4: 📤 Push-Only Mappings (TaskWarrior → GitHub)

#### 4.1 Start Date → Comment
```yaml
Mapping:
  TaskWarrior: start
  GitHub: comment (notification)
  
Direction: 📤 Push-Only (optional)

Transformation:
  TW → GH:
    - When task started, add comment
    - "[TaskWarrior] Work started on this issue"

Example:
  TW: start:2024-01-15T10:00:00Z
  GH: comment:"[TaskWarrior] Work started on 2024-01-15"

Notes:
  - Provides visibility in GitHub
  - Optional feature

Recommendation: Optional, off by default
```

#### 4.2 Urgency → Label
```yaml
Mapping:
  TaskWarrior: urgency
  GitHub: label (e.g., "urgency:high")
  
Direction: 📤 Push-Only (optional)

Transformation:
  TW → GH:
    urgency > 10 → urgency:high
    urgency 5-10 → urgency:medium
    urgency < 5  → urgency:low

Example:
  TW: urgency:12.5
  GH: label:"urgency:high"

Notes:
  - TaskWarrior calculates urgency automatically
  - Could provide useful signal in GitHub
  - May be noisy

Recommendation: Optional, off by default
```

---

### Category 5: ❌ No Mapping (Not Synced)

#### 5.1 TaskWarrior Fields (Not Synced)
```yaml
Fields:
  - depends          # Task dependencies (TW-specific)
  - wait             # Wait date (TW-specific)
  - scheduled        # Scheduled date (TW-specific)
  - until            # Expiration date (TW-specific)
  - recur            # Recurrence pattern (TW-specific)
  - parent           # Parent task (TW-specific)
  - imask            # Recurrence mask (TW-specific)

Reason:
  - No GitHub equivalent
  - TaskWarrior-specific workflow features
  - Would require complex custom implementation
```

#### 5.2 GitHub Fields (Not Synced)
```yaml
Fields:
  - id               # GitHub internal ID (not useful)
  - isPinned         # UI-specific feature
  - projectCards     # GitHub Projects v1 (deprecated)
  - projectItems     # GitHub Projects v2 (complex)
  - reactionGroups   # Reactions (not essential)

Reason:
  - Not essential for task management
  - UI-specific features
  - Complex to map
  - Low value for sync
```

---

## Recommended Default Configuration

### Phase 1: MVP (Minimal Viable Product)

```yaml
Bidirectional (Always Synced):
  ✅ description ↔ title
  ✅ status ↔ state
  ✅ priority ↔ labels (priority:*)
  ✅ tags ↔ labels

Pull-Only (Always Synced):
  ✅ number → githubissue (UDA)
  ✅ url → githuburl (UDA)
  ✅ (repo) → githubrepo (UDA)
  ✅ author.login → githubauthor (UDA)
  ✅ createdAt → entry (initial only)
  ✅ closedAt → end (when closed)

Not Synced (Phase 1):
  ❌ annotations ↔ comments (too complex initially)
  ❌ project ↔ milestone (opt-in later)
  ❌ due ↔ milestone.dueOn (opt-in later)
  ❌ assignees (pull-only later)
```

### Phase 2: Enhanced Features (Optional)

```yaml
Opt-In Features:
  ⚠️ annotations ↔ comments (bidirectional, append-only)
  ⚠️ project ↔ milestone (with configuration)
  ⚠️ due ↔ milestone.dueOn or label
  ⚠️ assignees → githubassignees (pull-only)
  ⚠️ body → annotation (initial sync only)
  ⚠️ start → comment (push notification)
```

---

## Configuration Format

### Profile-Level Configuration
```bash
# ~/.task/github-sync.conf

# Core mappings (always enabled)
SYNC_DESCRIPTION=true
SYNC_STATUS=true
SYNC_PRIORITY=true
SYNC_TAGS=true

# Optional mappings (opt-in)
SYNC_ANNOTATIONS=false      # Bidirectional comments
SYNC_PROJECT=false          # Project ↔ Milestone
SYNC_DUE=false              # Due date handling
SYNC_ASSIGNEES=false        # Pull assignees
SYNC_BODY=false             # Pull issue body as annotation
SYNC_START_NOTIFY=false     # Push start notifications

# Tag filtering
SYNC_EXCLUDE_TAGS="ACTIVE,READY,PENDING,COMPLETED,DELETED,sync:*"

# Label filtering
SYNC_EXCLUDE_LABELS="sync:*"
```

### Per-Task Override (Future)
```bash
# Task-level UDA for fine-grained control
uda.githubsyncfields.type=string
uda.githubsyncfields.label=GitHub Sync Fields
uda.githubsyncfields.values=all,minimal,custom

# Example
task abc-123 modify githubsyncfields:minimal
```

---

## Field Mapping Summary Table

| TaskWarrior Field | GitHub Field | Direction | Phase | Default |
|-------------------|--------------|-----------|-------|---------|
| description | title | ↔️ | 1 | ✅ On |
| status | state | ↔️ | 1 | ✅ On |
| priority | labels (priority:*) | ↔️ | 1 | ✅ On |
| tags | labels | ↔️ | 1 | ✅ On |
| annotations | comments | ↔️ | 2 | ❌ Off |
| project | milestone | ↔️ | 2 | ❌ Off |
| due | milestone.dueOn | ⚠️ | 2 | ❌ Off |
| (UDA) githubissue | number | 📥 | 1 | ✅ On |
| (UDA) githuburl | url | 📥 | 1 | ✅ On |
| (UDA) githubrepo | (derived) | 📥 | 1 | ✅ On |
| (UDA) githubauthor | author.login | 📥 | 1 | ✅ On |
| (UDA) githubassignees | assignees | 📥 | 2 | ❌ Off |
| entry | createdAt | 📥 | 1 | ✅ On |
| end | closedAt | 📥 | 1 | ✅ On |
| modified | updatedAt | 📥 | 1 | ✅ On |
| start | (comment) | 📤 | 2 | ❌ Off |
| urgency | labels (urgency:*) | 📤 | 2 | ❌ Off |

---

## Recommendations

### For MVP (Phase 1):
1. **Enable by default**: description, status, priority, tags
2. **Pull metadata**: issue number, URL, repo, author, dates
3. **Skip for now**: annotations/comments, project/milestone, assignees

### For Phase 2 (Optional):
1. **Add opt-in**: annotations ↔ comments (most requested)
2. **Add opt-in**: project ↔ milestone (useful for organization)
3. **Add opt-in**: assignees (pull-only, useful for teams)
4. **Consider**: due date handling (label-based approach)

### Configuration Philosophy:
- **Safe defaults**: Only sync fields that are low-risk
- **Opt-in complexity**: Advanced features require explicit enable
- **Profile-level**: Configuration at profile level (not per-task initially)
- **Future expansion**: Design allows per-task overrides later

---

## Next Steps

1. **Review this mapping** - Confirm field selections
2. **Finalize Phase 1 fields** - Lock in MVP scope
3. **Design UDA schema** - Define all UDAs needed
4. **Create field mapper** - Implement transformation logic
5. **Build tests** - Test each mapping thoroughly

**Questions for Review:**
1. Agree with Phase 1 field selection?
2. Should annotations/comments be in Phase 1 or 2?
3. Any other fields you want to prioritize?
4. Agree with opt-in approach for complex features?
