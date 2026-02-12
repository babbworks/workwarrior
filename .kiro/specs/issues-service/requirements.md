# Requirements Document: Issues Service Integration

## Introduction

This document specifies the requirements for integrating bugwarrior as an "issues" service into the Workwarrior ecosystem. Bugwarrior is a command-line utility that synchronizes issues from 25+ external services (GitHub, GitLab, Jira, Trello, etc.) into TaskWarrior. This integration provides one-way, read-only synchronization where external issue trackers remain the authoritative source.

## Glossary

- **Bugwarrior**: Command-line utility that syncs issues from external services into TaskWarrior
- **Issues_Service**: The new Workwarrior service that wraps bugwarrior functionality
- **Profile**: An isolated workspace in Workwarrior with its own TaskWarrior database, TimeWarrior data, journals, and ledgers
- **UDA**: User Defined Attribute - custom fields in TaskWarrior for storing service-specific metadata
- **Shell_Integration**: Global shell functions that provide convenient access to Workwarrior services
- **Custom_Services_Dispatcher**: The bin/custom script that routes configuration commands
- **Main_CLI_Dispatcher**: The bin/ww script that routes all Workwarrior commands
- **Shortcuts_Registry**: The config/shortcuts.yaml file that defines all available commands
- **External_Service**: Third-party issue tracking systems (GitHub, GitLab, Jira, etc.)
- **Bugwarriorrc**: Configuration file for bugwarrior (INI or TOML format)
- **One_Way_Sync**: Synchronization pattern where data flows only from external services to TaskWarrior

## Requirements

### Requirement 1: Shell Integration

**User Story:** As a user, I want to use the "i" command to interact with the issues service, so that I can manage issue synchronization consistently with other Workwarrior services.

#### Acceptance Criteria

1. THE Shell_Integration SHALL provide a global function i() that wraps bugwarrior commands
2. WHEN a user invokes i() with arguments, THE Shell_Integration SHALL pass those arguments to bugwarrior with profile-aware context
3. WHEN a user invokes "i pull", THE Shell_Integration SHALL execute bugwarrior pull with the active profile's configuration
4. WHEN a user invokes "i custom", THE Shell_Integration SHALL launch the interactive configuration tool
5. WHEN no profile is active, THE Shell_Integration SHALL display an error message indicating profile activation is required

### Requirement 2: Configuration Management

**User Story:** As a user, I want an interactive configuration tool for bugwarrior, so that I can easily set up issue synchronization from multiple external services.

#### Acceptance Criteria

1. THE Issues_Service SHALL provide a configure-issues.sh script in services/custom/
2. WHEN a user runs "i custom", THE Issues_Service SHALL launch an interactive configuration interface
3. THE Issues_Service SHALL support configuration for all 25+ bugwarrior-supported external services
4. WHEN a user configures a service, THE Issues_Service SHALL store configuration in $WORKWARRIOR_BASE/.config/bugwarrior/bugwarriorrc
5. WHEN a user adds a new service configuration, THE Issues_Service SHALL generate required UDA definitions
6. WHEN UDA definitions are generated, THE Issues_Service SHALL append them to the active profile's .taskrc file
7. THE Issues_Service SHALL support both INI and TOML configuration formats
8. WHEN a user configures credentials, THE Issues_Service SHALL offer secure storage options (keyring, password prompt, external password manager)
9. THE Issues_Service SHALL warn users against storing credentials in plain text

### Requirement 3: Profile Integration

**User Story:** As a user, I want each profile to have its own bugwarrior configuration, so that I can sync different issue trackers for work and personal projects.

#### Acceptance Criteria

1. WHEN a new profile is created, THE Issues_Service SHALL create a .config/bugwarrior/ directory structure
2. THE Issues_Service SHALL store profile-specific configuration in $WORKWARRIOR_BASE/.config/bugwarrior/bugwarriorrc
3. WHEN a profile is activated, THE Shell_Integration SHALL use that profile's bugwarrior configuration
4. THE Issues_Service SHALL isolate bugwarrior data between different profiles

### Requirement 4: CLI Dispatcher Integration

**User Story:** As a user, I want the "i" command to be available through the main ww CLI, so that I can access issues functionality consistently with other services.

#### Acceptance Criteria

1. THE Main_CLI_Dispatcher SHALL recognize "i" as a valid service command
2. WHEN a user runs "ww i <args>", THE Main_CLI_Dispatcher SHALL route the command to the issues service
3. THE Custom_Services_Dispatcher SHALL recognize "i custom" commands
4. WHEN a user runs "ww i custom", THE Custom_Services_Dispatcher SHALL launch configure-issues.sh

### Requirement 5: Shortcuts Registry

**User Story:** As a user, I want the issues service documented in the shortcuts registry, so that I can discover available commands through help systems.

#### Acceptance Criteria

1. THE Shortcuts_Registry SHALL include an "issues" section with all available commands
2. THE Shortcuts_Registry SHALL document the "i" shortcut and its usage
3. THE Shortcuts_Registry SHALL list supported bugwarrior commands (pull, uda)
4. THE Shortcuts_Registry SHALL document the "i custom" configuration command

### Requirement 6: UDA Management

**User Story:** As a user, I want UDAs automatically generated and added to my TaskWarrior configuration, so that I can view service-specific metadata without manual configuration.

#### Acceptance Criteria

1. WHEN a user configures an external service, THE Issues_Service SHALL execute "bugwarrior uda" to generate UDA definitions
2. THE Issues_Service SHALL parse the generated UDA definitions
3. THE Issues_Service SHALL append UDA definitions to the active profile's .taskrc file
4. THE Issues_Service SHALL prevent duplicate UDA definitions when re-configuring services
5. WHEN multiple services are configured, THE Issues_Service SHALL generate UDAs for all configured services

### Requirement 7: Dependency Management

**User Story:** As a system administrator, I want bugwarrior checked during installation, so that users are notified if the required dependency is missing.

#### Acceptance Criteria

1. THE Issues_Service SHALL add bugwarrior to the dependency check list
2. WHEN install.sh runs, THE Issues_Service SHALL verify bugwarrior is installed
3. WHEN bugwarrior is missing, THE Issues_Service SHALL display installation instructions
4. THE Issues_Service SHALL verify bugwarrior version compatibility

### Requirement 8: One-Way Sync Enforcement

**User Story:** As a user, I want clear documentation that sync is read-only, so that I understand changes in TaskWarrior will not sync back to external services.

#### Acceptance Criteria

1. THE Issues_Service SHALL display a warning during initial configuration explaining one-way sync behavior
2. THE Issues_Service SHALL document that external services are authoritative
3. THE Issues_Service SHALL document that TaskWarrior changes do not propagate to external services
4. WHEN a user runs "i pull", THE Issues_Service SHALL display a message indicating sync direction (external → TaskWarrior)

### Requirement 9: Service-Specific Field Mapping

**User Story:** As a user, I want service-specific metadata preserved in TaskWarrior, so that I can view issue details like URLs, numbers, and states.

#### Acceptance Criteria

1. WHEN syncing GitHub issues, THE Issues_Service SHALL preserve fields like githubnumber, githuburl, githubstate, githubrepo
2. WHEN syncing GitLab issues, THE Issues_Service SHALL preserve GitLab-specific UDAs
3. WHEN syncing Jira issues, THE Issues_Service SHALL preserve Jira-specific UDAs
4. THE Issues_Service SHALL sync issue comments as TaskWarrior annotations
5. THE Issues_Service SHALL sync issue labels as TaskWarrior tags
6. THE Issues_Service SHALL support custom field mapping templates

### Requirement 10: Multi-Service Support

**User Story:** As a user, I want to sync from multiple issue trackers simultaneously, so that I can consolidate tasks from different projects into one TaskWarrior database.

#### Acceptance Criteria

1. THE Issues_Service SHALL support configuring multiple external services in a single profile
2. WHEN a user runs "i pull", THE Issues_Service SHALL sync from all configured services
3. THE Issues_Service SHALL tag tasks with service identifiers (e.g., +github, +jira)
4. WHEN conflicts occur between services, THE Issues_Service SHALL handle them according to bugwarrior's conflict resolution rules

### Requirement 11: Error Handling

**User Story:** As a user, I want clear error messages when sync fails, so that I can troubleshoot configuration or connectivity issues.

#### Acceptance Criteria

1. WHEN bugwarrior pull fails, THE Issues_Service SHALL display the error message from bugwarrior
2. WHEN authentication fails, THE Issues_Service SHALL indicate credential issues
3. WHEN network connectivity fails, THE Issues_Service SHALL indicate connection problems
4. WHEN configuration is invalid, THE Issues_Service SHALL indicate which configuration section has errors
5. THE Issues_Service SHALL preserve existing TaskWarrior data when sync fails

### Requirement 12: Security and Credential Management

**User Story:** As a user, I want secure credential storage options, so that I can protect my API tokens and passwords.

#### Acceptance Criteria

1. THE Issues_Service SHALL support keyring integration via @oracle:use_keyring syntax
2. THE Issues_Service SHALL support password prompts via @oracle:ask_password syntax
3. THE Issues_Service SHALL support external password managers via @oracle:eval syntax
4. WHEN a user enters credentials, THE Issues_Service SHALL offer to store them securely
5. THE Issues_Service SHALL display a warning when credentials would be stored in plain text
6. THE Issues_Service SHALL document credential storage options in the configuration tool
