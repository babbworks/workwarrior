# Requirements Document

## Introduction

The Shell Configuration Migration feature provides a safe, automated way to update shell configuration files when the Workwarrior project location changes. The system detects old path references, creates backups, and migrates aliases and functions to use the new location while preserving user customizations.

## Glossary

- **Shell_Config_File**: A configuration file that shells read on startup (e.g., .bashrc, .zshrc, .bash_profile, .zprofile)
- **Migration_Script**: The executable script that performs the configuration migration
- **Section_Marker**: A comment line that delimits a block of configuration (e.g., "# --- Workwarrior Aliases ---")
- **Old_Path**: The previous Workwarrior installation location (user-specified or detected)
- **New_Path**: The target Workwarrior installation location (user-specified during installation)
- **Installation_Config**: A configuration file that stores the chosen installation path and folder name
- **Backup_File**: A timestamped copy of a shell configuration file created before modification
- **Path_Reference**: Any string in a configuration file that contains a filesystem path to Workwarrior

## Requirements

### Requirement 1: Shell Configuration File Detection

**User Story:** As a user, I want the system to automatically detect all my shell configuration files, so that all relevant files are migrated without manual specification.

#### Acceptance Criteria

1. WHEN the Migration_Script executes, THE System SHALL identify all shell configuration files in the user's home directory
2. THE System SHALL detect .bashrc, .zshrc, .bash_profile, .zprofile, .profile, and .bash_aliases files
3. WHEN a shell configuration file does not exist, THE System SHALL skip it without error
4. THE System SHALL report which configuration files were found

### Requirement 2: Backup Creation

**User Story:** As a user, I want automatic backups created before any changes, so that I can recover my original configuration if needed.

#### Acceptance Criteria

1. WHEN the Migration_Script modifies a file, THE System SHALL create a backup with a timestamp suffix
2. THE System SHALL use the format "{filename}.backup-YYYYMMDD-HHMMSS" for backup filenames
3. WHEN a backup cannot be created, THE System SHALL abort the migration for that file and report an error
4. THE System SHALL report the location of each backup file created
5. WHEN the Migration_Script runs multiple times, THE System SHALL create a new backup each time

### Requirement 3: Old Path Reference Detection

**User Story:** As a user, I want the system to find all references to the old Workwarrior location, so that no outdated paths remain in my configuration.

#### Acceptance Criteria

1. WHEN scanning a configuration file, THE System SHALL identify all lines containing the Old_Path
2. THE System SHALL detect path references in aliases, functions, and variable assignments
3. THE System SHALL detect path references regardless of quoting style (single quotes, double quotes, no quotes)
4. THE System SHALL report the number of old path references found in each file

### Requirement 4: Path Migration

**User Story:** As a user, I want old paths automatically updated to the new location, so that my aliases and functions work with the relocated Workwarrior installation.

#### Acceptance Criteria

1. WHEN an Old_Path reference is found, THE System SHALL replace it with the New_Path
2. THE System SHALL preserve the original quoting style when replacing paths
3. THE System SHALL preserve indentation and whitespace when replacing paths
4. WHEN replacing paths in section-marked blocks, THE System SHALL maintain the section structure
5. THE System SHALL report each path replacement performed

### Requirement 5: Installation Path Configuration

**User Story:** As a user installing or migrating Workwarrior, I want to specify where to install it and what to name the folder, so that the system adapts to my preferred directory structure.

#### Acceptance Criteria

1. WHEN the Migration_Script starts, THE System SHALL prompt the user for the New_Path if not already configured
2. THE System SHALL allow the user to specify a custom installation directory (e.g., /mp/, /home/user/projects/)
3. THE System SHALL allow the user to choose a folder name (e.g., "ww", "workwarrior", or custom name)
4. THE System SHALL store the chosen installation path in the Installation_Config for future reference
5. THE System SHALL validate that the specified New_Path exists as a directory before proceeding
6. IF the New_Path does not exist, THEN THE System SHALL offer to create it or abort the migration

### Requirement 6: Old Path Detection

**User Story:** As a user migrating from a previous installation, I want the system to detect my old Workwarrior location automatically, so that I don't need to remember where it was installed.

#### Acceptance Criteria

1. WHEN the Migration_Script starts, THE System SHALL scan shell configuration files for existing Workwarrior path references
2. THE System SHALL identify the most common path reference as the Old_Path
3. WHEN multiple different paths are found, THE System SHALL prompt the user to confirm which is the Old_Path
4. THE System SHALL allow the user to manually specify the Old_Path if auto-detection fails
5. WHEN no old path is detected, THE System SHALL treat this as a fresh installation and skip migration

### Requirement 7: Multi-Shell Support

**User Story:** As a user who may use different shells, I want the migration to work correctly for both bash and zsh configurations, so that all my shell environments are updated.

#### Acceptance Criteria

1. THE System SHALL correctly process bash-specific configuration files (.bashrc, .bash_profile, .bash_aliases)
2. THE System SHALL correctly process zsh-specific configuration files (.zshrc, .zprofile)
3. THE System SHALL correctly process shell-agnostic configuration files (.profile)
4. THE System SHALL handle shell-specific syntax differences when present

### Requirement 8: Rollback Capability

**User Story:** As a user, I want the ability to undo the migration, so that I can recover if the migration causes problems.

#### Acceptance Criteria

1. THE System SHALL provide a rollback command or option
2. WHEN rollback is invoked, THE System SHALL restore files from the most recent backup
3. WHEN multiple backups exist, THE System SHALL identify and use the most recent backup by timestamp
4. THE System SHALL report which files were restored during rollback
5. IF no backup exists for a file, THEN THE System SHALL report that rollback is not possible for that file

### Requirement 9: Change Reporting

**User Story:** As a user, I want to see what changes were made, so that I understand what the migration did to my configuration.

#### Acceptance Criteria

1. WHEN the Migration_Script completes, THE System SHALL display a summary of all changes
2. THE System SHALL report the number of files processed
3. THE System SHALL report the number of path references replaced in each file
4. THE System SHALL report the location of each backup file created
5. THE System SHALL display the total number of replacements across all files

### Requirement 10: Idempotency

**User Story:** As a user, I want to safely run the migration multiple times, so that I can re-run it if I add new configuration or if I'm unsure whether it completed successfully.

#### Acceptance Criteria

1. WHEN the Migration_Script runs on already-migrated files, THE System SHALL detect that no changes are needed
2. WHEN no Old_Path references exist, THE System SHALL report that the configuration is already up-to-date
3. THE System SHALL not create unnecessary backups when no changes are made
4. WHEN run multiple times, THE System SHALL produce the same result as running once

### Requirement 11: User Customization Preservation

**User Story:** As a user with customized shell configuration, I want my personal modifications preserved during migration, so that only paths are updated without losing my customizations.

#### Acceptance Criteria

1. WHEN migrating configuration, THE System SHALL only modify lines containing Old_Path references
2. THE System SHALL preserve all lines that do not contain Old_Path references
3. THE System SHALL preserve comments, blank lines, and formatting
4. THE System SHALL preserve the order of configuration entries
5. WHEN custom aliases or functions reference the Old_Path, THE System SHALL update only the path portion while preserving the custom logic

### Requirement 12: Section Marker Handling

**User Story:** As a user whose configuration uses section markers to organize content, I want the migration to respect these markers, so that my configuration remains well-organized.

#### Acceptance Criteria

1. WHEN processing files with Section_Markers, THE System SHALL preserve the marker comments
2. THE System SHALL maintain the structure of marked sections
3. WHEN updating paths within marked sections, THE System SHALL keep entries within their original sections
4. THE System SHALL not remove or modify Section_Marker comments

### Requirement 13: Error Handling and Safety

**User Story:** As a user, I want the migration to fail safely if errors occur, so that I don't end up with corrupted or partially-updated configuration files.

#### Acceptance Criteria

1. WHEN an error occurs during file processing, THE System SHALL not modify the original file
2. IF a backup creation fails, THEN THE System SHALL not proceed with modifying that file
3. WHEN file permissions prevent reading or writing, THE System SHALL report a clear error message
4. THE System SHALL validate that modified files are syntactically valid before replacing originals
5. IF the New_Path becomes unavailable during migration, THEN THE System SHALL abort and report an error

### Requirement 14: Installation Process Integration

**User Story:** As a user installing Workwarrior, I want the migration to integrate seamlessly with the installation process, so that my shell configuration is automatically updated during installation.

#### Acceptance Criteria

1. WHEN the installation process runs, THE System SHALL offer to migrate existing shell configurations
2. THE System SHALL use the installation path and folder name chosen during installation as the New_Path
3. WHEN this is a fresh installation with no previous Workwarrior configuration, THE System SHALL skip migration and only set up new aliases
4. THE System SHALL store the chosen installation path in the Installation_Config for future migrations
5. THE System SHALL allow the user to skip migration during installation and run it manually later

