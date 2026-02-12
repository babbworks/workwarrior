# Requirements Document: Workwarrior Profiles System and Services Registry

## Introduction

The Workwarrior Profiles System and Services Registry provides a comprehensive framework for managing multiple productivity profiles, each integrating TaskWarrior (task management), TimeWarrior (time tracking), JRNL (journaling), and Hledger (financial tracking). The system enables users to maintain isolated work contexts with dedicated configurations, data stores, and service extensions while providing seamless shell integration and profile switching capabilities.

## Glossary

- **Profile**: An isolated workspace containing TaskWarrior, TimeWarrior, JRNL, and Hledger configurations and data
- **Profile_Manager**: The system component responsible for profile lifecycle operations
- **Service**: An extensible module that provides additional functionality to profiles
- **Service_Registry**: The system component that manages service discovery and organization
- **Shell_Integration**: The bash/shell environment setup that provides aliases and functions
- **TASKRC**: TaskWarrior configuration file
- **TASKDATA**: TaskWarrior data directory containing tasks database
- **TIMEWARRIORDB**: TimeWarrior data directory containing time tracking database
- **Profile_Base**: The root directory path for a profile (e.g., ~/ww/profiles/profile-name)
- **Hook**: An executable script that integrates TaskWarrior with TimeWarrior
- **Alias**: A shell command shortcut for accessing profile-specific tools
- **Global_Function**: A shell function that operates on the currently active profile

## Requirements

### Requirement 1: Profile Structure and Organization

**User Story:** As a user, I want each profile to maintain isolated configurations and data for all productivity tools, so that I can keep different work contexts completely separate.

#### Acceptance Criteria

1. WHEN a profile is created, THE Profile_Manager SHALL create a directory structure at ~/ww/profiles/<profile-name>
2. THE Profile_Manager SHALL create a .task directory within each profile for TaskWarrior data storage
3. THE Profile_Manager SHALL create a .timewarrior directory within each profile for TimeWarrior data storage
4. THE Profile_Manager SHALL create a journals directory within each profile for JRNL text files
5. THE Profile_Manager SHALL create a ledgers directory within each profile for Hledger journal files
6. THE Profile_Manager SHALL create a .taskrc file within each profile for TaskWarrior configuration
7. THE Profile_Manager SHALL create a jrnl.yaml file within each profile for JRNL configuration
8. THE Profile_Manager SHALL create a ledgers.yaml file within each profile for Hledger configuration
9. THE Profile_Manager SHALL create a .task/hooks directory within each profile for TaskWarrior hook scripts
10. WHEN a profile directory is created, THE Profile_Manager SHALL ensure all parent directories exist

### Requirement 2: Profile Creation and Customization

**User Story:** As a user, I want to create new profiles with customization options, so that I can quickly set up profiles based on existing configurations or templates.

#### Acceptance Criteria

1. WHEN creating a profile, THE Profile_Manager SHALL accept a profile name as input
2. WHEN a profile name contains invalid characters, THE Profile_Manager SHALL reject the name and return an error
3. WHEN a profile name exceeds 50 characters, THE Profile_Manager SHALL reject the name and return an error
4. WHEN a profile already exists with the given name, THE Profile_Manager SHALL prompt the user for confirmation before overwriting
5. WHEN creating a profile, THE Profile_Manager SHALL offer to copy TaskRC configuration from an existing profile
6. WHEN creating a profile, THE Profile_Manager SHALL offer to copy JRNL configuration from an existing profile
7. WHEN creating a profile, THE Profile_Manager SHALL offer to copy Hledger configuration from an existing profile
8. WHEN creating a profile, THE Profile_Manager SHALL offer to use a custom configuration file from an arbitrary path
9. WHEN no custom configuration is specified, THE Profile_Manager SHALL use default templates for all configuration files
10. WHEN a profile is created, THE Profile_Manager SHALL initialize default journal and ledger files with welcome entries

### Requirement 3: Profile Lifecycle Management

**User Story:** As a user, I want to perform CRUD operations on profiles, so that I can manage my workspace configurations throughout their lifecycle.

#### Acceptance Criteria

1. THE Profile_Manager SHALL provide a command to list all existing profiles
2. THE Profile_Manager SHALL provide a command to delete a profile by name
3. WHEN deleting a profile, THE Profile_Manager SHALL remove the profile directory and all its contents
4. WHEN deleting a profile, THE Profile_Manager SHALL remove associated shell aliases from the shell configuration file
5. THE Profile_Manager SHALL provide a command to display profile information including location and disk usage
6. THE Profile_Manager SHALL provide a command to backup a profile to a tar.gz archive
7. WHEN backing up a profile, THE Profile_Manager SHALL include a timestamp in the backup filename
8. WHEN backing up a profile, THE Profile_Manager SHALL allow specifying a destination directory
9. WHEN listing profiles, THE Profile_Manager SHALL display profile names in sorted order
10. WHEN a profile operation fails, THE Profile_Manager SHALL return a non-zero exit code and display an error message

### Requirement 4: Shell Integration and Aliases

**User Story:** As a user, I want shell aliases and functions automatically configured, so that I can quickly access profile-specific tools without typing long commands.

#### Acceptance Criteria

1. WHEN a profile is created, THE Shell_Integration SHALL add a profile activation alias p-<profile-name> to ~/.bashrc
2. WHEN a profile is created, THE Shell_Integration SHALL add a shorthand profile alias <profile-name> to ~/.bashrc
3. WHEN a profile is created, THE Shell_Integration SHALL add a journal alias j-<profile-name> to ~/.bashrc
4. WHEN a profile is created, THE Shell_Integration SHALL add ledger aliases l-<ledger-name> to ~/.bashrc for each ledger
5. THE Shell_Integration SHALL ensure aliases are added to appropriate section markers in ~/.bashrc
6. THE Shell_Integration SHALL prevent duplicate aliases from being added to ~/.bashrc
7. THE Shell_Integration SHALL provide a global j function that operates on the active profile's journal
8. THE Shell_Integration SHALL provide a global l function that operates on the active profile's default ledger
9. THE Shell_Integration SHALL provide a use_task_profile function that activates a profile by name
10. WHEN no profile is active, THE Shell_Integration SHALL display an error message when global functions are called

### Requirement 5: Profile Activation and Environment

**User Story:** As a user, I want to activate a profile and have all environment variables automatically configured, so that all tools operate on the correct profile data.

#### Acceptance Criteria

1. WHEN a profile is activated, THE Shell_Integration SHALL export WARRIOR_PROFILE environment variable with the profile name
2. WHEN a profile is activated, THE Shell_Integration SHALL export WORKWARRIOR_BASE environment variable with the profile base path
3. WHEN a profile is activated, THE Shell_Integration SHALL export TASKRC environment variable pointing to the profile's .taskrc file
4. WHEN a profile is activated, THE Shell_Integration SHALL export TASKDATA environment variable pointing to the profile's .task directory
5. WHEN a profile is activated, THE Shell_Integration SHALL export TIMEWARRIORDB environment variable pointing to the profile's .timewarrior directory
6. WHEN a profile is activated, THE Shell_Integration SHALL display a confirmation message showing the active profile name
7. WHEN a profile is activated, THE Shell_Integration SHALL inform the user that global j and l commands are now available
8. WHEN activating a non-existent profile, THE Shell_Integration SHALL display an error message and return a non-zero exit code
9. WHEN switching between profiles, THE Shell_Integration SHALL update all environment variables to point to the new profile
10. THE Shell_Integration SHALL maintain profile activation state across function calls within the same shell session

### Requirement 6: TaskWarrior Configuration Management

**User Story:** As a user, I want TaskWarrior properly configured for each profile, so that tasks are stored in the correct location and hooks function properly.

#### Acceptance Criteria

1. WHEN a .taskrc file is created, THE Profile_Manager SHALL set data.location to point to the profile's .task directory
2. WHEN a .taskrc file is created, THE Profile_Manager SHALL set hooks.location to point to the profile's .task/hooks directory
3. WHEN a .taskrc file is created, THE Profile_Manager SHALL enable hooks by setting hooks=1
4. WHEN copying a .taskrc from another profile, THE Profile_Manager SHALL update data.location to the new profile's path
5. WHEN copying a .taskrc from another profile, THE Profile_Manager SHALL update hooks.location to the new profile's path
6. THE Profile_Manager SHALL preserve all User Defined Attributes (UDAs) when copying .taskrc files
7. THE Profile_Manager SHALL preserve report configurations when copying .taskrc files
8. THE Profile_Manager SHALL preserve urgency coefficients when copying .taskrc files
9. WHEN no template is available, THE Profile_Manager SHALL create a minimal .taskrc with basic configuration
10. THE Profile_Manager SHALL ensure .taskrc files use absolute paths for data.location and hooks.location

### Requirement 7: TimeWarrior Integration

**User Story:** As a user, I want TaskWarrior automatically integrated with TimeWarrior, so that starting and stopping tasks automatically tracks time.

#### Acceptance Criteria

1. WHEN a profile is created, THE Profile_Manager SHALL install an on-modify.timewarrior hook in the .task/hooks directory
2. THE Profile_Manager SHALL make the on-modify.timewarrior hook executable
3. WHEN an on-modify.timewarrior hook template exists in services/profile, THE Profile_Manager SHALL copy it to the profile
4. WHEN no hook template exists, THE Profile_Manager SHALL create a basic Python hook script
5. THE on-modify.timewarrior hook SHALL receive task modification data from TaskWarrior via stdin
6. THE on-modify.timewarrior hook SHALL parse JSON task data from TaskWarrior
7. THE on-modify.timewarrior hook SHALL output modified task data to stdout for TaskWarrior
8. WHEN a task is started in TaskWarrior, THE on-modify.timewarrior hook SHALL start time tracking in TimeWarrior
9. WHEN a task is stopped in TaskWarrior, THE on-modify.timewarrior hook SHALL stop time tracking in TimeWarrior
10. THE on-modify.timewarrior hook SHALL use the TIMEWARRIORDB environment variable to locate TimeWarrior data

### Requirement 8: Journal Management

**User Story:** As a user, I want to maintain multiple journals within a profile, so that I can organize notes by topic or purpose.

#### Acceptance Criteria

1. WHEN a profile is created, THE Profile_Manager SHALL create a default journal file at journals/<profile-name>.txt
2. WHEN a profile is created, THE Profile_Manager SHALL initialize the default journal with a welcome entry and timestamp
3. THE Profile_Manager SHALL create a jrnl.yaml configuration file mapping journal names to file paths
4. THE jrnl.yaml file SHALL specify the default journal location
5. THE jrnl.yaml file SHALL specify editor, encryption, time format, and display options
6. THE jrnl.yaml file SHALL support multiple named journals within a single profile
7. WHEN copying a journal from another profile, THE Profile_Manager SHALL copy the journal text file
8. WHEN copying a journal from another profile, THE Profile_Manager SHALL update file paths in jrnl.yaml
9. THE Shell_Integration SHALL create a j-<profile-name> alias that uses the profile's jrnl.yaml configuration
10. WHEN the global j function is called, THE Shell_Integration SHALL use the active profile's jrnl.yaml configuration
11. WHEN the global j function is called with a journal name as first argument, THE Shell_Integration SHALL write to that named journal
12. WHEN the global j function is called without a journal name, THE Shell_Integration SHALL write to the default journal
13. THE global j function SHALL support the syntax "j <journal-name> <entry>" for writing to named journals
14. THE global j function SHALL support the syntax "j <entry>" for writing to the default journal
15. WHEN a named journal does not exist in jrnl.yaml, THE global j function SHALL display an error listing available journals
16. THE Profile_Manager SHALL provide a command to add new journals to an existing profile
17. WHEN adding a new journal, THE Profile_Manager SHALL create the journal file and update jrnl.yaml
18. WHEN no profile is active, THE global j function SHALL display an error message

### Requirement 9: Ledger Management

**User Story:** As a user, I want to maintain multiple financial ledgers within a profile, so that I can track different accounts or categories separately.

#### Acceptance Criteria

1. WHEN a profile is created, THE Profile_Manager SHALL create a default ledger file at ledgers/<profile-name>.journal
2. WHEN a profile is created, THE Profile_Manager SHALL initialize the default ledger with account declarations and an opening entry
3. THE Profile_Manager SHALL create a ledgers.yaml configuration file mapping ledger names to file paths
4. THE ledgers.yaml file SHALL list all ledgers with their file paths
5. WHEN copying a ledger from another profile, THE Profile_Manager SHALL copy the journal file
6. THE Shell_Integration SHALL create an l-<ledger-name> alias for each ledger in the profile
7. WHEN a ledger name differs from the profile name, THE Shell_Integration SHALL create an l-<profile-name>-<ledger-name> alias
8. WHEN the global l function is called, THE Shell_Integration SHALL use the active profile's default ledger
9. WHEN no profile is active, THE global l function SHALL display an error message
10. THE default ledger file SHALL be named after the profile name

### Requirement 10: Services Directory Structure

**User Story:** As a system architect, I want services organized in a clear directory structure, so that services are discoverable and maintainable.

#### Acceptance Criteria

1. THE Service_Registry SHALL maintain a services directory at ~/ww/services
2. THE Service_Registry SHALL organize services into category subdirectories
3. THE Service_Registry SHALL provide a profile category for profile management services
4. THE Service_Registry SHALL provide a questions category for inquiry management services
5. THE Service_Registry SHALL provide a scripts category for utility scripts
6. THE Service_Registry SHALL provide an export category for data export services
7. THE Service_Registry SHALL provide a diagnostic category for system diagnostic services
8. THE Service_Registry SHALL provide a find category for search and discovery services
9. THE Service_Registry SHALL provide a verify category for validation services
10. THE Service_Registry SHALL allow services to contain subdirectories for organization

### Requirement 11: Profile-Specific Services

**User Story:** As a user, I want to extend profiles with profile-specific services, so that I can add custom functionality to individual profiles without affecting others.

#### Acceptance Criteria

1. THE Service_Registry SHALL support a services directory within each profile at <profile-base>/services
2. WHEN a profile-specific service is accessed, THE Service_Registry SHALL check the active profile's services directory
3. THE Service_Registry SHALL allow profile-specific services to override global services
4. WHEN a service exists both globally and in a profile, THE Service_Registry SHALL use the profile-specific version
5. THE Service_Registry SHALL maintain the same directory structure for profile-specific services as global services
6. WHEN no profile is active, THE Service_Registry SHALL only access global services
7. THE Service_Registry SHALL allow services to access the WORKWARRIOR_BASE environment variable
8. THE Service_Registry SHALL allow services to access profile configuration files
9. THE Service_Registry SHALL allow services to create subdirectories within the profile's services directory
10. THE Service_Registry SHALL preserve profile-specific services during profile backup operations

### Requirement 12: Questions Service

**User Story:** As a user, I want to use templated question workflows, so that I can consistently capture structured information for tasks, journals, and other tools.

#### Acceptance Criteria

1. THE Questions_Service SHALL provide a q function accessible from the shell
2. WHEN no profile is active, THE Questions_Service SHALL display an error message
3. WHEN called without arguments, THE Questions_Service SHALL display a help menu listing available services
4. THE Questions_Service SHALL support question templates for task, journal, time, list, and ledger services
5. THE Questions_Service SHALL organize templates in a templates directory with subdirectories per service type
6. THE Questions_Service SHALL allow creating new templates interactively
7. WHEN creating a template, THE Questions_Service SHALL prompt for template name, display name, description, and questions
8. THE Questions_Service SHALL store templates as JSON files with question definitions
9. THE Questions_Service SHALL provide commands to list, edit, and delete templates
10. WHEN using a template, THE Questions_Service SHALL prompt for answers to all questions in sequence

### Requirement 13: Questions Service Template Processing

**User Story:** As a user, I want question templates to integrate with productivity tools, so that collected answers are automatically formatted and stored appropriately.

#### Acceptance Criteria

1. WHEN a template is used, THE Questions_Service SHALL collect answers for all required questions
2. WHEN a required question is left empty, THE Questions_Service SHALL re-prompt until an answer is provided
3. THE Questions_Service SHALL store collected answers in a temporary JSON file
4. THE Questions_Service SHALL call a service-specific handler script to process answers
5. WHEN a handler script does not exist, THE Questions_Service SHALL create a basic handler template
6. THE handler script SHALL receive the template file path and answers file path as arguments
7. THE handler script SHALL parse the answers JSON file
8. THE handler script SHALL format answers according to the target service requirements
9. THE handler script SHALL integrate formatted data with the appropriate tool (TaskWarrior, JRNL, etc.)
10. WHEN handler processing completes successfully, THE Questions_Service SHALL display a success message

### Requirement 14: Service Discovery and Registration

**User Story:** As a developer, I want services to be automatically discoverable, so that I can add new services without modifying core system code.

#### Acceptance Criteria

1. THE Service_Registry SHALL discover services by scanning the services directory structure
2. THE Service_Registry SHALL identify services by the presence of executable scripts or shell functions
3. THE Service_Registry SHALL support services implemented as bash scripts
4. THE Service_Registry SHALL support services implemented as shell functions
5. THE Service_Registry SHALL support services implemented as Python scripts
6. THE Service_Registry SHALL allow services to define dependencies on other services
7. THE Service_Registry SHALL allow services to access shared library functions
8. THE Service_Registry SHALL provide a mechanism for services to register themselves
9. THE Service_Registry SHALL maintain a list of available service categories
10. THE Service_Registry SHALL allow querying available services by category

### Requirement 15: Profile Management Service

**User Story:** As a user, I want a dedicated service for profile management operations, so that I can perform all profile-related tasks through a consistent interface.

#### Acceptance Criteria

1. THE Profile_Management_Service SHALL provide create-ww-profile.sh script for profile creation
2. THE Profile_Management_Service SHALL provide manage-profiles.sh script for profile operations
3. THE Profile_Management_Service SHALL support create, delete, list, info, and backup commands
4. THE Profile_Management_Service SHALL validate profile names before performing operations
5. THE Profile_Management_Service SHALL provide colored output for success, error, warning, and info messages
6. THE Profile_Management_Service SHALL log all profile operations
7. THE Profile_Management_Service SHALL provide usage help when called with invalid arguments
8. THE Profile_Management_Service SHALL store default configuration templates in a defaults subdirectory
9. THE Profile_Management_Service SHALL store the on-modify.timewarrior hook template in the profile service directory
10. THE Profile_Management_Service SHALL provide subservices for specialized profile operations

### Requirement 16: Configuration File Management

**User Story:** As a user, I want configuration files properly managed across profiles, so that I can maintain consistent settings and easily share configurations.

#### Acceptance Criteria

1. THE Profile_Manager SHALL maintain default configuration templates in ~/ww/resources/config-files
2. THE Profile_Manager SHALL maintain default .taskrc templates in ~/ww/functions/tasks/default-taskrc
3. THE Profile_Manager SHALL maintain default ledger account templates in ~/ww/functions/ledgers/defaultaccounts
4. WHEN creating a profile, THE Profile_Manager SHALL search for configuration templates in standard locations
5. WHEN copying configurations between profiles, THE Profile_Manager SHALL preserve all settings except paths
6. THE Profile_Manager SHALL update all absolute paths when copying configurations
7. THE Profile_Manager SHALL update all profile-specific references when copying configurations
8. THE Profile_Manager SHALL validate configuration files after creation or modification
9. THE Profile_Manager SHALL provide a mechanism to export a profile's configuration as a template
10. THE Profile_Manager SHALL allow importing configuration templates from external sources

### Requirement 17: Shell Configuration Management

**User Story:** As a user, I want shell configuration automatically managed, so that aliases and functions are properly organized and don't conflict.

#### Acceptance Criteria

1. THE Shell_Integration SHALL use section markers in ~/.bashrc to organize different types of aliases
2. THE Shell_Integration SHALL use "# -- Workwarrior Profile Aliases ---" section for profile activation aliases
3. THE Shell_Integration SHALL use "# -- Direct Alias for Journals ---" section for journal aliases
4. THE Shell_Integration SHALL use "# -- Direct Aliases for Hledger ---" section for ledger aliases
5. THE Shell_Integration SHALL use "# --- Workwarrior Core Functions ---" section for global functions
6. WHEN adding an alias, THE Shell_Integration SHALL check if the section marker exists
7. WHEN a section marker does not exist, THE Shell_Integration SHALL create it before adding aliases
8. WHEN adding an alias, THE Shell_Integration SHALL check if the alias already exists
9. WHEN an alias already exists, THE Shell_Integration SHALL skip adding it
10. THE Shell_Integration SHALL preserve existing shell configuration when adding new aliases

### Requirement 18: Error Handling and Validation

**User Story:** As a user, I want clear error messages and validation, so that I understand what went wrong and how to fix it.

#### Acceptance Criteria

1. WHEN a profile operation fails, THE Profile_Manager SHALL display a descriptive error message
2. WHEN a required directory cannot be created, THE Profile_Manager SHALL display the path and reason
3. WHEN a configuration file cannot be read, THE Profile_Manager SHALL display the file path and error
4. WHEN a profile name is invalid, THE Profile_Manager SHALL explain the naming requirements
5. WHEN a profile does not exist, THE Profile_Manager SHALL display the profile name and available profiles
6. WHEN environment variables are not set, THE Shell_Integration SHALL display which variables are missing
7. WHEN a service cannot be found, THE Service_Registry SHALL display the service name and search paths
8. WHEN a template file is malformed, THE Questions_Service SHALL display the file path and parsing error
9. WHEN a handler script fails, THE Questions_Service SHALL display the handler output and exit code
10. THE system SHALL use consistent error message formatting across all components

### Requirement 19: Data Isolation and Integrity

**User Story:** As a user, I want complete data isolation between profiles, so that operations on one profile never affect another profile's data.

#### Acceptance Criteria

1. WHEN a profile is active, THE system SHALL only read and write data within that profile's directory
2. WHEN TaskWarrior is invoked, THE system SHALL use the TASKRC and TASKDATA environment variables
3. WHEN TimeWarrior is invoked, THE system SHALL use the TIMEWARRIORDB environment variable
4. WHEN JRNL is invoked, THE system SHALL use the --config-file flag with the profile's jrnl.yaml
5. WHEN Hledger is invoked, THE system SHALL use the -f flag with the profile's ledger file
6. THE system SHALL prevent accidental cross-profile data access
7. THE system SHALL validate that environment variables point to the active profile before operations
8. WHEN switching profiles, THE system SHALL ensure all environment variables are updated atomically
9. THE system SHALL not maintain shared state between profiles
10. THE system SHALL ensure profile directories have appropriate file permissions

### Requirement 20: Backup and Recovery

**User Story:** As a user, I want to backup and restore profiles, so that I can protect my data and migrate profiles between systems.

#### Acceptance Criteria

1. WHEN backing up a profile, THE Profile_Manager SHALL create a compressed tar.gz archive
2. THE backup archive SHALL include all profile directories and files
3. THE backup archive SHALL include .taskrc, jrnl.yaml, and ledgers.yaml configuration files
4. THE backup archive SHALL include all task data, time tracking data, journals, and ledgers
5. THE backup archive SHALL include profile-specific services if they exist
6. THE backup filename SHALL include the profile name and timestamp
7. WHEN a backup destination is not specified, THE Profile_Manager SHALL use the user's home directory
8. THE Profile_Manager SHALL verify the backup archive was created successfully
9. THE Profile_Manager SHALL display the backup file path and size after creation
10. THE backup archive SHALL be portable and restorable on different systems

### Requirement 21: Extensibility and Plugin Architecture

**User Story:** As a developer, I want to extend the system with new services, so that I can add functionality without modifying core code.

#### Acceptance Criteria

1. THE Service_Registry SHALL allow adding new service categories by creating directories
2. THE Service_Registry SHALL allow adding new services by placing scripts in service directories
3. THE Service_Registry SHALL support services written in bash, Python, or other scripting languages
4. THE Service_Registry SHALL allow services to define configuration files
5. THE Service_Registry SHALL allow services to define templates
6. THE Service_Registry SHALL allow services to define handlers
7. THE Service_Registry SHALL provide a standard interface for service initialization
8. THE Service_Registry SHALL provide access to profile environment variables for all services
9. THE Service_Registry SHALL allow services to depend on other services
10. THE Service_Registry SHALL document the service development interface

### Requirement 22: Documentation and Help

**User Story:** As a user, I want comprehensive help and documentation, so that I can learn how to use the system effectively.

#### Acceptance Criteria

1. THE Profile_Manager SHALL display usage information when called with --help or invalid arguments
2. THE Profile_Manager SHALL display examples of common operations in help output
3. THE Questions_Service SHALL display available commands when called without arguments
4. THE Questions_Service SHALL display available templates when listing services
5. THE Shell_Integration SHALL provide inline documentation for global functions
6. THE system SHALL maintain a README.md file documenting the overall architecture
7. THE system SHALL maintain service-specific README files in each service directory
8. THE system SHALL provide examples of profile creation and customization
9. THE system SHALL document environment variables and their purposes
10. THE system SHALL document the directory structure and file organization
