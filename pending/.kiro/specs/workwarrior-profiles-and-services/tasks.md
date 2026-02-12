# Implementation Plan: Workwarrior Profiles System and Services Registry

## Overview

This implementation plan breaks down the Workwarrior Profiles System and Services Registry into discrete, testable tasks. The approach follows an incremental development strategy, building core functionality first, then adding services and extensibility features. Each task includes specific requirements references and builds upon previous work.

## Tasks

- [x] 1. Set up project structure and core utilities
  - Create directory structure for services, resources, and functions
  - Implement logging utilities (log_info, log_success, log_warning, log_error)
  - Implement profile name validation function
  - Create constants for standard paths (PROFILES_DIR, SERVICES_DIR, etc.)
  - _Requirements: 2.2, 2.3, 18.1, 18.2, 18.3, 18.4_

- [x] 1.1 Write property test for profile name validation
  - **Property 2: Profile Name Validation**
  - **Validates: Requirements 2.2**

- [x] 2. Implement core profile directory structure creation
  - [x] 2.1 Implement create_profile_directories function
    - Create profile base directory
    - Create .task, .task/hooks, .timewarrior, journals, ledgers subdirectories
    - Ensure parent directories exist (mkdir -p behavior)
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.9, 1.10_

  - [x] 2.2 Write property test for directory structure creation
    - **Property 1: Complete Directory Structure Creation**
    - **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.9, 1.10**

- [x] 3. Implement TaskWarrior configuration management
  - [x] 3.1 Implement create_taskrc function
    - Copy from template or create minimal default
    - Update data.location to profile's .task directory
    - Update hooks.location to profile's .task/hooks directory
    - Set hooks=1
    - Ensure absolute paths are used
    - _Requirements: 6.1, 6.2, 6.3, 6.9, 6.10_

  - [x] 3.2 Implement copy_taskrc_from_profile function
    - Copy .taskrc from source profile
    - Update data.location and hooks.location paths
    - Preserve UDAs, reports, and urgency coefficients
    - _Requirements: 6.4, 6.5, 6.6, 6.7, 6.8_

  - [x] 3.3 Write property test for TaskRC path configuration
    - **Property 15: TaskRC Path Configuration**
    - **Validates: Requirements 6.1, 6.2, 6.3, 6.10**

  - [x] 3.4 Write property test for TaskRC copy path update
    - **Property 16: TaskRC Copy Path Update**
    - **Validates: Requirements 6.4, 6.5, 6.6, 6.7, 6.8**

- [x] 4. Implement TimeWarrior hook installation
  - [x] 4.1 Implement install_timewarrior_hook function
    - Copy hook from services/profile/on-modify.timewarrior if exists
    - Create basic Python hook script if template doesn't exist
    - Make hook executable (chmod +x)
    - Ensure hook uses TIMEWARRIORDB environment variable
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.10_

  - [x] 4.2 Write property test for hook installation
    - **Property 17: TimeWarrior Hook Installation**
    - **Validates: Requirements 7.1, 7.2, 7.3, 7.4**

  - [x] 4.3 Write property test for hook environment variable usage
    - **Property 18: Hook Environment Variable Usage**
    - **Validates: Requirements 7.10**

- [x] 5. Checkpoint - Verify core profile structure
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement journal management
  - [x] 6.1 Implement create_journal_config function
    - Create default journal file with welcome entry and timestamp
    - Generate jrnl.yaml with default journal configuration
    - Set editor, timeformat, encryption, and display options
    - Support multiple named journals in configuration
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_

  - [x] 6.2 Implement add_journal_to_profile function
    - Create new journal file
    - Update jrnl.yaml with new journal entry
    - Validate journal name doesn't already exist
    - _Requirements: 8.16, 8.17_

  - [x] 6.3 Implement copy_journal_from_profile function
    - Copy journal text file from source profile
    - Update file paths in jrnl.yaml
    - _Requirements: 8.7, 8.8_

  - [x] 6.4 Write property test for journal system initialization
    - **Property 19: Journal System Initialization**
    - **Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.5**

  - [x] 6.5 Write property test for multiple journals support
    - **Property 20: Multiple Journals Support**
    - **Validates: Requirements 8.6**

  - [x] 6.6 Write property test for journal addition
    - **Property 23: Journal Addition**
    - **Validates: Requirements 8.16, 8.17**

- [x] 7. Implement ledger management
  - [x] 7.1 Implement create_ledger_config function
    - Create default ledger file with account declarations and opening entry
    - Generate ledgers.yaml with default ledger configuration
    - Ensure default ledger is named after profile
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.10_

  - [x] 7.2 Implement copy_ledger_from_profile function
    - Copy ledger journal file from source profile
    - Update file paths in ledgers.yaml
    - _Requirements: 9.5_

  - [x] 7.3 Write property test for ledger system initialization
    - **Property 24: Ledger System Initialization**
    - **Validates: Requirements 9.1, 9.2, 9.3, 9.4**

  - [x] 7.4 Write property test for ledger naming convention
    - **Property 25: Ledger Naming Convention**
    - **Validates: Requirements 9.10**

- [x] 8. Implement shell alias management
  - [x] 8.1 Implement add_alias_to_section function
    - Check if alias already exists (prevent duplicates)
    - Ensure section marker exists in ~/.bashrc
    - Add alias after section marker
    - Use awk for precise insertion
    - _Requirements: 4.5, 4.6, 17.1, 17.2, 17.3, 17.4, 17.5, 17.6, 17.7, 17.8, 17.9, 17.10_

  - [x] 8.2 Implement create_profile_aliases function
    - Create p-<profile-name> alias
    - Create <profile-name> alias
    - Create j-<profile-name> alias
    - Create l-<ledger-name> aliases for each ledger
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 8.9, 9.6, 9.7_

  - [x] 8.3 Implement remove_profile_aliases function
    - Remove all aliases associated with a profile
    - Use sed to delete matching lines from ~/.bashrc
    - _Requirements: 3.4_

  - [x] 8.4 Write property test for complete alias creation
    - **Property 8: Complete Alias Creation**
    - **Validates: Requirements 4.1, 4.2, 4.3, 4.4**

  - [x] 8.5 Write property test for alias section organization
    - **Property 9: Alias Section Organization**
    - **Validates: Requirements 4.5**

  - [x] 8.6 Write property test for alias idempotence
    - **Property 10: Alias Idempotence**
    - **Validates: Requirements 4.6**

  - [x] 8.7 Write property test for ledger alias creation
    - **Property 26: Ledger Alias Creation**
    - **Validates: Requirements 9.6, 9.7**

- [x] 9. Implement global shell functions
  - [x] 9.1 Implement use_task_profile function
    - Validate profile exists
    - Export WARRIOR_PROFILE environment variable
    - Export WORKWARRIOR_BASE environment variable
    - Export TASKRC environment variable
    - Export TASKDATA environment variable
    - Export TIMEWARRIORDB environment variable
    - Display confirmation message
    - Handle non-existent profiles with error message
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8_

  - [x] 9.2 Implement global j function
    - Check WORKWARRIOR_BASE is set
    - Parse arguments to detect journal name
    - If first arg is journal name, use named journal
    - If no journal name, use default journal
    - Validate journal exists in jrnl.yaml
    - Execute jrnl with --config-file flag
    - Display error if no profile active
    - Display error with available journals if journal not found
    - _Requirements: 4.7, 8.10, 8.11, 8.12, 8.13, 8.14, 8.15, 8.18_

  - [x] 9.3 Implement global l function
    - Check WORKWARRIOR_BASE is set
    - Use profile's default ledger
    - Execute hledger with -f flag
    - Display error if no profile active
    - _Requirements: 4.8, 9.8, 9.9_

  - [x] 9.4 Implement ensure_shell_functions function
    - Check if functions exist in ~/.bashrc
    - Add functions to "# --- Workwarrior Core Functions ---" section
    - Prevent duplicate function definitions
    - _Requirements: 17.5_

  - [x] 9.5 Write property test for global function error handling
    - **Property 11: Global Function Error Handling**
    - **Validates: Requirements 4.10, 8.18, 9.9**

  - [x] 9.6 Write property test for complete environment variable export
    - **Property 12: Complete Environment Variable Export**
    - **Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5**

  - [x] 9.7 Write property test for invalid profile activation error
    - **Property 13: Invalid Profile Activation Error**
    - **Validates: Requirements 5.8**

  - [x] 9.8 Write property test for profile switching updates environment
    - **Property 14: Profile Switching Updates Environment**
    - **Validates: Requirements 5.9**

  - [x] 9.9 Write property test for journal routing by name
    - **Property 21: Journal Routing by Name**
    - **Validates: Requirements 8.11, 8.12, 8.13, 8.14**

  - [x] 9.10 Write property test for invalid journal name error
    - **Property 22: Invalid Journal Name Error**
    - **Validates: Requirements 8.15**

- [x] 10. Checkpoint - Verify shell integration
  - Ensure all tests pass, ask the user if questions arise.

- [x] 11. Implement profile creation script (create-ww-profile.sh)
  - [x] 11.1 Implement main profile creation flow
    - Parse command-line arguments
    - Validate profile name
    - Check if profile already exists
    - Prompt for customization options (TaskRC, JRNL, Ledger sources)
    - Call create_profile_directories
    - Call create_taskrc or copy_taskrc_from_profile
    - Call create_journal_config or copy_journal_from_profile
    - Call create_ledger_config or copy_ledger_from_profile
    - Call install_timewarrior_hook
    - Call create_profile_aliases
    - Call ensure_shell_functions
    - Display success message with usage instructions
    - _Requirements: 2.1, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10_

  - [x] 11.2 Write property test for default configuration initialization
    - **Property 3: Default Configuration Initialization**
    - **Validates: Requirements 2.9, 2.10**

- [x] 12. Implement profile management script (manage-profiles.sh)
  - [x] 12.1 Implement list_profiles command
    - Scan profiles directory
    - Return sorted list of profile names
    - _Requirements: 3.1, 3.9_

  - [x] 12.2 Implement delete_profile command
    - Validate profile name
    - Check profile exists
    - Remove profile directory and contents
    - Remove aliases from ~/.bashrc
    - Display success message
    - _Requirements: 3.2, 3.3, 3.4_

  - [x] 12.3 Implement info_profile command
    - Display profile name, location, disk usage
    - Show task count, journal count, ledger count
    - _Requirements: 3.5_

  - [x] 12.4 Implement backup_profile command
    - Validate profile name and exists
    - Create tar.gz archive with timestamp in filename
    - Include all directories and configuration files
    - Allow specifying destination directory
    - Display backup file path and size
    - _Requirements: 3.6, 3.7, 3.8, 20.1, 20.2, 20.3, 20.4, 20.5, 20.6, 20.7, 20.8, 20.9_

  - [x] 12.5 Implement command dispatcher and help
    - Parse command-line arguments
    - Route to appropriate command function
    - Display usage help for invalid arguments
    - Return appropriate exit codes
    - _Requirements: 3.10, 15.1, 15.2, 15.3, 15.7, 22.1, 22.2_

  - [x] 12.6 Write property test for profile deletion completeness
    - **Property 4: Profile Deletion Completeness**
    - **Validates: Requirements 3.3, 3.4**

  - [x] 12.7 Write property test for backup filename timestamp
    - **Property 5: Backup Filename Timestamp**
    - **Validates: Requirements 3.7**

  - [x] 12.8 Write property test for profile list sorting
    - **Property 6: Profile List Sorting**
    - **Validates: Requirements 3.9**

  - [x] 12.9 Write property test for error exit codes
    - **Property 7: Error Exit Codes**
    - **Validates: Requirements 3.10**

  - [x] 12.10 Write property test for backup completeness
    - **Property 32: Backup Completeness**
    - **Validates: Requirements 20.1, 20.2, 20.3, 20.4, 20.5**

- [x] 13. Checkpoint - Verify profile management
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 14. Implement service registry infrastructure
  - [x] 14.1 Create services directory structure
    - Create category directories (profile, questions, scripts, export, diagnostic, find, verify, custom)
    - Document service organization in README
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9, 10.10_

  - [x] 14.2 Implement service discovery functions
    - Implement discover_services function to scan service directories
    - Implement get_service_path function with profile override support
    - Implement service_exists function
    - Support global and profile-specific service locations
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7, 11.8, 11.9, 14.1, 14.2, 14.3, 14.4, 14.5_

  - [ ] 14.3 Write property test for profile-specific service override
    - **Property 27: Profile-Specific Service Override**
    - **Validates: Requirements 11.3, 11.4**

  - [ ] 14.4 Write property test for service discovery
    - **Property 28: Service Discovery**
    - **Validates: Requirements 14.1, 14.2, 14.3, 14.4, 14.5**

- [ ] 15. Implement questions service
  - [ ] 15.1 Implement q function main interface
    - Parse command-line arguments
    - Display help menu when called without arguments
    - Route to appropriate subcommand
    - Check for active profile
    - Create questions directory structure if needed
    - _Requirements: 12.1, 12.2, 12.3_

  - [ ] 15.2 Implement template creation (q new)
    - Prompt for template name, display name, description
    - Collect questions interactively
    - Generate JSON template file
    - Save to appropriate service category directory
    - _Requirements: 12.6, 12.7, 12.8_

  - [ ] 15.3 Implement template listing (q list, q <service>)
    - Scan templates directory for service category
    - Display available templates
    - Show template names and descriptions
    - _Requirements: 12.4, 12.9_

  - [ ] 15.4 Implement template usage (q <service> <template>)
    - Load template JSON file
    - Prompt for answers to all questions
    - Validate required fields
    - Save answers to temporary JSON file
    - Call service handler with template and answers
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.8_

  - [ ] 15.5 Implement handler execution
    - Check if handler exists for service
    - Create basic handler template if missing
    - Make handler executable
    - Execute handler with template and answers files
    - Display success or error message
    - _Requirements: 13.5, 13.6, 13.7, 13.9, 13.10_

  - [ ] 15.6 Implement template editing and deletion (q edit, q delete)
    - Locate template file
    - Open in editor or delete file
    - Update jrnl.yaml if needed
    - _Requirements: 12.9_

- [ ] 16. Implement configuration management utilities
  - [ ] 16.1 Implement configuration template management
    - Store default templates in resources/config-files
    - Implement load_template function
    - Implement save_template function
    - _Requirements: 16.1, 16.2, 16.3, 16.4_

  - [ ] 16.2 Implement configuration path updating
    - Implement update_paths_in_config function
    - Parse configuration files (taskrc, yaml)
    - Replace absolute paths with new profile paths
    - Preserve all other settings
    - _Requirements: 16.5, 16.6, 16.7_

  - [ ] 16.3 Implement configuration validation
    - Implement validate_taskrc function
    - Implement validate_jrnl_config function
    - Implement validate_ledger_config function
    - Check required fields and syntax
    - _Requirements: 16.8, 18.4_

  - [ ] 16.4 Write property test for configuration path updates
    - **Property 29: Configuration Path Updates**
    - **Validates: Requirements 16.5, 16.6, 16.7**

- [ ] 17. Implement data isolation verification
  - [ ] 17.1 Write property test for data isolation
    - **Property 30: Data Isolation**
    - **Validates: Requirements 19.1, 19.2, 19.3, 19.4, 19.5, 19.6, 19.7**

  - [ ] 17.2 Write property test for environment variable atomic update
    - **Property 31: Environment Variable Atomic Update**
    - **Validates: Requirements 19.8**

- [ ] 18. Implement backup portability verification
  - [ ] 18.1 Write property test for backup portability
    - **Property 33: Backup Portability**
    - **Validates: Requirements 20.10**

- [ ] 19. Create documentation
  - [ ] 19.1 Create main README.md
    - Document system overview and architecture
    - Explain profile concept and benefits
    - Provide installation instructions
    - Include quick start guide
    - Document environment variables
    - _Requirements: 22.6, 22.9, 22.10_

  - [ ] 19.2 Create service development guide
    - Document service structure and organization
    - Explain service discovery mechanism
    - Provide service template examples
    - Document handler interface
    - Include best practices
    - _Requirements: 21.7, 21.8, 21.9, 21.10_

  - [ ] 19.3 Create usage examples
    - Document profile creation examples
    - Show customization workflows
    - Demonstrate journal and ledger usage
    - Provide questions service examples
    - _Requirements: 22.8_

  - [ ] 19.4 Create service-specific README files
    - Document each service category
    - Explain available services
    - Provide usage examples
    - _Requirements: 22.7_

- [ ] 20. Final checkpoint - Integration testing
  - Run full integration test suite
  - Verify all property tests pass
  - Test profile creation, activation, switching, deletion
  - Test journal and ledger operations
  - Test questions service workflow
  - Test backup and restore
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional property-based tests and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at logical breakpoints
- Property tests validate universal correctness properties across random inputs
- Unit tests validate specific examples and edge cases
- The implementation follows a bottom-up approach: utilities → core → shell integration → services → documentation
- All shell scripts should use `set -e` for fail-fast behavior
- All functions should validate inputs before performing operations
- All operations should provide clear error messages with context
