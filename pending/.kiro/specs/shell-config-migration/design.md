# Design Document: Shell Configuration Migration

## Overview

The Shell Configuration Migration system provides a safe, automated mechanism for updating shell configuration files when the Workwarrior project is relocated or reinstalled. The system detects existing Workwarrior path references, creates backups, and migrates configuration to use the new installation location while preserving user customizations.

The design follows a defensive programming approach with multiple safety checks, comprehensive backup mechanisms, and clear rollback capabilities. The system integrates with the Workwarrior installation process but can also be run standalone for manual migrations.

### Key Design Principles

1. **Safety First**: Never modify files without backups; validate all operations before execution
2. **Idempotency**: Safe to run multiple times; detects when no changes are needed
3. **User Control**: Prompt for confirmation on destructive operations; provide clear feedback
4. **Flexibility**: Support custom installation paths and folder names
5. **Integration**: Work seamlessly with the installation process or standalone

## Architecture

The migration system consists of three main components:

```
┌─────────────────────────────────────────────────────────────┐
│                    Migration Controller                      │
│  (Orchestrates the migration workflow)                       │
└────────────┬────────────────────────────────────────────────┘
             │
             ├──────────────┬──────────────┬──────────────────┐
             │              │              │                  │
             ▼              ▼              ▼                  ▼
    ┌────────────┐  ┌──────────────┐  ┌────────────┐  ┌──────────────┐
    │   Config   │  │     File     │  │   Backup   │  │   Reporter   │
    │  Manager   │  │   Scanner    │  │  Manager   │  │              │
    └────────────┘  └──────────────┘  └────────────┘  └──────────────┘
         │               │                  │                │
         │               │                  │                │
         ▼               ▼                  ▼                ▼
    ┌─────────────────────────────────────────────────────────┐
    │              Shell Configuration Files                   │
    │  (.bashrc, .zshrc, .bash_profile, .zprofile, etc.)      │
    └─────────────────────────────────────────────────────────┘
```

### Component Responsibilities

1. **Migration Controller**: Main orchestration logic; coordinates all operations
2. **Config Manager**: Handles installation configuration storage and retrieval
3. **File Scanner**: Detects shell config files and identifies path references
4. **Backup Manager**: Creates and manages backups; provides rollback capability
5. **Reporter**: Generates user-facing output and change summaries

## Components and Interfaces

### 1. Migration Controller

The main entry point that orchestrates the entire migration process.

**Interface:**
```bash
migrate_shell_config [OPTIONS]

Options:
  --old-path PATH       Specify the old Workwarrior path (auto-detected if omitted)
  --new-path PATH       Specify the new Workwarrior path (prompted if omitted)
  --non-interactive     Run without prompts (use defaults/fail on ambiguity)
  --dry-run            Show what would be changed without modifying files
  --rollback           Restore from most recent backups
  --help               Show usage information
```

**Workflow:**
1. Parse command-line arguments
2. Load or prompt for installation configuration
3. Validate new path exists and is accessible
4. Detect old path from existing configuration (if not specified)
5. Scan for shell configuration files
6. For each file:
   - Create backup
   - Scan for old path references
   - Replace old paths with new paths
   - Validate modified content
   - Replace original file
7. Generate and display change report

### 2. Config Manager

Manages persistent storage of installation configuration.

**Configuration File Location:** `~/.config/workwarrior/install.conf`

**Configuration Format:**
```bash
# Workwarrior Installation Configuration
WORKWARRIOR_INSTALL_PATH="/mp/workwarrior"
WORKWARRIOR_FOLDER_NAME="workwarrior"
INSTALLATION_DATE="2024-01-15T10:30:00Z"
```

**Functions:**
```bash
# Load configuration from file
# Returns: 0 on success, 1 if file doesn't exist
load_install_config()

# Save configuration to file
# Args: install_path, folder_name
# Returns: 0 on success, 1 on failure
save_install_config(install_path, folder_name)

# Prompt user for installation path and folder name
# Returns: Sets global variables INSTALL_PATH and FOLDER_NAME
prompt_install_config()

# Get the full installation path (parent + folder name)
# Returns: Full path string
get_install_path()
```

### 3. File Scanner

Detects shell configuration files and identifies path references.

**Shell Config Files to Scan:**
- `~/.bashrc`
- `~/.bash_profile`
- `~/.bash_aliases`
- `~/.profile`
- `~/.zshrc`
- `~/.zprofile`

**Functions:**
```bash
# Find all shell configuration files that exist
# Returns: Array of file paths
find_shell_config_files()

# Scan a file for path references
# Args: file_path, search_path
# Returns: Array of line numbers containing the path
scan_file_for_path(file_path, search_path)

# Count occurrences of a path in a file
# Args: file_path, search_path
# Returns: Integer count
count_path_references(file_path, search_path)

# Detect the most common Workwarrior path in config files
# Returns: Path string or empty if none found
detect_old_path()
```

**Path Detection Algorithm:**
1. Scan all shell config files for paths matching common patterns:
   - `/*/ww/` (any parent with "ww" folder)
   - `/*/workwarrior/` (any parent with "workwarrior" folder)
   - Paths containing "workwarrior" or "ww" in directory names
2. Count occurrences of each unique path
3. Return the most frequent path as the likely old installation location
4. If multiple paths have equal frequency, prompt user to select

### 4. Backup Manager

Creates timestamped backups and manages rollback operations.

**Backup File Format:** `{original_filename}.backup-YYYYMMDD-HHMMSS`

**Functions:**
```bash
# Create a backup of a file
# Args: file_path
# Returns: Backup file path on success, empty on failure
create_backup(file_path)

# Find the most recent backup for a file
# Args: original_file_path
# Returns: Backup file path or empty if none found
find_latest_backup(original_file_path)

# Restore a file from its most recent backup
# Args: original_file_path
# Returns: 0 on success, 1 on failure
restore_from_backup(original_file_path)

# List all backups for shell config files
# Returns: Array of backup file paths with timestamps
list_all_backups()

# Clean up old backups (keep only N most recent)
# Args: original_file_path, keep_count
# Returns: 0 on success
cleanup_old_backups(original_file_path, keep_count)
```

**Backup Strategy:**
- Create backup before any modification
- Use atomic operations (write to temp, then move)
- Verify backup integrity before proceeding
- Keep multiple backups (configurable, default: 5 most recent)
- Provide easy rollback mechanism

### 5. Path Replacer

Performs the actual path replacement in configuration files.

**Functions:**
```bash
# Replace all occurrences of old path with new path in a file
# Args: file_path, old_path, new_path
# Returns: 0 on success, 1 on failure
replace_paths_in_file(file_path, old_path, new_path)

# Validate that a modified file is syntactically valid
# Args: file_path, shell_type (bash|zsh)
# Returns: 0 if valid, 1 if invalid
validate_shell_syntax(file_path, shell_type)

# Preview changes without modifying file
# Args: file_path, old_path, new_path
# Returns: Diff output showing proposed changes
preview_changes(file_path, old_path, new_path)
```

**Replacement Algorithm:**
1. Read file content into memory
2. Use `sed` or `awk` to replace all occurrences:
   - Preserve quoting style (single, double, none)
   - Preserve whitespace and indentation
   - Handle escaped characters
3. Write to temporary file
4. Validate syntax of temporary file
5. If valid, atomically replace original with temp file
6. If invalid, abort and report error

**Sed Command Pattern:**
```bash
sed -E "s|${old_path}|${new_path}|g" "$file_path"
```

This preserves:
- Quoting: `"/mp/ww/"` → `"/mp/workwarrior/"`
- Variables: `WW_PATH=/mp/ww` → `WW_PATH=/mp/workwarrior`
- Comments: `# Located at /mp/ww/` → `# Located at /mp/workwarrior/`

### 6. Reporter

Generates user-facing output and change summaries.

**Functions:**
```bash
# Display migration summary
# Args: files_processed, total_replacements, backup_locations
display_summary(files_processed, total_replacements, backup_locations)

# Display file-specific changes
# Args: file_path, replacement_count
display_file_changes(file_path, replacement_count)

# Display error message with context
# Args: error_message, file_path (optional)
display_error(error_message, file_path)

# Display rollback instructions
# Args: backup_locations
display_rollback_instructions(backup_locations)
```

**Output Format:**
```
Shell Configuration Migration
═══════════════════════════════════════════════════════════════

Configuration:
  Old path: /mp/ww
  New path: /mp/workwarrior

Scanning for shell configuration files...
  ✓ Found ~/.bashrc
  ✓ Found ~/.zshrc
  ✓ Found ~/.bash_profile

Creating backups...
  ✓ ~/.bashrc → ~/.bashrc.backup-20240115-103000
  ✓ ~/.zshrc → ~/.zshrc.backup-20240115-103000

Migrating paths...
  ✓ ~/.bashrc: 12 references updated
  ✓ ~/.zshrc: 8 references updated
  ✓ ~/.bash_profile: 3 references updated

═══════════════════════════════════════════════════════════════
Migration completed successfully!

Summary:
  Files processed: 3
  Total replacements: 23
  Backups created: 3

To apply changes, reload your shell:
  source ~/.bashrc
  source ~/.zshrc

To rollback if needed:
  migrate_shell_config --rollback
═══════════════════════════════════════════════════════════════
```

## Data Models

### Installation Configuration

```bash
# Structure stored in ~/.config/workwarrior/install.conf
{
  install_path: string          # Full path to Workwarrior installation
  folder_name: string           # Folder name (ww, workwarrior, custom)
  installation_date: timestamp  # When configuration was created
  last_migration: timestamp     # When last migration was performed
}
```

### Migration Context

```bash
# Runtime context passed between functions
{
  old_path: string              # Source path to migrate from
  new_path: string              # Target path to migrate to
  config_files: array[string]   # List of shell config files to process
  dry_run: boolean              # Whether to actually modify files
  non_interactive: boolean      # Whether to prompt user
  backups: map[string]string    # Original file → backup file mapping
  changes: map[string]int       # File → replacement count mapping
}
```

### Backup Metadata

```bash
# Information about a backup file
{
  original_file: string         # Path to original file
  backup_file: string           # Path to backup file
  timestamp: string             # Backup creation time (YYYYMMDD-HHMMSS)
  file_size: int                # Size in bytes
  checksum: string              # SHA256 hash for integrity verification
}
```


## Correctness Properties

A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

### Property 1: Complete File Detection

*For any* home directory containing shell configuration files (.bashrc, .zshrc, .bash_profile, .zprofile, .profile, .bash_aliases), the file scanner should identify all existing files and skip non-existent files without error.

**Validates: Requirements 1.1, 1.3**

### Property 2: Backup Creation Atomicity

*For any* file that is modified during migration, a backup with timestamp format "{filename}.backup-YYYYMMDD-HHMMSS" must be created before modification, and if backup creation fails, the original file must remain unmodified.

**Validates: Requirements 2.1, 2.2, 2.3, 13.2**

### Property 3: Multiple Backup Preservation

*For any* file, running the migration script multiple times should create distinct timestamped backups for each run, with no backups being overwritten.

**Validates: Requirements 2.5**

### Property 4: Comprehensive Path Detection

*For any* shell configuration file containing path references, the scanner should identify all occurrences of the old path regardless of context (aliases, functions, variables) or quoting style (single quotes, double quotes, no quotes).

**Validates: Requirements 3.1, 3.2, 3.3**

### Property 5: Complete Path Replacement

*For any* occurrence of the old path in a configuration file, it should be replaced with the new path while preserving the original quoting style, indentation, whitespace, and surrounding context.

**Validates: Requirements 4.1, 4.2, 4.3, 11.5**

### Property 6: Selective Modification

*For any* configuration file, only lines containing the old path should be modified, while all other lines (including comments, blank lines, and non-path content) should remain exactly as they were, preserving order and formatting.

**Validates: Requirements 11.1, 11.2, 11.3, 11.4**

### Property 7: Section Marker Preservation

*For any* configuration file containing section markers, the markers and section structure should remain intact after migration, with entries staying within their original sections.

**Validates: Requirements 12.1, 12.2, 12.3**

### Property 8: Configuration Round-Trip

*For any* valid installation path and folder name, storing the configuration and then loading it should return the exact same values.

**Validates: Requirements 5.4**

### Property 9: Path Validation

*For any* specified new path, the system should verify it exists as a readable directory before proceeding with migration, and should fail gracefully with a clear error if the path is invalid or inaccessible.

**Validates: Requirements 5.5**

### Property 10: Old Path Auto-Detection

*For any* set of shell configuration files containing Workwarrior path references, the system should identify the most frequently occurring path as the old path, and when multiple paths have equal frequency, should prompt for user confirmation.

**Validates: Requirements 6.1, 6.2**

### Property 11: Rollback Round-Trip

*For any* file that has been migrated with a backup created, invoking rollback should restore the file to its exact pre-migration state by using the most recent backup based on timestamp.

**Validates: Requirements 8.2, 8.3**

### Property 12: Idempotency

*For any* configuration that has already been migrated, running the migration script again should detect that no changes are needed, report the configuration as up-to-date, create no backups, and leave all files unchanged.

**Validates: Requirements 10.1, 10.2, 10.3, 10.4**

### Property 13: Error Atomicity

*For any* error that occurs during file processing (backup failure, validation failure, permission error), the original file should remain unmodified and the system should report a clear error message.

**Validates: Requirements 13.1, 13.4**

### Property 14: Multi-Shell Support

*For any* shell type (bash, zsh, or shell-agnostic), the system should correctly process the corresponding configuration files and handle shell-specific syntax appropriately.

**Validates: Requirements 7.1, 7.2, 7.3**

## Error Handling

### Error Categories

1. **File System Errors**
   - File not readable: Report error, skip file, continue with others
   - File not writable: Report error, skip file, continue with others
   - Backup creation failure: Abort modification of that file, continue with others
   - Disk full: Abort entire migration, report error

2. **Path Validation Errors**
   - New path doesn't exist: Offer to create or abort
   - New path not readable: Report error, abort migration
   - Old path auto-detection finds no paths: Treat as fresh install, skip migration
   - Old path auto-detection finds multiple equal paths: Prompt user to select

3. **Configuration Errors**
   - Invalid installation config format: Report error, prompt for new config
   - Missing installation config: Prompt user for installation path
   - Config file not writable: Report error, continue without saving config

4. **Syntax Validation Errors**
   - Modified file fails syntax check: Abort replacement, restore from backup, report error
   - Cannot determine shell type for validation: Skip validation, warn user

### Error Recovery Strategy

All file modifications use atomic operations:
1. Create backup
2. Modify content in memory
3. Write to temporary file
4. Validate temporary file
5. Atomically move temporary file to original location

If any step fails, the original file remains untouched and the backup (if created) remains available.

### Error Messages

Error messages should be:
- **Clear**: Explain what went wrong in plain language
- **Actionable**: Suggest what the user can do to fix it
- **Contextual**: Include relevant file paths and line numbers

Example error messages:
```
ERROR: Cannot create backup for ~/.bashrc
  Reason: Permission denied
  Action: Check file permissions and try again
  
ERROR: New path does not exist: /mp/workwarrior
  Action: Create the directory or specify a different path
  Options:
    1. Create directory: mkdir -p /mp/workwarrior
    2. Specify different path: --new-path /other/path
    
WARNING: Cannot validate syntax for ~/.zshrc
  Reason: zsh not installed
  Action: Manually verify the file after migration
```

## Testing Strategy

The Shell Configuration Migration system will be tested using both unit tests and property-based tests to ensure comprehensive coverage.

### Unit Testing

Unit tests will focus on:
- **Specific examples**: Test known shell config patterns and edge cases
- **Error conditions**: Test specific error scenarios (permission denied, disk full, etc.)
- **Integration points**: Test interaction between components
- **Edge cases**: Empty files, files with only comments, files with special characters

Example unit tests:
- Test backup filename format matches expected pattern
- Test that non-existent files are skipped without error
- Test that permission errors are reported correctly
- Test rollback with no backups available
- Test fresh installation detection (no old paths found)

### Property-Based Testing

Property-based tests will verify universal properties across randomized inputs. Each test will run a minimum of 100 iterations.

**Test Configuration:**
- Library: Use language-appropriate PBT library (e.g., `shunit2` with randomization for bash, or Python's `hypothesis` for a Python implementation)
- Iterations: Minimum 100 per property test
- Tagging: Each test tagged with `Feature: shell-config-migration, Property N: [property text]`

**Property Test Examples:**

1. **Property 1: Complete File Detection**
   - Generate: Random set of shell config files (some exist, some don't)
   - Test: All existing files are detected, non-existent files are skipped
   - Tag: `Feature: shell-config-migration, Property 1: Complete File Detection`

2. **Property 5: Complete Path Replacement**
   - Generate: Random shell config content with various path references and quoting styles
   - Test: All old paths replaced with new paths, quoting/whitespace preserved
   - Tag: `Feature: shell-config-migration, Property 5: Complete Path Replacement`

3. **Property 6: Selective Modification**
   - Generate: Random shell config with mix of path and non-path lines
   - Test: Only path lines modified, all other lines unchanged
   - Tag: `Feature: shell-config-migration, Property 6: Selective Modification`

4. **Property 8: Configuration Round-Trip**
   - Generate: Random valid installation paths and folder names
   - Test: save_config(path, name) then load_config() returns same values
   - Tag: `Feature: shell-config-migration, Property 8: Configuration Round-Trip`

5. **Property 11: Rollback Round-Trip**
   - Generate: Random shell config content
   - Test: original → migrate → rollback produces original content
   - Tag: `Feature: shell-config-migration, Property 11: Rollback Round-Trip`

6. **Property 12: Idempotency**
   - Generate: Random shell config content
   - Test: migrate(migrate(content)) = migrate(content)
   - Tag: `Feature: shell-config-migration, Property 12: Idempotency`

### Test Data Generation

For property-based tests, generators will create:
- **Random paths**: Various directory structures and folder names
- **Random shell syntax**: Aliases, functions, variables with different quoting
- **Random file content**: Mix of valid shell code, comments, blank lines
- **Random section markers**: Various marker formats and nesting levels
- **Edge cases**: Empty files, very long lines, special characters, unicode

### Integration Testing

Integration tests will verify:
- End-to-end migration workflow with real shell config files
- Integration with installation process
- Rollback functionality with multiple backups
- Non-interactive mode with various flag combinations
- Dry-run mode produces accurate previews

### Manual Testing Checklist

Before release, manually verify:
- [ ] Migration works on actual user shell configurations
- [ ] Rollback successfully restores original state
- [ ] Error messages are clear and actionable
- [ ] Installation integration works smoothly
- [ ] Works on both bash and zsh
- [ ] Works on different operating systems (Linux, macOS)
- [ ] Handles edge cases (symlinks, read-only files, etc.)
