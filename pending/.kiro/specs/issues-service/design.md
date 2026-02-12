# Design Document: Issues Service Integration

## Overview

This document describes the design for integrating bugwarrior as an "issues" service into the Workwarrior ecosystem. Bugwarrior is a command-line utility that synchronizes issues from 25+ external services (GitHub, GitLab, Jira, Trello, etc.) into TaskWarrior through one-way, read-only synchronization.

The integration follows established Workwarrior patterns:
- Shell function wrapper (i) for convenient access
- Interactive configuration tool (configure-issues.sh)
- CLI dispatcher integration (bin/ww and bin/custom)
- Profile-aware configuration storage
- Shortcuts registry documentation

Key design principle: External issue trackers are authoritative. Bugwarrior pulls data FROM external services TO TaskWarrior. Changes in TaskWarrior do NOT sync back.

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    User Interface Layer                      │
├─────────────────────────────────────────────────────────────┤
│  Shell Function: i()                                         │
│  - Profile-aware wrapper                                     │
│  - Routes to bugwarrior or configuration tool                │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   CLI Dispatcher Layer                       │
├─────────────────────────────────────────────────────────────┤
│  bin/ww                    bin/custom                        │
│  - Routes "i" commands     - Routes "i custom" commands      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Configuration Layer                         │
├─────────────────────────────────────────────────────────────┤
│  services/custom/configure-issues.sh                         │
│  - Interactive service configuration                         │
│  - UDA generation and management                             │
│  - Credential security guidance                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    External Tool Layer                       │
├─────────────────────────────────────────────────────────────┤
│  bugwarrior                                                  │
│  - Issue synchronization (pull)                              │
│  - UDA definition generation (uda)                           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Storage Layer                             │
├─────────────────────────────────────────────────────────────┤
│  Profile Directory Structure:                                │
│  $WORKWARRIOR_BASE/                                          │
│    .config/bugwarrior/                                       │
│      bugwarriorrc (or bugwarrior.toml)                       │
│    .taskrc (with UDA definitions)                            │
│    .task/ (TaskWarrior database with synced issues)          │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. User activates profile: `p-work`
2. User configures service: `i custom`
   - Interactive prompts guide configuration
   - Service credentials stored securely
   - UDAs generated and appended to .taskrc
3. User syncs issues: `i pull`
   - Bugwarrior reads $WORKWARRIOR_BASE/.config/bugwarrior/bugwarriorrc
   - Connects to external services (GitHub, Jira, etc.)
   - Creates/updates tasks in TaskWarrior with service-specific UDAs
   - Tags tasks with service identifiers (+github, +jira)
4. User views tasks: `task list +github`
   - TaskWarrior displays synced issues with metadata

## Components and Interfaces

### 1. Shell Integration Function: i()

**Location**: `lib/shell-integration.sh`

**Purpose**: Provide convenient shell access to bugwarrior with profile awareness

**Interface**:
```bash
i() {
  # Resolve scope (active profile, --global, --profile <name>)
  if ! ww_resolve_scope "$@"; then
    return 1
  fi
  local args=("${WW_REMAINING_ARGS[@]}")
  
  # Handle 'i custom' command
  if [[ ${#args[@]} -gt 0 && "${args[0]}" == "custom" ]]; then
    # Route to configuration tool
    local remaining=("${args[@]:1}")
    if command -v ww &>/dev/null; then
      WORKWARRIOR_BASE="$WW_SCOPE_BASE" WARRIOR_PROFILE="$WW_SCOPE_PROFILE" \
        ww custom issues "${remaining[@]}"
    else
      local ww_base="${WW_BASE:-$HOME/ww}"
      WORKWARRIOR_BASE="$WW_SCOPE_BASE" WARRIOR_PROFILE="$WW_SCOPE_PROFILE" \
        "$ww_base/services/custom/configure-issues.sh" "${remaining[@]}"
    fi
    return $?
  fi
  
  # Check if bugwarrior config exists
  local bugwarrior_config="$WW_SCOPE_BASE/.config/bugwarrior/bugwarriorrc"
  if [[ ! -f "$bugwarrior_config" ]]; then
    # Try TOML format
    bugwarrior_config="$WW_SCOPE_BASE/.config/bugwarrior/bugwarrior.toml"
    if [[ ! -f "$bugwarrior_config" ]]; then
      echo "Error: Bugwarrior configuration not found" >&2
      echo "Run 'i custom' to configure the issues service" >&2
      return 1
    fi
  fi
  
  # Execute bugwarrior with profile-specific config
  BUGWARRIORRC="$bugwarrior_config" \
  BUGWARRIOR_TASKRC="$WW_SCOPE_BASE/.taskrc" \
  BUGWARRIOR_TASKDATA="$WW_SCOPE_BASE/.task" \
    bugwarrior "${args[@]}"
  return $?
}
```

**Key Features**:
- Uses `ww_resolve_scope` for profile awareness (consistent with j, l, list)
- Routes "i custom" to configuration tool
- Sets bugwarrior environment variables for profile isolation
- Validates configuration exists before executing
- Provides helpful error messages

### 2. Configuration Tool: configure-issues.sh

**Location**: `services/custom/configure-issues.sh`

**Purpose**: Interactive configuration wizard for bugwarrior services

**Interface**:
```bash
#!/usr/bin/env bash
# Service: configure-issues
# Category: custom
# Description: Interactive guide for configuring bugwarrior issue synchronization

# Main menu structure:
# 1. Add/configure external service
# 2. List configured services
# 3. Remove service
# 4. Generate/update UDAs
# 5. Test connection
# 6. View current configuration
# 7. Exit
```

**Configuration Flow**:
1. Check active profile (required)
2. Ensure .config/bugwarrior/ directory exists
3. Load or create bugwarriorrc
4. Present service selection menu (GitHub, GitLab, Jira, etc.)
5. Prompt for service-specific credentials and settings
6. Offer secure credential storage options
7. Generate UDAs for configured service
8. Append UDAs to .taskrc (avoiding duplicates)
9. Save configuration

**Service Templates**:
The tool will include templates for common services:
- GitHub: token, username, repo filters
- GitLab: token, host, project filters
- Jira: username, password/token, server, JQL filters
- Trello: api_key, token, board filters
- Generic: for other services

### 3. CLI Dispatcher Integration

**bin/ww modifications**:
```bash
# Add to cmd_custom() function
cmd_custom() {
  local action="${1:-}"
  shift 2>/dev/null || true

  case "$action" in
    journals)
      "$WW_BASE/services/custom/configure-journals.sh" "$@"
      ;;
    tasks)
      "$WW_BASE/services/custom/configure-tasks.sh" "$@"
      ;;
    times)
      "$WW_BASE/services/custom/configure-times.sh" "$@"
      ;;
    ledgers)
      "$WW_BASE/services/custom/configure-ledgers.sh" "$@"
      ;;
    issues)  # NEW
      "$WW_BASE/services/custom/configure-issues.sh" "$@"
      ;;
    list)
      # ... existing code ...
      echo "  issues     Configure bugwarrior issue synchronization (requires active profile)"
      # ... existing code ...
      ;;
    # ... rest of cases ...
  esac
}
```

**bin/custom modifications**:
```bash
main() {
  local service="${1:-}"
  shift 2>/dev/null || true

  case "$service" in
    journals)
      "$WW_BASE/services/custom/configure-journals.sh" "$@"
      ;;
    tasks)
      "$WW_BASE/services/custom/configure-tasks.sh" "$@"
      ;;
    times)
      "$WW_BASE/services/custom/configure-times.sh" "$@"
      ;;
    ledgers)
      "$WW_BASE/services/custom/configure-ledgers.sh" "$@"
      ;;
    issues)  # NEW
      "$WW_BASE/services/custom/configure-issues.sh" "$@"
      ;;
    # ... rest of cases ...
  esac
}
```

### 4. Profile Creation Integration

**Modifications to create-ww-profile.sh**:
```bash
# Add to profile directory structure creation
create_profile_structure() {
  local profile_name="$1"
  local profile_base="$PROFILES_DIR/$profile_name"
  
  # ... existing directories ...
  
  # Create bugwarrior configuration directory
  mkdir -p "$profile_base/.config/bugwarrior"
  
  # Create empty bugwarriorrc placeholder
  cat > "$profile_base/.config/bugwarrior/bugwarriorrc" << 'EOF'
# Bugwarrior Configuration
# Run 'i custom' to configure issue synchronization services
#
# Supported services: GitHub, GitLab, Jira, Trello, Todoist, and 20+ more
# Documentation: https://github.com/GothenburgBitFactory/bugwarrior

[general]
# Targets specify which TaskWarrior instance to use
targets = my_tasks

# ... rest of template ...
EOF
  
  # ... rest of function ...
}
```

### 5. Dependency Management

**Modifications to install.sh or dependency checker**:
```bash
# Add to dependency checks
check_bugwarrior() {
  if command -v bugwarrior &> /dev/null; then
    local version
    version=$(bugwarrior --version 2>&1 | head -1)
    log_success "bugwarrior: $version"
    return 0
  else
    log_warning "bugwarrior: not installed"
    echo "  Install: pip install bugwarrior"
    echo "  Or: pipx install bugwarrior"
    return 1
  fi
}
```

### 6. Shortcuts Registry

**Modifications to config/shortcuts.yaml**:
```yaml
shortcuts:
  # ... existing shortcuts ...
  
  # Issues service (NEW)
  i:
    name: "Issues (Bugwarrior)"
    category: function
    description: "Issue synchronization"
    command: "i"
    requires_profile: true
```

## Data Models

### Bugwarrior Configuration File

**Format**: INI or TOML

**Location**: `$WORKWARRIOR_BASE/.config/bugwarrior/bugwarriorrc`

**Example (INI format)**:
```ini
[general]
targets = my_tasks

# Taskwarrior instance
[my_tasks]
service = github
github.login = username
github.token = @oracle:use_keyring
github.username = username
github.include_repos = owner/repo1, owner/repo2
github.exclude_repos = owner/archived-repo
github.import_labels_as_tags = True
github.filter_pull_requests = True
```

**Example (TOML format)**:
```toml
[general]
targets = ["my_tasks"]

[my_tasks]
service = "github"

[my_tasks.github]
login = "username"
token = "@oracle:use_keyring"
username = "username"
include_repos = ["owner/repo1", "owner/repo2"]
exclude_repos = ["owner/archived-repo"]
import_labels_as_tags = true
filter_pull_requests = true
```

### UDA Definitions

**Location**: Appended to `$WORKWARRIOR_BASE/.taskrc`

**Example (GitHub UDAs)**:
```
# Bugwarrior UDAs for GitHub
uda.githubbody.type=string
uda.githubbody.label=Github Body
uda.githubcreatedon.type=date
uda.githubcreatedon.label=Github Created
uda.githubmilestone.type=string
uda.githubmilestone.label=Github Milestone
uda.githubnumber.type=numeric
uda.githubnumber.label=Github Issue/PR #
uda.githubrepo.type=string
uda.githubrepo.label=Github Repo Slug
uda.githubtitle.type=string
uda.githubtitle.label=Github Title
uda.githubtype.type=string
uda.githubtype.label=Github Type
uda.githuburl.type=string
uda.githuburl.label=Github URL
uda.githubupdatedat.type=date
uda.githubupdatedat.label=Github Updated
uda.githubuser.type=string
uda.githubuser.label=Github User
uda.githubstate.type=string
uda.githubstate.label=Github State
uda.githubnamespace.type=string
uda.githubnamespace.label=Github Namespace
```

### TaskWarrior Task Structure

**Synced Issue Example**:
```json
{
  "id": 42,
  "description": "Fix authentication bug",
  "project": "myproject",
  "tags": ["github", "bug"],
  "priority": "H",
  "githubnumber": 123,
  "githuburl": "https://github.com/owner/repo/issues/123",
  "githubstate": "open",
  "githubrepo": "owner/repo",
  "githubuser": "contributor",
  "githubcreatedon": "20240211T100000Z",
  "githubupdatedat": "20240212T150000Z",
  "annotations": [
    {
      "entry": "20240211T120000Z",
      "description": "Comment: This needs urgent attention"
    }
  ]
}
```

## Correctness Properties


A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

### Property 1: Argument Forwarding

*For any* set of command-line arguments passed to the i() function, those arguments should be forwarded to bugwarrior with the correct profile-specific environment variables (BUGWARRIORRC, BUGWARRIOR_TASKRC, BUGWARRIOR_TASKDATA) set based on the active profile.

**Validates: Requirements 1.2, 4.2**

### Property 2: Configuration File Storage

*For any* service configuration created through the configuration tool, the configuration should be stored in $WORKWARRIOR_BASE/.config/bugwarrior/bugwarriorrc (or bugwarrior.toml) where WORKWARRIOR_BASE corresponds to the active profile.

**Validates: Requirements 2.4, 3.2**

### Property 3: UDA Generation and Appending

*For any* external service configured, the configuration tool should generate UDA definitions for that service and append them to the active profile's .taskrc file without creating duplicates if the service is reconfigured.

**Validates: Requirements 2.5, 2.6, 6.1, 6.2, 6.3, 6.4**

### Property 4: Multi-Service UDA Generation

*For any* set of multiple external services configured in a single profile, the configuration tool should generate and maintain UDA definitions for all configured services in the .taskrc file.

**Validates: Requirements 6.5, 10.1**

### Property 5: Configuration Format Support

*For any* valid bugwarrior configuration, the system should correctly handle both INI and TOML formats, allowing users to create and use configurations in either format.

**Validates: Requirements 2.7**

### Property 6: Profile Isolation

*For any* two different profiles, syncing issues in one profile should not affect the TaskWarrior database or configuration of the other profile.

**Validates: Requirements 3.4**

### Property 7: Profile-Aware Configuration Selection

*For any* profile activation, the i() function should use the bugwarrior configuration file located in that profile's .config/bugwarrior/ directory.

**Validates: Requirements 3.3**

### Property 8: Error Message Forwarding

*For any* error returned by bugwarrior, the shell integration should forward the error message to the user without modification or suppression.

**Validates: Requirements 11.1, 11.4**

### Property 9: Data Preservation on Failure

*For any* bugwarrior sync failure, the existing TaskWarrior database should remain unchanged and uncorrupted.

**Validates: Requirements 11.5**

### Property 10: Version Compatibility Check

*For any* installed version of bugwarrior, the dependency checker should verify that the version meets minimum compatibility requirements.

**Validates: Requirements 7.4**

## Error Handling

### Error Categories

1. **Missing Profile**
   - Condition: User invokes i() without an active profile
   - Response: Display error message: "Error: No profile is active. Activate a profile with: p-<profile-name>"
   - Exit code: 1

2. **Missing Configuration**
   - Condition: User invokes i() but bugwarriorrc doesn't exist
   - Response: Display error message: "Error: Bugwarrior configuration not found. Run 'i custom' to configure the issues service"
   - Exit code: 1

3. **Missing Bugwarrior**
   - Condition: bugwarrior command not found in PATH
   - Response: Display error message with installation instructions
   - Exit code: 1

4. **Bugwarrior Execution Failure**
   - Condition: bugwarrior command returns non-zero exit code
   - Response: Forward bugwarrior's error output to stderr
   - Exit code: Same as bugwarrior's exit code

5. **Authentication Failure**
   - Condition: bugwarrior reports authentication error
   - Response: Display error with credential troubleshooting guidance
   - Exit code: Same as bugwarrior's exit code

6. **Network Failure**
   - Condition: bugwarrior reports network connectivity error
   - Response: Display error with network troubleshooting guidance
   - Exit code: Same as bugwarrior's exit code

7. **Invalid Configuration**
   - Condition: bugwarrior reports configuration parsing error
   - Response: Display error with configuration file location and section information
   - Exit code: Same as bugwarrior's exit code

8. **UDA Conflict**
   - Condition: Attempting to add UDA that already exists with different type
   - Response: Display warning and skip UDA addition
   - Exit code: 0 (warning, not error)

### Error Handling Principles

1. **Fail Fast**: Validate prerequisites (profile active, config exists) before executing bugwarrior
2. **Preserve Data**: Never modify TaskWarrior database on error
3. **Clear Messages**: Provide actionable error messages with next steps
4. **Exit Codes**: Use appropriate exit codes for scripting
5. **No Silent Failures**: Always report errors to user

## Testing Strategy

### Unit Testing

Unit tests will focus on specific examples and edge cases:

1. **Shell Function Tests**
   - Test i() with no active profile (error case)
   - Test i() with "custom" argument (routing)
   - Test i() with missing configuration (error case)
   - Test environment variable setting for profile isolation

2. **Configuration Tool Tests**
   - Test configuration file creation (INI format)
   - Test configuration file creation (TOML format)
   - Test UDA generation for GitHub service
   - Test UDA generation for GitLab service
   - Test UDA generation for Jira service
   - Test duplicate UDA prevention
   - Test credential security warning display

3. **CLI Dispatcher Tests**
   - Test "ww i" command routing
   - Test "ww i custom" command routing
   - Test "custom issues" command routing

4. **Profile Creation Tests**
   - Test .config/bugwarrior/ directory creation
   - Test bugwarriorrc template creation

5. **Dependency Check Tests**
   - Test bugwarrior detection when installed
   - Test bugwarrior detection when missing
   - Test version compatibility check

### Property-Based Testing

Property-based tests will verify universal properties across all inputs. Each test should run a minimum of 100 iterations.

1. **Property Test: Argument Forwarding**
   - Generate random argument lists
   - Verify all arguments are passed to bugwarrior
   - Verify environment variables are set correctly
   - **Feature: issues-service, Property 1: For any set of command-line arguments passed to the i() function, those arguments should be forwarded to bugwarrior with the correct profile-specific environment variables**

2. **Property Test: Configuration Storage**
   - Generate random service configurations
   - Verify configuration is written to correct file path
   - Verify configuration is valid INI or TOML
   - **Feature: issues-service, Property 2: For any service configuration created through the configuration tool, the configuration should be stored in the correct profile directory**

3. **Property Test: UDA Generation**
   - Generate random service types
   - Verify UDAs are generated for each service
   - Verify UDAs are appended to .taskrc
   - Verify no duplicates on reconfiguration
   - **Feature: issues-service, Property 3: For any external service configured, the configuration tool should generate UDA definitions without creating duplicates**

4. **Property Test: Multi-Service UDAs**
   - Generate random sets of multiple services
   - Verify UDAs for all services are present
   - Verify no conflicts between service UDAs
   - **Feature: issues-service, Property 4: For any set of multiple external services configured, all UDA definitions should be maintained**

5. **Property Test: Profile Isolation**
   - Generate random profile pairs
   - Sync issues in one profile
   - Verify other profile is unaffected
   - **Feature: issues-service, Property 6: For any two different profiles, syncing issues in one should not affect the other**

6. **Property Test: Error Forwarding**
   - Generate random bugwarrior error conditions
   - Verify error messages are forwarded
   - Verify exit codes are preserved
   - **Feature: issues-service, Property 8: For any error returned by bugwarrior, the error message should be forwarded to the user**

### Integration Testing

Integration tests will verify the complete workflow:

1. **End-to-End Workflow**
   - Create profile
   - Activate profile
   - Run i custom to configure GitHub service
   - Run i pull to sync issues
   - Verify tasks appear in TaskWarrior with correct UDAs
   - Verify tasks are tagged with +github

2. **Multi-Service Workflow**
   - Configure GitHub and GitLab services
   - Run i pull
   - Verify tasks from both services appear
   - Verify correct service tags (+github, +gitlab)

3. **Profile Switching Workflow**
   - Configure different services in two profiles
   - Switch between profiles
   - Verify correct configuration is used for each profile
   - Verify data isolation

### Manual Testing

Manual testing will cover UI and user experience:

1. **Configuration Tool UX**
   - Interactive prompts are clear
   - Service selection menu is comprehensive
   - Credential security warnings are prominent
   - Error messages are helpful

2. **Documentation Verification**
   - Shortcuts registry is accurate
   - Help text is complete
   - Examples work as documented

3. **Compatibility Testing**
   - Test with different bugwarrior versions
   - Test with different external services
   - Test on different operating systems

## Implementation Notes

### Bugwarrior Environment Variables

Bugwarrior respects these environment variables for configuration:
- `BUGWARRIORRC`: Path to configuration file
- `BUGWARRIOR_TASKRC`: Path to TaskWarrior configuration
- `BUGWARRIOR_TASKDATA`: Path to TaskWarrior data directory

Our shell integration must set these variables to ensure profile isolation.

### UDA Management Strategy

1. **Generation**: Use `bugwarrior uda` command to generate UDA definitions
2. **Parsing**: Parse output to extract UDA definitions
3. **Deduplication**: Check .taskrc for existing UDAs before appending
4. **Appending**: Use atomic file operations to prevent corruption

### Configuration File Format Detection

The tool should detect format based on file extension:
- `.bugwarriorrc` or `bugwarriorrc` → INI format
- `.toml` or `bugwarrior.toml` → TOML format

If no extension, default to INI format for backward compatibility.

### Credential Security

The configuration tool should:
1. Never store credentials in plain text by default
2. Recommend keyring integration as first option
3. Provide clear examples of @oracle syntax
4. Display prominent warnings if user chooses plain text

### Service Templates

The configuration tool should include templates for:
- GitHub (most common)
- GitLab (second most common)
- Jira (enterprise common)
- Trello (personal productivity)
- Generic template for other services

Each template should include:
- Required fields
- Optional fields with descriptions
- Example values
- Credential security options

### Profile Creation Integration

When creating a new profile, the system should:
1. Create `.config/bugwarrior/` directory
2. Create empty `bugwarriorrc` with commented template
3. Add comment explaining how to configure: "Run 'i custom' to configure"

This ensures users discover the feature without requiring manual setup.

### Dependency Version Requirements

Minimum bugwarrior version: 1.8.0 (for stable UDA support)

The dependency checker should:
1. Detect bugwarrior installation
2. Parse version from `bugwarrior --version`
3. Compare against minimum version
4. Display warning if version is too old

### Shell Function Registration

The i() function should be added to `lib/shell-integration.sh` alongside j(), l(), list(), task(), and timew() functions.

The function should be registered in `~/.bashrc` during installation using the same pattern as other global functions.

### Shortcuts Registry Integration

Add to `config/shortcuts.yaml`:
```yaml
i:
  name: "Issues (Bugwarrior)"
  category: function
  description: "Issue synchronization"
  command: "i"
  requires_profile: true
```

This ensures the shortcut appears in help documentation and shortcut listings.

## Security Considerations

### Credential Storage

1. **Keyring Integration**: Recommend system keyring as primary option
2. **Password Prompts**: Support interactive password entry
3. **External Managers**: Support pass, 1Password, LastPass via @oracle:eval
4. **Plain Text Warning**: Display prominent warning if credentials stored in plain text

### File Permissions

Configuration files should have restrictive permissions:
- `bugwarriorrc`: 600 (read/write owner only)
- `.taskrc`: 600 (read/write owner only)

The configuration tool should set these permissions automatically.

### API Token Scope

Guidance for users on API token permissions:
- GitHub: Recommend read-only repo scope
- GitLab: Recommend read_api scope
- Jira: Recommend read-only access

The configuration tool should display these recommendations during setup.

## Performance Considerations

### Sync Frequency

Bugwarrior sync can be slow for large repositories. Recommendations:
- Manual sync: `i pull` when needed
- Cron job: Every 15-30 minutes for active projects
- Hook integration: Sync before running `task` command (optional)

### Rate Limiting

External services have rate limits. The configuration tool should:
- Warn about rate limits during setup
- Recommend appropriate sync frequencies
- Document rate limit errors

### Large Repositories

For repositories with many issues:
- Use filters to limit synced issues
- Configure `github.include_repos` to specific repos
- Use `github.filter_pull_requests` to exclude PRs if not needed

## Future Enhancements

### Planned Features

1. **Sync Status Command**: `i status` to show last sync time and issue count
2. **Service Management**: `i service list`, `i service add`, `i service remove`
3. **Sync Hooks**: Pre/post sync hooks for custom automation
4. **Conflict Resolution**: UI for handling sync conflicts
5. **Selective Sync**: Sync specific services: `i pull github`

### Integration Opportunities

1. **TimeWarrior Integration**: Auto-start time tracking when working on synced issues
2. **JRNL Integration**: Auto-journal entries for issue updates
3. **Notification System**: Desktop notifications for new issues
4. **Dashboard**: Web dashboard showing synced issues across profiles

These enhancements are not part of the initial implementation but represent future directions for the issues service.
