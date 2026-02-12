# Implementation Plan: Issues Service Integration

## Overview

This implementation plan breaks down the integration of bugwarrior as an "issues" service into the Workwarrior ecosystem. The implementation follows established patterns from existing services (journals, tasks, times, ledgers) and integrates at multiple layers: shell functions, CLI dispatchers, configuration tools, and profile management.

## Tasks

- [x] 1. Add shell integration function i()
  - Add i() function to lib/shell-integration.sh following the pattern of j() and l()
  - Implement scope resolution using ww_resolve_scope
  - Handle "i custom" routing to configuration tool
  - Set bugwarrior environment variables (BUGWARRIORRC, BUGWARRIOR_TASKRC, BUGWARRIOR_TASKDATA)
  - Validate configuration file exists before executing bugwarrior
  - Provide helpful error messages for missing profile or configuration
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 3.3_

- [ ]* 1.1 Write property test for argument forwarding
  - **Property 1: Argument Forwarding**
  - **Validates: Requirements 1.2, 4.2**

- [ ]* 1.2 Write unit tests for i() function
  - Test with no active profile (error case)
  - Test with "custom" argument (routing)
  - Test with missing configuration (error case)
  - Test environment variable setting
  - _Requirements: 1.5_

- [x] 2. Register i() function in shell configuration
  - Add i() function stub to ensure_shell_functions() in lib/shell-integration.sh
  - Follow the pattern used for j(), l(), list(), task(), timew()
  - Function should delegate to full implementation in shell-integration.sh
  - _Requirements: 1.1_

- [x] 3. Create configuration tool script
  - [x] 3.1 Create services/custom/configure-issues.sh
    - Set up script structure with shebang and core-utils sourcing
    - Add service metadata comments (Service, Category, Description)
    - Implement check_active_profile() function
    - Implement show_banner() function
    - _Requirements: 2.1, 2.2_

  - [x] 3.2 Implement main configuration menu
    - Create show_main_menu() function with options:
      1. Add/configure external service
      2. List configured services
      3. Remove service
      4. Generate/update UDAs
      5. Test connection
      6. View current configuration
      7. Exit
    - _Requirements: 2.2_

  - [x] 3.3 Implement service configuration functions
    - Create configure_service() function with service selection menu
    - Implement service templates for GitHub, GitLab, Jira, Trello
    - Add generic template for other services
    - Prompt for service-specific credentials and settings
    - Store configuration in bugwarriorrc (INI format)
    - _Requirements: 2.3, 2.4, 2.7, 3.2_

  - [x] 3.4 Implement credential security features
    - Display warning about plain text credentials
    - Offer secure storage options (keyring, password prompt, external manager)
    - Provide examples of @oracle syntax
    - Set restrictive file permissions (600) on bugwarriorrc
    - _Requirements: 2.8, 2.9, 12.1, 12.2, 12.3, 12.4, 12.5, 12.6_

  - [x] 3.5 Implement UDA management functions
    - Create generate_udas() function that executes "bugwarrior uda"
    - Implement parse_udas() to extract UDA definitions from output
    - Create append_udas_to_taskrc() with duplicate detection
    - Ensure atomic file operations to prevent corruption
    - _Requirements: 2.5, 2.6, 6.1, 6.2, 6.3, 6.4, 6.5_

  - [ ]* 3.6 Write property test for UDA generation
    - **Property 3: UDA Generation and Appending**
    - **Validates: Requirements 2.5, 2.6, 6.1, 6.2, 6.3, 6.4**

  - [ ]* 3.7 Write property test for multi-service UDAs
    - **Property 4: Multi-Service UDA Generation**
    - **Validates: Requirements 6.5, 10.1**

  - [x] 3.8 Implement service listing and removal
    - Create list_services() to display configured services
    - Create remove_service() to remove service from configuration
    - Update UDAs when service is removed
    - _Requirements: 2.3_

  - [x] 3.9 Implement TOML format support
    - Add format detection based on file extension
    - Implement TOML configuration writing
    - Ensure both INI and TOML formats work
    - _Requirements: 2.7_

  - [ ]* 3.10 Write property test for configuration format support
    - **Property 5: Configuration Format Support**
    - **Validates: Requirements 2.7**

  - [ ]* 3.11 Write unit tests for configuration tool
    - Test configuration file creation (INI format)
    - Test configuration file creation (TOML format)
    - Test UDA generation for GitHub service
    - Test duplicate UDA prevention
    - Test credential security warning display
    - _Requirements: 2.4, 2.7, 2.9, 6.4_

- [x] 4. Integrate with CLI dispatchers
  - [x] 4.1 Update bin/ww dispatcher
    - Add "issues" case to cmd_custom() function
    - Route to services/custom/configure-issues.sh
    - Update help text to include issues service
    - Update custom list output to include issues
    - _Requirements: 4.1, 4.2, 4.4_

  - [x] 4.2 Update bin/custom dispatcher
    - Add "issues" case to main() function
    - Route to services/custom/configure-issues.sh
    - Update help text to include issues service
    - Update list output to include issues
    - _Requirements: 4.3, 4.4_

  - [ ]* 4.3 Write unit tests for CLI routing
    - Test "ww i" command routing
    - Test "ww i custom" command routing
    - Test "custom issues" command routing
    - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [x] 5. Update shortcuts registry
  - Add "i" shortcut to config/shortcuts.yaml
  - Set name: "Issues (Bugwarrior)"
  - Set category: function
  - Set description: "Issue synchronization"
  - Set command: "i"
  - Set requires_profile: true
  - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [ ]* 5.1 Write unit test for shortcuts registry
  - Test that "i" shortcut is documented
  - Test that shortcut has correct metadata
  - _Requirements: 5.1, 5.2_

- [x] 6. Integrate with profile creation
  - [x] 6.1 Update scripts/create-ww-profile.sh
    - Add .config/bugwarrior/ directory creation to create_profile_structure()
    - Create bugwarriorrc template with commented configuration
    - Add comment explaining how to configure: "Run 'i custom' to configure"
    - _Requirements: 3.1_

  - [ ]* 6.2 Write property test for profile isolation
    - **Property 6: Profile Isolation**
    - **Validates: Requirements 3.4**

  - [ ]* 6.3 Write property test for profile-aware configuration
    - **Property 7: Profile-Aware Configuration Selection**
    - **Validates: Requirements 3.3**

  - [ ]* 6.4 Write unit test for profile creation
    - Test .config/bugwarrior/ directory creation
    - Test bugwarriorrc template creation
    - _Requirements: 3.1_

- [x] 7. Add dependency management
  - [x] 7.1 Update dependency checker
    - Add check_bugwarrior() function to lib/dependency-installer.sh
    - Detect bugwarrior installation
    - Parse version from "bugwarrior --version"
    - Display installation instructions if missing
    - _Requirements: 7.1, 7.2, 7.3_

  - [x] 7.2 Implement version compatibility check
    - Compare detected version against minimum (1.8.0)
    - Display warning if version is too old
    - _Requirements: 7.4_

  - [ ]* 7.3 Write property test for version checking
    - **Property 10: Version Compatibility Check**
    - **Validates: Requirements 7.4**

  - [ ]* 7.4 Write unit tests for dependency checks
    - Test bugwarrior detection when installed
    - Test bugwarrior detection when missing
    - Test version compatibility check
    - _Requirements: 7.2, 7.3, 7.4_

- [x] 8. Implement error handling
  - [x] 8.1 Add error handling to i() function
    - Handle missing profile error
    - Handle missing configuration error
    - Handle missing bugwarrior error
    - Forward bugwarrior errors to stderr
    - Preserve bugwarrior exit codes
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

  - [ ]* 8.2 Write property test for error forwarding
    - **Property 8: Error Message Forwarding**
    - **Validates: Requirements 11.1, 11.4**

  - [ ]* 8.3 Write property test for data preservation
    - **Property 9: Data Preservation on Failure**
    - **Validates: Requirements 11.5**

  - [ ]* 8.4 Write unit tests for error handling
    - Test authentication failure error
    - Test network failure error
    - Test invalid configuration error
    - _Requirements: 11.2, 11.3, 11.4_

- [x] 9. Add user documentation and warnings
  - [x] 9.1 Add one-way sync warning to configuration tool
    - Display warning during initial configuration
    - Explain that external services are authoritative
    - Explain that TaskWarrior changes don't sync back
    - _Requirements: 8.1, 8.2, 8.3_

  - [x] 9.2 Add sync direction message to i pull
    - Display message indicating sync direction (external → TaskWarrior)
    - Show which services are being synced
    - _Requirements: 8.4_

  - [ ]* 9.3 Write unit tests for warning messages
    - Test one-way sync warning display
    - Test sync direction message display
    - _Requirements: 8.1, 8.4_

- [x] 10. Create bugwarriorrc template
  - Create resources/config-files/bugwarriorrc.template
  - Include commented examples for common services
  - Include credential security examples
  - Include UDA generation instructions
  - _Requirements: 2.3, 2.4_

- [x] 11. Update installation script
  - Update install.sh to call dependency checker for bugwarrior
  - Add bugwarrior to list of optional dependencies
  - Display installation instructions if missing
  - _Requirements: 7.1, 7.2, 7.3_

- [ ] 12. Checkpoint - Ensure all tests pass
  - Run all unit tests
  - Run all property tests
  - Verify shell integration works
  - Verify configuration tool works
  - Verify CLI routing works
  - Ask the user if questions arise

- [ ] 13. Integration testing
  - [ ]* 13.1 Write end-to-end workflow test
    - Create profile
    - Activate profile
    - Run i custom to configure GitHub service
    - Run i pull to sync issues (with mock)
    - Verify configuration files created
    - Verify UDAs added to .taskrc
    - _Requirements: 1.1, 1.2, 1.3, 2.2, 2.4, 2.5, 2.6, 3.1, 3.2, 3.3_

  - [ ]* 13.2 Write multi-service workflow test
    - Configure GitHub and GitLab services
    - Verify both configurations stored
    - Verify UDAs for both services generated
    - _Requirements: 6.5, 10.1_

  - [ ]* 13.3 Write profile switching workflow test
    - Configure different services in two profiles
    - Switch between profiles
    - Verify correct configuration used for each profile
    - Verify data isolation
    - _Requirements: 3.3, 3.4_

- [x] 14. Documentation
  - [x] 14.1 Create README for issues service
    - Document service purpose and features
    - Provide usage examples
    - Document supported external services
    - Document credential security options
    - Document UDA management
    - _Requirements: 2.3, 12.6_

  - [x] 14.2 Update main Workwarrior documentation
    - Add issues service to service list
    - Add i() function to shell integration documentation
    - Add examples to user guide
    - _Requirements: 5.3, 5.4_

  - [x] 14.3 Create troubleshooting guide
    - Document common errors and solutions
    - Document authentication issues
    - Document network issues
    - Document configuration issues
    - _Requirements: 11.2, 11.3, 11.4_

- [ ] 15. Final checkpoint - Complete verification
  - Run full test suite
  - Verify all requirements are met
  - Verify all documentation is complete
  - Test on clean installation
  - Ask the user if questions arise

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- Integration tests verify end-to-end workflows
- The implementation follows established Workwarrior patterns from existing services
- Bugwarrior is an external dependency that must be installed separately
- Configuration tool provides interactive setup for ease of use
- Shell integration provides convenient access via i() function
- Profile isolation ensures different projects can have different issue trackers
