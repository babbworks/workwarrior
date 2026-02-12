# Implementation Plan: GitHub Two-Way Sync

## Overview

This implementation plan breaks down the GitHub two-way sync feature into discrete coding tasks organized by week. The plan follows the architecture specified in the design document, building from foundational components through core sync logic to the final CLI interface.

The implementation uses shell scripting (bash) to fit Workwarrior's existing architecture and leverages the gh CLI tool for GitHub operations.

## Tasks

### Week 1-2: Foundation and Core Infrastructure

- [x] 1. Set up project structure and UDA definitions
  - Create directory structure: `lib/` for sync components
  - Add UDA definitions to profile .taskrc template
  - Create state database directory structure
  - Set up logging infrastructure
  - _Requirements: 3.5, 16.1, 16.2, 16.3, 16.4, 16.5, 16.6, 16.7_

- [ ]* 1.1 Write unit tests for UDA definitions
  - Test that UDAs are added to .taskrc correctly
  - Test profile-specific .taskrc modification
  - _Requirements: 16.6, 16.7_

- [x] 2. Implement State Manager (`lib/github-sync-state.sh`)
  - [x] 2.1 Implement state database initialization
    - Write `init_state_database()` function
    - Create JSON file with proper permissions
    - Handle missing parent directories
    - _Requirements: 3.5, 3.7_
  
  - [x] 2.2 Implement state CRUD operations
    - Write `get_sync_state()` function
    - Write `save_sync_state()` function
    - Write `remove_sync_state()` function
    - Use jq for JSON manipulation
    - _Requirements: 3.1, 3.2_
  
  - [x] 2.3 Implement state query functions
    - Write `is_task_synced()` function
    - Write `get_all_synced_tasks()` function
    - Handle empty state database
    - _Requirements: 8.1_
  
  - [ ]* 2.4 Write property test for state persistence
    - **Property 8: State Persistence**
    - **Validates: Requirements 3.1, 3.2**
  
  - [ ]* 2.5 Write unit tests for state corruption recovery
    - Test corrupted JSON handling
    - Test missing file recovery
    - _Requirements: 3.7_

- [x] 3. Implement GitHub API Wrapper (`lib/github-api.sh`)
  - [x] 3.1 Implement gh CLI availability check
    - Write `check_gh_cli()` function
    - Check for gh installation
    - Check for gh authentication
    - Display helpful error messages
    - _Requirements: 10.2, 10.3_
  
  - [x] 3.2 Implement issue fetch operations
    - Write `github_get_issue()` function
    - Use `gh issue view --json` for data retrieval
    - Parse JSON response
    - Handle errors (not found, permission denied)
    - _Requirements: 10.4_
  
  - [x] 3.3 Implement issue update operations
    - Write `github_update_issue()` function
    - Use `gh issue edit` for title and state updates
    - Handle validation errors
    - _Requirements: 10.5_
  
  - [x] 3.4 Implement label management
    - Write `github_update_labels()` function
    - Write `github_ensure_label()` function
    - Add and remove labels
    - Create labels if they don't exist
    - _Requirements: 10.7_
  
  - [x] 3.5 Implement comment operations
    - Write `github_add_comment()` function
    - Use `gh issue comment` for adding comments
    - Return comment ID
    - _Requirements: 10.6_
  
  - [ ]* 3.6 Write unit tests for GitHub API wrapper
    - Mock gh CLI responses
    - Test error handling
    - Test JSON parsing
    - _Requirements: 10.1, 10.2, 10.3_


- [x] 4. Implement TaskWarrior API Wrapper (`lib/taskwarrior-api.sh`)
  - [x] 4.1 Implement task fetch operations
    - Write `tw_get_task()` function
    - Use `task export` for data retrieval
    - Parse JSON response
    - Handle missing tasks
    - _Requirements: 11.5_
  
  - [x] 4.2 Implement task update operations
    - Write `tw_update_task()` function
    - Use `task modify` for field updates
    - Handle validation errors
    - Respect TASKRC and TASKDATA environment variables
    - _Requirements: 11.5_
  
  - [x] 4.3 Implement annotation operations
    - Write `tw_add_annotation()` function
    - Use `task annotate` command
    - Handle annotation text escaping
    - _Requirements: 1.10_
  
  - [x] 4.4 Implement task query functions
    - Write `tw_get_task_by_issue()` function
    - Write `tw_task_exists()` function
    - Use `task export` with filters
    - _Requirements: 8.1_
  
  - [ ]* 4.5 Write unit tests for TaskWarrior API wrapper
    - Test with isolated test profile
    - Test field updates
    - Test annotation handling
    - _Requirements: 11.5_

- [x] 5. Checkpoint - Foundation Complete
  - Ensure all tests pass
  - Verify state database operations work
  - Verify GitHub API wrapper works with real gh CLI
  - Verify TaskWarrior API wrapper works with test profile
  - Ask user if questions arise

### Week 3: Core Sync Logic

- [x] 6. Implement Field Mapper (`lib/field-mapper.sh`)
  - [x] 6.1 Implement status/state mapping
    - Write `map_status_to_github()` function
    - Write `map_github_to_status()` function
    - Handle all status values (pending, started, waiting, completed, deleted)
    - Handle stateReason for deleted vs completed
    - _Requirements: 1.3, 1.4, 6.1, 6.2_
  
  - [x] 6.2 Implement priority/label mapping
    - Write `map_priority_to_label()` function
    - Write `map_labels_to_priority()` function
    - Handle H/M/L/empty priority values
    - Create priority:high, priority:medium, priority:low labels
    - _Requirements: 1.5, 1.6, 6.3, 6.4_
  
  - [x] 6.3 Implement tags/labels mapping
    - Write `map_tags_to_labels()` function
    - Write `map_labels_to_tags()` function
    - Write `filter_system_tags()` function
    - Write `sanitize_label_name()` function
    - Exclude system tags and priority labels
    - _Requirements: 1.7, 1.8, 6.5, 6.6_
  
  - [x] 6.4 Implement description/title mapping
    - Write `truncate_title()` function
    - Handle titles >256 characters
    - Warn user when truncating
    - _Requirements: 1.1, 1.2, 6.7_
  
  - [x] 6.5 Implement annotation/comment mapping
    - Write functions to add prefixes
    - Write functions to format timestamps
    - Handle "[TaskWarrior]" and "[GitHub @username]" prefixes
    - _Requirements: 1.9, 1.10, 6.8, 6.9_
  
  - [ ]* 6.6 Write property test for status/state round trip
    - **Property 2: Status/State Round Trip**
    - **Validates: Requirements 1.3, 1.4, 6.1, 6.2**
  
  - [ ]* 6.7 Write property test for priority/label round trip
    - **Property 3: Priority/Label Round Trip**
    - **Validates: Requirements 1.5, 1.6, 6.3, 6.4**
  
  - [ ]* 6.8 Write property test for tags/labels round trip
    - **Property 4: Tags/Labels Round Trip**
    - **Validates: Requirements 1.7, 1.8, 6.5, 6.6**
  
  - [ ]* 6.9 Write property test for system tag exclusion
    - **Property 14: System Tag Exclusion**
    - **Validates: Requirements 6.5**
  
  - [ ]* 6.10 Write property test for title truncation
    - **Property 16: Title Truncation**
    - **Validates: Requirements 6.7**

- [x] 7. Implement Change Detector (`lib/sync-detector.sh`)
  - [x] 7.1 Implement task change detection
    - Write `detect_task_changes()` function
    - Compare description, status, priority, tags, annotation count
    - Return JSON object with changed fields
    - _Requirements: 4.1_
  
  - [x] 7.2 Implement GitHub change detection
    - Write `detect_github_changes()` function
    - Compare title, state, labels, comment count
    - Return JSON object with changed fields
    - _Requirements: 4.2_
  
  - [x] 7.3 Implement sync action determination
    - Write `determine_sync_action()` function
    - Return push, pull, conflict, or none
    - Handle all combinations of changes
    - _Requirements: 4.3, 4.4, 4.5, 4.6_
  
  - [x] 7.4 Implement annotation/comment delta detection
    - Write `detect_new_annotations()` function
    - Write `detect_new_comments()` function
    - Compare counts and track synced items
    - _Requirements: 15.1, 15.2_
  
  - [ ]* 7.5 Write property test for field change detection
    - **Property 11: Field Change Detection**
    - **Validates: Requirements 4.1, 4.2**
  
  - [ ]* 7.6 Write property test for sync action determination
    - **Property 12: Sync Action Determination**
    - **Validates: Requirements 4.3, 4.4, 4.5, 4.6**

- [x] 8. Implement Conflict Resolver (`lib/conflict-resolver.sh`)
  - [x] 8.1 Implement timestamp comparison
    - Write `compare_timestamps()` function
    - Parse ISO 8601 timestamps
    - Return task_newer, github_newer, or equal
    - _Requirements: 5.1_
  
  - [x] 8.2 Implement last-write-wins resolution
    - Write `resolve_conflict_last_write_wins()` function
    - Compare timestamps and determine winner
    - Prefer GitHub on equal timestamps
    - Return push or pull action
    - _Requirements: 5.2, 5.3, 5.4_
  
  - [x] 8.3 Implement conflict logging
    - Write `log_conflict_resolution()` function
    - Log to error log with JSON format
    - Include task UUID, strategy, and winner
    - _Requirements: 5.5_
  
  - [ ]* 8.4 Write property test for last-write-wins
    - **Property 13: Last-Write-Wins Conflict Resolution**
    - **Validates: Requirements 5.1, 5.2, 5.3**
  
  - [ ]* 8.5 Write unit test for equal timestamp tiebreaker
    - Test that GitHub wins when timestamps are equal
    - _Requirements: 5.4_

- [x] 9. Checkpoint - Core Logic Complete
  - Ensure all tests pass
  - Verify field mapping works correctly
  - Verify change detection identifies all changes
  - Verify conflict resolution works
  - Ask user if questions arise

### Week 4: Sync Operations and Error Handling

- [x] 10. Implement Error Handler (`lib/error-handler.sh`)
  - [x] 10.1 Implement error parsing
    - Write `parse_github_error()` function
    - Extract error field, code, message, value from GitHub response
    - Categorize errors (validation, permission, rate_limit, network, conflict)
    - _Requirements: 9.1_
  
  - [x] 10.2 Implement field-specific error handlers
    - Write `handle_title_error()` function
    - Write `handle_state_error()` function
    - Write `handle_label_error()` function
    - Display current value, error, requirements, and suggestions
    - Prompt for correction
    - _Requirements: 9.2, 9.3_
  
  - [x] 10.3 Implement permission and rate limit handlers
    - Write `handle_permission_error()` function
    - Write `handle_rate_limit_error()` function
    - Display helpful messages and solutions
    - Offer to wait for rate limit reset
    - _Requirements: 9.4, 9.5_
  
  - [x] 10.4 Implement retry logic
    - Write `sync_with_error_handling()` function
    - Retry up to 3 times after correction
    - Skip task after max retries
    - _Requirements: 9.7, 9.8_
  
  - [ ]* 10.5 Write property test for retry logic
    - **Property 30: Retry Logic**
    - **Validates: Requirements 9.7, 9.8**
  
  - [ ]* 10.6 Write unit tests for error handlers
    - Test each error category
    - Test interactive prompts (with mock input)
    - Test retry behavior
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [x] 11. Implement Pull Operations (`lib/sync-pull.sh`)
  - [x] 11.1 Implement single issue pull
    - Write `sync_pull_issue()` function
    - Fetch issue from GitHub
    - Detect changes
    - Map fields to TaskWarrior format
    - Update task
    - Update sync state
    - _Requirements: 7.2, 7.5_
  
  - [x] 11.2 Implement batch pull
    - Write `sync_pull_all()` function
    - Get all synced tasks
    - Pull each changed issue
    - Continue on errors
    - Display summary
    - _Requirements: 7.2, 18.2, 18.3_
  
  - [x] 11.3 Implement metadata population
    - Populate githubissue, githuburl, githubrepo, githubauthor UDAs
    - Set entry date on first sync
    - Set end date when issue closed
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_
  
  - [ ]* 11.4 Write property test for metadata population
    - **Property 7: Metadata Population**
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4**
  
  - [ ]* 11.5 Write property test for batch pull completeness
    - **Property 19: Batch Pull Completeness**
    - **Validates: Requirements 7.2, 18.2**

- [x] 12. Implement Push Operations (`lib/sync-push.sh`)
  - [x] 12.1 Implement single task push
    - Write `sync_push_task()` function
    - Get task from TaskWarrior
    - Detect changes
    - Map fields to GitHub format
    - Update issue
    - Update sync state
    - _Requirements: 7.1, 7.4_
  
  - [x] 12.2 Implement batch push
    - Write `sync_push_all()` function
    - Get all synced tasks
    - Push each changed task
    - Continue on errors
    - Display summary
    - _Requirements: 7.1, 18.2, 18.3_
  
  - [ ]* 12.3 Write property test for batch push completeness
    - **Property 18: Batch Push Completeness**
    - **Validates: Requirements 7.1, 18.2**

- [x] 13. Implement Bidirectional Sync (`lib/sync-bidirectional.sh`)
  - [x] 13.1 Implement single task bidirectional sync
    - Write `sync_task_bidirectional()` function
    - Fetch both task and issue states
    - Detect changes on both sides
    - Determine sync action (push, pull, conflict, none)
    - Execute appropriate operation
    - _Requirements: 7.3, 7.6_
  
  - [x] 13.2 Implement batch bidirectional sync
    - Write `sync_all_tasks()` function
    - Process all synced tasks
    - Handle conflicts
    - Display summary
    - _Requirements: 7.3, 18.2, 18.3_
  
  - [ ]* 13.3 Write property test for bidirectional sync completeness
    - **Property 20: Bidirectional Sync Completeness**
    - **Validates: Requirements 7.3**

- [x] 14. Implement Annotation/Comment Sync
  - [x] 14.1 Implement annotation to comment sync
    - Detect new annotations since last sync
    - Add "[TaskWarrior]" prefix
    - Create GitHub comments
    - Track synced annotation hashes
    - _Requirements: 1.9, 15.1, 15.3, 15.5_
  
  - [x] 14.2 Implement comment to annotation sync
    - Detect new comments since last sync
    - Add "[GitHub @username]" prefix
    - Create TaskWarrior annotations
    - Track synced comment IDs
    - _Requirements: 1.10, 15.2, 15.4, 15.6_
  
  - [ ]* 14.3 Write property test for annotation/comment idempotence
    - **Property 9: Annotation/Comment Idempotence**
    - **Validates: Requirements 3.3, 3.4, 15.1, 15.2, 15.3, 15.4**
  
  - [ ]* 14.4 Write property test for annotation append-only
    - **Property 5: Annotation/Comment Append-Only**
    - **Validates: Requirements 1.9, 15.5, 15.7**
  
  - [ ]* 14.5 Write property test for comment append-only
    - **Property 6: Comment/Annotation Append-Only**
    - **Validates: Requirements 1.10, 15.6, 15.7**

- [x] 15. Checkpoint - Sync Operations Complete
  - Ensure all tests pass
  - Verify push operations work with real GitHub
  - Verify pull operations work with real GitHub
  - Verify bidirectional sync handles all scenarios
  - Verify annotation/comment sync works
  - Ask user if questions arise

### Week 5: CLI Interface and Integration

- [x] 16. Implement CLI Interface (`services/custom/github-sync.sh`)
  - [x] 16.1 Implement main entry point and command routing
    - Write `main()` function
    - Parse command-line arguments
    - Route to appropriate subcommand
    - Handle --help flag
    - _Requirements: 19.1_
  
  - [x] 16.2 Implement enable/disable sync commands
    - Write `cmd_enable()` function
    - Write `cmd_disable()` function
    - Link/unlink task to GitHub issue
    - Set githubsync UDA
    - Perform initial pull on enable
    - _Requirements: 8.2, 8.3, 8.4, 8.5, 8.6_
  
  - [x] 16.3 Implement push command
    - Write `cmd_push()` function
    - Support single task or all tasks
    - Support --dry-run flag
    - Display success/error messages
    - _Requirements: 7.1, 7.4, 7.7, 7.8_
  
  - [x] 16.4 Implement pull command
    - Write `cmd_pull()` function
    - Support single task or all tasks
    - Support --dry-run flag
    - Display success/error messages
    - _Requirements: 7.2, 7.5, 7.7, 7.8_
  
  - [x] 16.5 Implement sync command
    - Write `cmd_sync()` function
    - Support single task or all tasks
    - Support --dry-run flag
    - Display success/error messages
    - _Requirements: 7.3, 7.6, 7.7, 7.8_
  
  - [x] 16.6 Implement status command
    - Write `cmd_status()` function
    - Display sync status for all tasks
    - Show last sync time, changes pending
    - _Requirements: 13.7_
  
  - [x] 16.7 Implement help command
    - Write `cmd_help()` function
    - Display usage information
    - Include examples
    - Document all flags and options
    - _Requirements: 20.1, 20.2, 20.3, 20.4, 20.5, 20.6_
  
  - [ ]* 16.8 Write unit tests for CLI interface
    - Test command routing
    - Test argument parsing
    - Test help text display
    - _Requirements: 19.1, 20.1, 20.2, 20.3_

- [x] 17. Implement Dry-Run Mode
  - [x] 17.1 Add dry-run flag support to all operations
    - Modify push, pull, sync functions
    - Display planned operations without executing
    - Ensure no changes to tasks, issues, or state
    - _Requirements: 17.1, 17.2, 17.3_
  
  - [ ]* 17.2 Write property test for dry-run immutability
    - **Property 38: Dry-Run Immutability**
    - **Validates: Requirements 17.1, 17.2, 17.3, 17.4, 17.5, 17.6**

- [x] 18. Integrate with Shell Integration (`lib/shell-integration.sh`)
  - [x] 18.1 Update i() function
    - Add routing for push, pull, sync, enable-sync, disable-sync, sync-status
    - Check for active profile
    - Display one-way sync warning for pull
    - Preserve existing bugwarrior routing
    - _Requirements: 14.4, 14.5, 14.6, 19.1, 19.2, 19.3, 19.4, 19.5_
  
  - [x] 18.2 Implement profile requirement check
    - Verify WORKWARRIOR_BASE is set
    - Display error if no profile active
    - _Requirements: 11.3, 19.4_
  
  - [ ]* 18.3 Write property test for shell command routing
    - **Property 36: Shell Command Routing**
    - **Validates: Requirements 19.1, 19.5**
  
  - [ ]* 18.4 Write property test for profile requirement
    - **Property 37: Profile Requirement**
    - **Validates: Requirements 11.3, 19.4**

- [x] 19. Implement Configuration Management
  - [x] 19.1 Create configuration file template
    - Define all configuration options
    - Set sensible defaults
    - Document each option
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7_
  
  - [x] 19.2 Implement configuration loading
    - Read config from $WORKWARRIOR_BASE/.config/github-sync/config.sh
    - Use defaults if config missing
    - Validate configuration values
    - _Requirements: 12.1, 12.2_
  
  - [x] 19.3 Implement configuration-based filtering
    - Apply tag exclusion from config
    - Apply label exclusion from config
    - _Requirements: 12.6, 12.7_
  
  - [ ]* 19.4 Write property test for configuration defaults
    - **Property 26: Configuration Defaults**
    - **Validates: Requirements 12.2**
  
  - [ ]* 19.5 Write property test for tag exclusion configuration
    - **Property 27: Tag Exclusion Configuration**
    - **Validates: Requirements 12.6**

- [x] 20. Implement Logging
  - [x] 20.1 Implement operation logging
    - Log all sync operations to sync.log
    - Include task UUID, operation type, result, duration
    - _Requirements: 13.1, 13.3, 13.4_
  
  - [x] 20.2 Implement error logging
    - Log all errors to errors.log in JSON format
    - Include error category, field, GitHub response
    - _Requirements: 13.2, 13.5, 13.6_
  
  - [ ]* 20.3 Write property test for operation logging
    - **Property 31: Operation Logging**
    - **Validates: Requirements 13.1, 13.3, 13.4**
  
  - [ ]* 20.4 Write property test for error logging
    - **Property 32: Error Logging**
    - **Validates: Requirements 13.2, 13.5, 13.6**

- [x] 21. Implement Bugwarrior Integration
  - [x] 21.1 Ensure coexistence with bugwarrior
    - Don't interfere with bugwarrior operations
    - Detect bugwarrior-created tasks
    - Initialize sync state for bugwarrior tasks
    - Preserve bugwarrior UDAs
    - _Requirements: 14.1, 14.2, 14.3_
  
  - [ ]* 21.2 Write property test for bugwarrior coexistence
    - **Property 34: Bugwarrior Coexistence**
    - **Validates: Requirements 14.1, 14.3**
  
  - [ ]* 21.3 Write property test for bugwarrior task detection
    - **Property 35: Bugwarrior Task Detection**
    - **Validates: Requirements 14.2**

- [x] 22. Implement Profile Isolation
  - [x] 22.1 Ensure profile-specific paths
    - Use WORKWARRIOR_BASE for all paths
    - Store state database in profile directory
    - Store logs in profile directory
    - Store config in profile directory
    - _Requirements: 11.1, 11.2, 11.4, 11.5_
  
  - [ ]* 22.2 Write property test for profile isolation
    - **Property 10: Profile Isolation**
    - **Validates: Requirements 3.6, 11.2, 11.4**

- [x] 23. Final Checkpoint - Integration Complete
  - Ensure all tests pass
  - Verify CLI commands work correctly
  - Verify shell integration works
  - Verify configuration loading works
  - Verify logging works
  - Verify bugwarrior coexistence
  - Verify profile isolation
  - Ask user if questions arise

### Week 6: Testing, Documentation, and Polish

- [x] 24. Integration Testing
  - [x] 24.1 Test full push cycle with real GitHub
    - Create test repository
    - Create test tasks
    - Push to GitHub
    - Verify issue updates
    - _Requirements: 1.1, 1.3, 1.5, 1.7, 1.9_
  
  - [x] 24.2 Test full pull cycle with real GitHub
    - Create test issues
    - Pull to TaskWarrior
    - Verify task updates
    - _Requirements: 1.2, 1.4, 1.6, 1.8, 1.10_
  
  - [x] 24.3 Test bidirectional sync with real GitHub
    - Modify both task and issue
    - Run sync
    - Verify conflict resolution
    - _Requirements: 5.1, 5.2, 5.3_
  
  - [x] 24.4 Test error correction flow
    - Trigger validation errors
    - Test interactive correction
    - Verify retry logic
    - _Requirements: 9.1, 9.2, 9.3, 9.7, 9.8_
  
  - [x] 24.5 Test batch operations
    - Sync 10+ tasks
    - Verify sequential processing
    - Verify error resilience
    - Verify summary display
    - _Requirements: 18.1, 18.2, 18.3_

- [ ]* 24.6 Write property test for description/title round trip
  - **Property 1: Description/Title Round Trip**
  - **Validates: Requirements 1.1, 1.2**

- [ ]* 24.7 Write property test for sync success feedback
  - **Property 21: Sync Success Feedback**
  - **Validates: Requirements 7.7**

- [ ]* 24.8 Write property test for sync error feedback
  - **Property 22: Sync Error Feedback**
  - **Validates: Requirements 7.8, 13.2, 13.5**

- [x] 25. Documentation
  - [x] 25.1 Write user documentation
    - Getting started guide
    - Command reference
    - Configuration guide
    - Troubleshooting guide
    - _Requirements: 20.1, 20.2, 20.3, 20.4, 20.5, 20.6_
  
  - [x] 25.2 Write developer documentation
    - Architecture overview
    - Component descriptions
    - Testing guide
    - Contributing guide
  
  - [x] 25.3 Add inline code comments
    - Document all functions
    - Explain complex logic
    - Add usage examples

- [x] 26. Polish and Optimization
  - [x] 26.1 Improve error messages
    - Make messages more helpful
    - Add suggestions for common issues
    - Improve formatting
  
  - [x] 26.2 Optimize performance
    - Reduce redundant API calls
    - Optimize state database queries
    - Add caching where appropriate
  
  - [x] 26.3 Add progress indicators
    - Show progress for batch operations
    - Display estimated time remaining
    - Add spinner for long operations

- [x] 27. Final Testing and Release Preparation
  - [x] 27.1 Run full test suite
    - All unit tests pass
    - All property tests pass (100 iterations)
    - All integration tests pass
  
  - [x] 27.2 Manual testing checklist
    - Test with real GitHub repository
    - Test with multiple profiles
    - Test conflict resolution with real timing
    - Test error correction flow interactively
    - Test batch operations with 10+ tasks
    - Test bugwarrior coexistence
    - Test profile switching
    - Verify all help text displays correctly
    - Verify all error messages are helpful
  
  - [x] 27.3 Prepare release
    - Update version number
    - Write release notes
    - Tag release in git
    - Update main documentation

## Notes

- Tasks marked with `*` are optional test-related sub-tasks and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at key milestones
- Property tests validate universal correctness properties across many inputs
- Unit tests validate specific examples and edge cases
- Integration tests validate end-to-end workflows with real GitHub API

## Implementation Order Rationale

1. **Week 1-2**: Build foundational components (state management, API wrappers) that all other components depend on
2. **Week 3**: Implement core sync logic (field mapping, change detection, conflict resolution) that orchestrates the sync process
3. **Week 4**: Implement sync operations (push, pull, bidirectional) and error handling that use the core logic
4. **Week 5**: Implement CLI interface and integration that expose the functionality to users
5. **Week 6**: Testing, documentation, and polish to ensure production readiness

This order ensures each component can be tested as it's built, with dependencies available before they're needed.
