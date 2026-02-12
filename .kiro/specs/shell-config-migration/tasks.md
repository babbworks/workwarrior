# Implementation Plan: Shell Configuration Migration

## Overview

This implementation plan breaks down the Shell Configuration Migration feature into discrete, testable tasks. The system will be implemented as a bash script that safely migrates shell configuration files when Workwarrior is relocated. The implementation follows a bottom-up approach, building core utilities first, then composing them into higher-level functionality, and finally integrating everything into the main migration workflow.

## Tasks

- [ ] 1. Set up project structure and utilities
  - Create directory structure for the migration script
  - Set up script header with shebang and strict mode (set -euo pipefail)
  - Implement logging utilities (info, warn, error functions)
  - Implement color output functions for user-facing messages
  - _Requirements: 9.1, 9.2, 13.4_

- [ ] 2. Implement Config Manager component
  - [ ] 2.1 Create configuration file handling functions
    - Implement `load_install_config()` to read from ~/.config/workwarrior/install.conf
    - Implement `save_install_config(install_path, folder_name)` to write configuration
    - Implement `get_install_path()` to return full installation path
    - Handle missing config directory creation
    - _Requirements: 5.4, 14.4_
  
  - [ ]* 2.2 Write property test for configuration round-trip
    - **Property 8: Configuration Round-Trip**
    - **Validates: Requirements 5.4**
    - Generate random valid paths and folder names
    - Test that save then load returns identical values
  
  - [ ] 2.3 Implement user prompts for installation configuration
    - Implement `prompt_install_config()` to interactively ask for paths
    - Validate user input (path format, folder name)
    - Provide sensible defaults (/mp/, workwarrior)
    - _Requirements: 5.1, 5.2, 5.3_
  
  - [ ]* 2.4 Write unit tests for config manager edge cases
    - Test missing config file handling
    - Test invalid config format handling
    - Test config file permission errors
    - _Requirements: 5.4_

- [ ] 3. Implement File Scanner component
  - [ ] 3.1 Create shell config file detection
    - Implement `find_shell_config_files()` to locate all shell config files
    - Check for .bashrc, .zshrc, .bash_profile, .zprofile, .profile, .bash_aliases
    - Return only files that exist
    - _Requirements: 1.1, 1.2, 1.3_
  
  - [ ]* 3.2 Write property test for complete file detection
    - **Property 1: Complete File Detection**
    - **Validates: Requirements 1.1, 1.3**
    - Generate random sets of existing/non-existing files
    - Test that all existing files are found and non-existing are skipped
  
  - [ ] 3.3 Implement path reference scanning
    - Implement `scan_file_for_path(file_path, search_path)` to find line numbers
    - Implement `count_path_references(file_path, search_path)` to count occurrences
    - Handle different quoting styles (single, double, none)
    - _Requirements: 3.1, 3.2, 3.3_
  
  - [ ]* 3.4 Write property test for comprehensive path detection
    - **Property 4: Comprehensive Path Detection**
    - **Validates: Requirements 3.1, 3.2, 3.3**
    - Generate random shell config content with various quoting styles
    - Test that all path references are detected regardless of context
  
  - [ ] 3.5 Implement old path auto-detection
    - Implement `detect_old_path()` to find most common Workwarrior path
    - Scan for patterns like /*/ww/, /*/workwarrior/
    - Count occurrences and return most frequent
    - Handle multiple equal-frequency paths (prompt user)
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_
  
  - [ ]* 3.6 Write property test for old path auto-detection
    - **Property 10: Old Path Auto-Detection**
    - **Validates: Requirements 6.1, 6.2**
    - Generate random config files with various path frequencies
    - Test that most frequent path is correctly identified

- [ ] 4. Checkpoint - Verify core utilities work correctly
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Implement Backup Manager component
  - [ ] 5.1 Create backup file operations
    - Implement `create_backup(file_path)` with timestamp format
    - Use format {filename}.backup-YYYYMMDD-HHMMSS
    - Implement atomic backup creation (write to temp, then move)
    - Verify backup integrity after creation
    - _Requirements: 2.1, 2.2, 2.3_
  
  - [ ]* 5.2 Write property test for backup creation atomicity
    - **Property 2: Backup Creation Atomicity**
    - **Validates: Requirements 2.1, 2.2, 2.3, 13.2**
    - Generate random file content
    - Test that backup is created before modification
    - Test that failure prevents modification
  
  - [ ]* 5.3 Write property test for multiple backup preservation
    - **Property 3: Multiple Backup Preservation**
    - **Validates: Requirements 2.5**
    - Run migration multiple times
    - Test that each run creates distinct timestamped backups
  
  - [ ] 5.4 Implement backup discovery and rollback
    - Implement `find_latest_backup(original_file_path)` to find most recent backup
    - Implement `restore_from_backup(original_file_path)` to restore file
    - Implement `list_all_backups()` to show all available backups
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_
  
  - [ ]* 5.5 Write property test for rollback round-trip
    - **Property 11: Rollback Round-Trip**
    - **Validates: Requirements 8.2, 8.3**
    - Generate random file content
    - Test that migrate then rollback restores original state
  
  - [ ] 5.6 Implement backup cleanup
    - Implement `cleanup_old_backups(original_file_path, keep_count)` to remove old backups
    - Keep configurable number of most recent backups (default: 5)
    - _Requirements: 2.5_

- [ ] 6. Implement Path Replacer component
  - [ ] 6.1 Create path replacement logic
    - Implement `replace_paths_in_file(file_path, old_path, new_path)` using sed
    - Preserve quoting style (single, double, none)
    - Preserve indentation and whitespace
    - Use atomic file replacement (write to temp, validate, then move)
    - _Requirements: 4.1, 4.2, 4.3, 4.4_
  
  - [ ]* 6.2 Write property test for complete path replacement
    - **Property 5: Complete Path Replacement**
    - **Validates: Requirements 4.1, 4.2, 4.3, 11.5**
    - Generate random shell config with various quoting styles
    - Test that all paths are replaced while preserving formatting
  
  - [ ]* 6.3 Write property test for selective modification
    - **Property 6: Selective Modification**
    - **Validates: Requirements 11.1, 11.2, 11.3, 11.4**
    - Generate random config with path and non-path lines
    - Test that only path lines are modified
  
  - [ ]* 6.4 Write property test for section marker preservation
    - **Property 7: Section Marker Preservation**
    - **Validates: Requirements 12.1, 12.2, 12.3**
    - Generate random config with section markers
    - Test that markers and structure remain intact
  
  - [ ] 6.5 Implement syntax validation
    - Implement `validate_shell_syntax(file_path, shell_type)` for bash/zsh
    - Use bash -n or zsh -n for syntax checking
    - Handle cases where shell is not installed (skip validation with warning)
    - _Requirements: 13.4_
  
  - [ ] 6.6 Implement change preview
    - Implement `preview_changes(file_path, old_path, new_path)` using diff
    - Show side-by-side comparison of changes
    - Support --dry-run mode
    - _Requirements: 9.1, 9.3_

- [ ] 7. Checkpoint - Verify path replacement works correctly
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 8. Implement Reporter component
  - [ ] 8.1 Create output formatting functions
    - Implement `display_summary(files_processed, total_replacements, backup_locations)`
    - Implement `display_file_changes(file_path, replacement_count)`
    - Implement `display_error(error_message, file_path)`
    - Implement `display_rollback_instructions(backup_locations)`
    - Use color coding (green for success, red for errors, yellow for warnings)
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_
  
  - [ ]* 8.2 Write unit tests for reporter output
    - Test that summary includes all required information
    - Test that file changes are reported correctly
    - Test that error messages are clear and actionable
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [ ] 9. Implement path validation
  - [ ] 9.1 Create path validation functions
    - Implement validation that new path exists and is a directory
    - Implement validation that new path is readable
    - Implement offer to create directory if it doesn't exist
    - _Requirements: 5.5, 5.6_
  
  - [ ]* 9.2 Write property test for path validation
    - **Property 9: Path Validation**
    - **Validates: Requirements 5.5**
    - Generate random valid and invalid paths
    - Test that valid paths pass and invalid paths fail gracefully

- [ ] 10. Implement multi-shell support
  - [ ] 10.1 Add shell-specific handling
    - Detect shell type from filename (.bashrc → bash, .zshrc → zsh)
    - Handle bash-specific files (.bashrc, .bash_profile, .bash_aliases)
    - Handle zsh-specific files (.zshrc, .zprofile)
    - Handle shell-agnostic files (.profile)
    - _Requirements: 7.1, 7.2, 7.3, 7.4_
  
  - [ ]* 10.2 Write property test for multi-shell support
    - **Property 14: Multi-Shell Support**
    - **Validates: Requirements 7.1, 7.2, 7.3**
    - Generate random shell configs for different shell types
    - Test that each shell type is processed correctly

- [ ] 11. Implement idempotency checking
  - [ ] 11.1 Add detection for already-migrated files
    - Check if old path exists in files before migration
    - Report when no changes are needed
    - Skip backup creation when no changes needed
    - _Requirements: 10.1, 10.2, 10.3_
  
  - [ ]* 11.2 Write property test for idempotency
    - **Property 12: Idempotency**
    - **Validates: Requirements 10.1, 10.2, 10.3, 10.4**
    - Generate random shell config
    - Test that migrate(migrate(content)) = migrate(content)

- [ ] 12. Implement error handling and safety
  - [ ] 12.1 Add comprehensive error handling
    - Handle file permission errors (read/write)
    - Handle disk full errors
    - Handle backup creation failures
    - Ensure atomic operations (no partial modifications)
    - _Requirements: 13.1, 13.2, 13.3, 13.5_
  
  - [ ]* 12.2 Write property test for error atomicity
    - **Property 13: Error Atomicity**
    - **Validates: Requirements 13.1, 13.4**
    - Simulate various error conditions
    - Test that original files remain unmodified on error
  
  - [ ]* 12.3 Write unit tests for specific error scenarios
    - Test permission denied errors
    - Test disk full errors
    - Test invalid path errors
    - Test missing backup errors
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_

- [ ] 13. Checkpoint - Verify error handling works correctly
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 14. Implement main Migration Controller
  - [ ] 14.1 Create command-line argument parsing
    - Parse --old-path, --new-path, --non-interactive, --dry-run, --rollback, --help
    - Validate argument combinations
    - Display help text
    - _Requirements: 5.1, 6.4_
  
  - [ ] 14.2 Implement main migration workflow
    - Load or prompt for installation configuration
    - Validate new path exists and is accessible
    - Detect or prompt for old path
    - Scan for shell configuration files
    - For each file: backup, scan, replace, validate, report
    - Generate final summary report
    - _Requirements: 1.1, 2.1, 3.1, 4.1, 5.1, 6.1, 9.1_
  
  - [ ] 14.3 Implement rollback workflow
    - Find all backups for shell config files
    - Restore each file from most recent backup
    - Report which files were restored
    - _Requirements: 8.1, 8.2, 8.3, 8.4_
  
  - [ ] 14.4 Implement dry-run mode
    - Show what would be changed without modifying files
    - Display preview of all changes
    - Skip backup creation in dry-run mode
    - _Requirements: 9.1, 9.3_
  
  - [ ] 14.5 Implement non-interactive mode
    - Use defaults or fail on ambiguity
    - No user prompts
    - Suitable for automation/scripting
    - _Requirements: 5.1, 6.3_

- [ ] 15. Implement installation process integration
  - [ ] 15.1 Create installation hook
    - Offer to migrate during Workwarrior installation
    - Use installation path and folder name as new path
    - Detect fresh installation (no old paths) and skip migration
    - Store installation configuration for future use
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5_
  
  - [ ]* 15.2 Write integration tests for installation flow
    - Test fresh installation (no migration needed)
    - Test migration during installation
    - Test skipping migration during installation
    - _Requirements: 14.1, 14.2, 14.3_

- [ ] 16. Create main script entry point and documentation
  - [ ] 16.1 Create executable script file
    - Create migrate_shell_config.sh in appropriate location
    - Make script executable (chmod +x)
    - Add to PATH or create symlink
    - _Requirements: 1.1_
  
  - [ ] 16.2 Add inline documentation
    - Add function documentation comments
    - Add usage examples in help text
    - Document all command-line options
    - _Requirements: 9.1_
  
  - [ ] 16.3 Create user-facing documentation
    - Document migration workflow
    - Document rollback procedure
    - Document integration with installation
    - Provide troubleshooting guide
    - _Requirements: 8.4, 9.1_

- [ ] 17. Final checkpoint - End-to-end testing
  - Run full migration workflow with real shell config files
  - Test rollback functionality
  - Test dry-run mode
  - Test non-interactive mode
  - Verify all error messages are clear and actionable
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests should run minimum 100 iterations each
- The implementation uses bash scripting as specified in the design
- Atomic operations (backup before modify, write to temp then move) ensure safety
- The script should work on both Linux and macOS
- All user-facing output should be clear, colored, and actionable
