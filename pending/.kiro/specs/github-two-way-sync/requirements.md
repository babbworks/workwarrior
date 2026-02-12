# Requirements Document: GitHub Two-Way Sync

## Introduction

This document specifies the requirements for implementing bidirectional synchronization between TaskWarrior and GitHub issues. The feature extends the existing one-way bugwarrior sync (GitHub → TaskWarrior) by adding push capabilities (TaskWarrior → GitHub), enabling a complete two-way sync workflow for single-user contexts.

The implementation uses a hybrid approach: keeping bugwarrior for pull operations while adding gh CLI for push operations, coordinated by a custom sync engine.

## Glossary

- **Sync_Engine**: The custom shell-based synchronization system that coordinates bidirectional sync between TaskWarrior and GitHub
- **TaskWarrior**: Task management system that stores tasks locally
- **GitHub**: Issue tracking service accessed via gh CLI
- **Bugwarrior**: Existing tool that pulls issues from external services into TaskWarrior (one-way sync)
- **gh_CLI**: Official GitHub command-line tool used for push operations
- **Profile**: A Workwarrior workspace with isolated TaskWarrior, journal, and ledger configurations
- **State_Database**: JSON file tracking sync state for each task-issue pair
- **UDA**: User Defined Attribute in TaskWarrior for storing custom metadata
- **Field_Mapper**: Component that transforms data between TaskWarrior and GitHub formats
- **Conflict_Resolver**: Component that handles simultaneous changes on both sides
- **Sync_State**: Stored information about last known state of task and issue for change detection

## Requirements

### Requirement 1: Bidirectional Field Synchronization

**User Story:** As a developer, I want my task changes in TaskWarrior to sync to GitHub and vice versa, so that I can work in either system without manual updates.

#### Acceptance Criteria

1. WHEN a task description is modified in TaskWarrior, THE Sync_Engine SHALL update the corresponding GitHub issue title
2. WHEN a GitHub issue title is modified, THE Sync_Engine SHALL update the corresponding TaskWarrior task description
3. WHEN a task status changes to completed in TaskWarrior, THE Sync_Engine SHALL close the corresponding GitHub issue
4. WHEN a GitHub issue is closed, THE Sync_Engine SHALL mark the corresponding TaskWarrior task as completed
5. WHEN a task priority is set in TaskWarrior, THE Sync_Engine SHALL add the corresponding priority label to the GitHub issue
6. WHEN a priority label is added to a GitHub issue, THE Sync_Engine SHALL set the corresponding TaskWarrior task priority
7. WHEN tags are added to a TaskWarrior task, THE Sync_Engine SHALL add corresponding labels to the GitHub issue
8. WHEN labels are added to a GitHub issue, THE Sync_Engine SHALL add corresponding tags to the TaskWarrior task
9. WHEN an annotation is added to a TaskWarrior task, THE Sync_Engine SHALL add a comment to the GitHub issue with "[TaskWarrior]" prefix
10. WHEN a comment is added to a GitHub issue, THE Sync_Engine SHALL add an annotation to the TaskWarrior task with "[GitHub @username]" prefix

### Requirement 2: Pull-Only Metadata Fields

**User Story:** As a developer, I want GitHub metadata stored in TaskWarrior, so that I can reference and filter tasks by their GitHub properties.

#### Acceptance Criteria

1. WHEN a GitHub issue is synced, THE Sync_Engine SHALL store the issue number in the githubissue UDA
2. WHEN a GitHub issue is synced, THE Sync_Engine SHALL store the issue URL in the githuburl UDA
3. WHEN a GitHub issue is synced, THE Sync_Engine SHALL store the repository name in the githubrepo UDA
4. WHEN a GitHub issue is synced, THE Sync_Engine SHALL store the author username in the githubauthor UDA
5. WHEN a GitHub issue is synced for the first time, THE Sync_Engine SHALL set the task entry date to the issue creation date
6. WHEN a GitHub issue is closed, THE Sync_Engine SHALL set the task end date to the issue closed date
7. WHEN detecting changes, THE Sync_Engine SHALL compare the GitHub updatedAt timestamp with the stored last sync timestamp

### Requirement 3: State Management

**User Story:** As a developer, I want the sync system to track what has been synced, so that it can detect changes and avoid duplicate operations.

#### Acceptance Criteria

1. WHEN a task is synced, THE Sync_Engine SHALL store the last known task state in the State_Database
2. WHEN a GitHub issue is synced, THE Sync_Engine SHALL store the last known issue state in the State_Database
3. WHEN an annotation is synced, THE Sync_Engine SHALL record its hash in the State_Database to prevent duplicate syncing
4. WHEN a comment is synced, THE Sync_Engine SHALL record its ID in the State_Database to prevent duplicate syncing
5. THE State_Database SHALL be stored as JSON at ~/.task/github-sync/state.json
6. THE State_Database SHALL be profile-isolated using WORKWARRIOR_BASE path
7. WHEN the State_Database is corrupted or missing, THE Sync_Engine SHALL initialize a new state file

### Requirement 4: Change Detection

**User Story:** As a developer, I want the sync system to detect what changed since last sync, so that it only syncs necessary updates.

#### Acceptance Criteria

1. WHEN comparing task states, THE Sync_Engine SHALL detect changes in description, status, priority, tags, and annotation count
2. WHEN comparing GitHub states, THE Sync_Engine SHALL detect changes in title, state, labels, and comment count
3. WHEN only the task changed, THE Sync_Engine SHALL perform a push operation
4. WHEN only the GitHub issue changed, THE Sync_Engine SHALL perform a pull operation
5. WHEN both task and issue changed, THE Sync_Engine SHALL invoke the Conflict_Resolver
6. WHEN neither changed, THE Sync_Engine SHALL skip the sync operation

### Requirement 5: Conflict Resolution

**User Story:** As a developer working alone, I want conflicts resolved automatically using last-write-wins, so that I don't need manual intervention for timing issues.

#### Acceptance Criteria

1. WHEN both task and issue changed, THE Conflict_Resolver SHALL compare the modified timestamp with the updatedAt timestamp
2. WHEN the task was modified more recently, THE Conflict_Resolver SHALL push task changes to GitHub
3. WHEN the issue was updated more recently, THE Conflict_Resolver SHALL pull issue changes to TaskWarrior
4. WHEN timestamps are equal, THE Conflict_Resolver SHALL prefer the GitHub state
5. THE Conflict_Resolver SHALL log all conflict resolutions to the error log

### Requirement 6: Field Mapping and Transformation

**User Story:** As a developer, I want data transformed correctly between TaskWarrior and GitHub formats, so that information is preserved accurately.

#### Acceptance Criteria

1. WHEN mapping task status to GitHub state, THE Field_Mapper SHALL map pending/started/waiting to OPEN and completed/deleted to CLOSED
2. WHEN mapping GitHub state to task status, THE Field_Mapper SHALL map OPEN to pending and CLOSED to completed
3. WHEN mapping task priority to labels, THE Field_Mapper SHALL create priority:high, priority:medium, or priority:low labels
4. WHEN mapping labels to task priority, THE Field_Mapper SHALL extract priority from priority:* labels
5. WHEN mapping tags to labels, THE Field_Mapper SHALL exclude system tags (ACTIVE, READY, PENDING, etc.)
6. WHEN mapping labels to tags, THE Field_Mapper SHALL exclude priority:* labels
7. WHEN a task description exceeds 256 characters, THE Field_Mapper SHALL truncate it and warn the user
8. WHEN mapping annotations to comments, THE Field_Mapper SHALL prefix with "[TaskWarrior]" and include timestamp
9. WHEN mapping comments to annotations, THE Field_Mapper SHALL prefix with "[GitHub @username]" and include timestamp

### Requirement 7: Sync Operations

**User Story:** As a developer, I want manual control over sync operations, so that I can choose when to push, pull, or sync bidirectionally.

#### Acceptance Criteria

1. WHEN the user runs "i push", THE Sync_Engine SHALL push all changed tasks to GitHub
2. WHEN the user runs "i pull", THE Sync_Engine SHALL pull all changed issues from GitHub
3. WHEN the user runs "i sync", THE Sync_Engine SHALL perform bidirectional sync for all synced tasks
4. WHEN the user runs "i push <uuid>", THE Sync_Engine SHALL push only the specified task
5. WHEN the user runs "i pull <uuid>", THE Sync_Engine SHALL pull only the specified task's issue
6. WHEN the user runs "i sync <uuid>", THE Sync_Engine SHALL sync only the specified task
7. WHEN a sync operation completes successfully, THE Sync_Engine SHALL display a success message
8. WHEN a sync operation fails, THE Sync_Engine SHALL display an error message and log details

### Requirement 8: Sync Enablement

**User Story:** As a developer, I want to control which tasks sync with GitHub, so that I can keep some tasks local-only.

#### Acceptance Criteria

1. WHEN a task has a githubissue UDA, THE Sync_Engine SHALL consider it eligible for syncing
2. WHEN the user runs "i enable-sync <uuid> <issue-number>", THE Sync_Engine SHALL link the task to the GitHub issue
3. WHEN the user runs "i disable-sync <uuid>", THE Sync_Engine SHALL unlink the task from GitHub
4. WHEN a task is linked to GitHub, THE Sync_Engine SHALL set the githubsync UDA to "enabled"
5. WHEN a task is unlinked from GitHub, THE Sync_Engine SHALL set the githubsync UDA to "disabled"
6. WHEN enabling sync, THE Sync_Engine SHALL perform an initial pull to populate task fields

### Requirement 9: Error Handling and Validation

**User Story:** As a developer, I want clear error messages and interactive correction, so that I can fix sync issues quickly.

#### Acceptance Criteria

1. WHEN a field validation fails, THE Sync_Engine SHALL display the current value, error message, and requirements
2. WHEN a title is too long, THE Sync_Engine SHALL suggest a truncated version and prompt for correction
3. WHEN a label format is invalid, THE Sync_Engine SHALL suggest a sanitized version and prompt for correction
4. WHEN a permission error occurs, THE Sync_Engine SHALL display the cause and suggest solutions
5. WHEN a rate limit is exceeded, THE Sync_Engine SHALL display wait time and offer to wait or skip
6. WHEN a network error occurs, THE Sync_Engine SHALL log the error and offer to retry
7. WHEN an error is corrected, THE Sync_Engine SHALL automatically retry the sync operation up to 3 times
8. WHEN max retries are exceeded, THE Sync_Engine SHALL log the failure and skip the task

### Requirement 10: GitHub API Integration

**User Story:** As a developer, I want the sync system to use gh CLI for GitHub operations, so that authentication and API access are handled reliably.

#### Acceptance Criteria

1. WHEN performing GitHub operations, THE Sync_Engine SHALL use gh CLI commands
2. WHEN gh CLI is not installed, THE Sync_Engine SHALL display an error message with installation instructions
3. WHEN gh CLI is not authenticated, THE Sync_Engine SHALL display an error message with authentication instructions
4. WHEN fetching an issue, THE Sync_Engine SHALL use "gh issue view" with JSON output
5. WHEN updating an issue, THE Sync_Engine SHALL use "gh issue edit" with appropriate flags
6. WHEN adding a comment, THE Sync_Engine SHALL use "gh issue comment" with the comment body
7. WHEN creating labels, THE Sync_Engine SHALL use "gh label create" if the label doesn't exist

### Requirement 11: Profile Isolation

**User Story:** As a developer with multiple profiles, I want each profile's sync state isolated, so that syncing one profile doesn't affect others.

#### Acceptance Criteria

1. THE Sync_Engine SHALL use WORKWARRIOR_BASE to determine the active profile
2. THE State_Database SHALL be stored in $WORKWARRIOR_BASE/.task/github-sync/state.json
3. WHEN no profile is active, THE Sync_Engine SHALL display an error message
4. WHEN switching profiles, THE Sync_Engine SHALL use the new profile's state database
5. THE Sync_Engine SHALL use the profile's .taskrc and .task directory for all TaskWarrior operations

### Requirement 12: Configuration Management

**User Story:** As a developer, I want to configure sync behavior per profile, so that I can customize sync settings for different workflows.

#### Acceptance Criteria

1. THE Sync_Engine SHALL read configuration from $WORKWARRIOR_BASE/.config/github-sync/config.sh
2. WHEN configuration is missing, THE Sync_Engine SHALL use default values
3. THE configuration SHALL support setting default repository
4. THE configuration SHALL support setting conflict resolution strategy
5. THE configuration SHALL support enabling/disabling auto-sync
6. THE configuration SHALL support excluding specific tags from syncing
7. THE configuration SHALL support excluding specific labels from syncing

### Requirement 13: Logging and Debugging

**User Story:** As a developer troubleshooting sync issues, I want detailed logs, so that I can understand what went wrong.

#### Acceptance Criteria

1. THE Sync_Engine SHALL log all sync operations to $WORKWARRIOR_BASE/.task/github-sync/sync.log
2. THE Sync_Engine SHALL log all errors to $WORKWARRIOR_BASE/.task/github-sync/errors.log
3. WHEN a sync operation starts, THE Sync_Engine SHALL log the task UUID and operation type
4. WHEN a sync operation completes, THE Sync_Engine SHALL log the result and duration
5. WHEN an error occurs, THE Sync_Engine SHALL log the error category, field, and GitHub response
6. THE error log SHALL use JSON format for structured logging
7. WHEN the user runs "i sync-status", THE Sync_Engine SHALL display recent sync activity

### Requirement 14: Integration with Existing Issues Service

**User Story:** As a developer using bugwarrior, I want two-way sync to coexist with existing one-way sync, so that I don't lose existing functionality.

#### Acceptance Criteria

1. THE Sync_Engine SHALL not interfere with bugwarrior pull operations
2. WHEN bugwarrior creates a task, THE Sync_Engine SHALL detect it and initialize sync state
3. WHEN a task has bugwarrior UDAs, THE Sync_Engine SHALL preserve them during sync
4. THE i() function SHALL route "i pull" to bugwarrior for backward compatibility
5. THE i() function SHALL route "i push" and "i sync" to the Sync_Engine
6. WHEN the user runs "i custom", THE i() function SHALL route to the issues configuration tool

### Requirement 15: Annotation and Comment Sync

**User Story:** As a developer, I want annotations and comments synced bidirectionally, so that discussions are visible in both systems.

#### Acceptance Criteria

1. WHEN syncing annotations, THE Sync_Engine SHALL only sync new annotations since last sync
2. WHEN syncing comments, THE Sync_Engine SHALL only sync new comments since last sync
3. THE Sync_Engine SHALL track synced annotation hashes to prevent duplicates
4. THE Sync_Engine SHALL track synced comment IDs to prevent duplicates
5. WHEN an annotation is synced to GitHub, THE Sync_Engine SHALL prefix it with "[TaskWarrior]"
6. WHEN a comment is synced to TaskWarrior, THE Sync_Engine SHALL prefix it with "[GitHub @username]"
7. THE Sync_Engine SHALL never delete or edit existing annotations or comments (append-only)

### Requirement 16: UDA Definitions

**User Story:** As a developer, I want GitHub metadata stored in TaskWarrior UDAs, so that I can filter and report on GitHub-synced tasks.

#### Acceptance Criteria

1. THE Sync_Engine SHALL define githubissue UDA as numeric type
2. THE Sync_Engine SHALL define githuburl UDA as string type
3. THE Sync_Engine SHALL define githubrepo UDA as string type
4. THE Sync_Engine SHALL define githubauthor UDA as string type
5. THE Sync_Engine SHALL define githubsync UDA as string type with values enabled/disabled
6. WHEN installing the sync system, THE Sync_Engine SHALL add UDA definitions to .taskrc if missing
7. THE UDA definitions SHALL be added to the profile's .taskrc, not the global .taskrc

### Requirement 17: Dry Run Mode

**User Story:** As a developer testing sync configuration, I want a dry-run mode, so that I can preview changes without applying them.

#### Acceptance Criteria

1. WHEN the user runs "i push --dry-run", THE Sync_Engine SHALL display what would be pushed without making changes
2. WHEN the user runs "i pull --dry-run", THE Sync_Engine SHALL display what would be pulled without making changes
3. WHEN the user runs "i sync --dry-run", THE Sync_Engine SHALL display all planned operations without executing them
4. WHEN in dry-run mode, THE Sync_Engine SHALL not modify TaskWarrior tasks
5. WHEN in dry-run mode, THE Sync_Engine SHALL not modify GitHub issues
6. WHEN in dry-run mode, THE Sync_Engine SHALL not update the State_Database

### Requirement 18: Batch Operations

**User Story:** As a developer with many synced tasks, I want efficient batch syncing, so that I don't wait for sequential operations.

#### Acceptance Criteria

1. WHEN syncing multiple tasks, THE Sync_Engine SHALL process them sequentially to avoid rate limiting
2. WHEN a batch operation encounters an error, THE Sync_Engine SHALL continue processing remaining tasks
3. WHEN a batch operation completes, THE Sync_Engine SHALL display a summary of successes and failures
4. WHEN multiple tasks fail, THE Sync_Engine SHALL offer to fix errors interactively
5. THE Sync_Engine SHALL respect GitHub API rate limits and pause if necessary

### Requirement 19: Shell Integration

**User Story:** As a developer, I want sync commands integrated into the i() function, so that they follow the same pattern as other Workwarrior commands.

#### Acceptance Criteria

1. THE i() function SHALL accept "push", "pull", "sync", "enable-sync", "disable-sync", and "sync-status" subcommands
2. THE i() function SHALL pass --global and --profile flags to the Sync_Engine for scope resolution
3. THE i() function SHALL display the one-way sync warning for "i pull" commands
4. THE i() function SHALL check for active profile before executing sync commands
5. THE i() function SHALL route "i custom" to the issues configuration tool

### Requirement 20: Documentation and Help

**User Story:** As a developer learning the sync system, I want clear documentation and help text, so that I can understand how to use it.

#### Acceptance Criteria

1. WHEN the user runs "i sync --help", THE Sync_Engine SHALL display usage information for sync commands
2. WHEN the user runs "i push --help", THE Sync_Engine SHALL display usage information for push operations
3. WHEN the user runs "i pull --help", THE Sync_Engine SHALL display usage information for pull operations
4. THE help text SHALL include examples for common use cases
5. THE help text SHALL explain the difference between push, pull, and sync operations
6. THE help text SHALL document all available flags and options
