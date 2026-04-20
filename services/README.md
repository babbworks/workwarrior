# Workwarrior Services Registry

## Overview

The Services Registry provides an extensible architecture for adding functionality to the Workwarrior Profiles System. Services are organized into categories and can be either global (available to all profiles) or profile-specific (available only to a specific profile).

## Service Categories

Use the CLI discovery layer to inspect categories before running scripts:

- `ww service list` - list categories with short descriptions
- `ww service info <category>` - show scope, syntax hints, and resolved service counts
- `ww service help <category-or-topic>` - route to command help where available

### profile/
**Purpose:** Profile management services

Contains scripts and utilities for creating, managing, and configuring Workwarrior profiles. This includes profile creation, deletion, backup, and configuration management.

**Key Services:**
- `create-ww-profile.sh` - Create new profiles with customization options
- `manage-profiles.sh` - Manage existing profiles (list, delete, info, backup)
- `on-modify.timewarrior` - TaskWarrior hook for TimeWarrior integration

**Subdirectories:**
- `defaults/` - Default configuration templates
- `subservices/` - Specialized profile operations
- `taskrc/` - TaskWarrior configuration templates

### questions/
**Purpose:** Inquiry management services

Provides templated question workflows for consistently capturing structured information for tasks, journals, and other productivity tools.

**Key Services:**
- `q.sh` - Main questions service interface
- Template creation and management
- Handler scripts for processing answers

**Subdirectories:**
- `templates/` - Question template definitions (JSON)
- `handlers/` - Service-specific answer processors
- `bin/` - Utility scripts for template management

### scripts/
**Purpose:** Utility scripts

General-purpose utility scripts for various productivity workflows. These scripts provide helper functionality that doesn't fit into other specific categories.

**Subdirectories:**
- `journals/` - Journal-related utilities
- `ledgers/` - Ledger-related utilities
- `tasks/` - Task-related utilities
- `times/` - Time tracking utilities
- `list/` - Simple list utilities
- `templates/` - Script templates
- `terminals/` - Terminal configuration scripts

### export/
**Purpose:** Data export services

Services for exporting data from TaskWarrior, TimeWarrior, JRNL, and Hledger to various formats (CSV, JSON, PDF, etc.).

**Use Cases:**
- Generate reports from task data
- Export time tracking summaries
- Create journal backups in different formats
- Export financial data for analysis

### diagnostic/
**Purpose:** System diagnostic services

Tools for diagnosing issues with profiles, configurations, and tool integrations.

**Use Cases:**
- Verify profile integrity
- Check configuration file syntax
- Validate environment variables
- Test tool integrations (TaskWarrior, TimeWarrior, JRNL, Hledger)
- Identify permission issues

### find/
**Purpose:** Search and discovery services

Services for searching across tasks, journals, ledgers, and time tracking data.

**Use Cases:**
- Search for tasks by description, tags, or attributes
- Find journal entries by date or content
- Locate transactions in ledgers
- Discover time tracking patterns

### verify/
**Purpose:** Validation services

Services for validating data integrity, configuration correctness, and system state.

**Use Cases:**
- Validate TaskWarrior data consistency
- Check journal file integrity
- Verify ledger balance assertions
- Validate configuration file syntax
- Ensure environment variables are correctly set

### custom/
**Purpose:** User-defined services

A directory for users to add their own custom services without modifying the core system.

**Guidelines:**
- Follow the same structure as other service categories
- Use descriptive names for service scripts
- Include README files for complex services
- Make scripts executable (`chmod +x`)

### groups/
**Purpose:** Profile grouping services

Manage collections of profiles for easy association and listing. Groups are global and do not require an active profile.

**Key Services:**
- `groups.sh` - Create, list, and modify profile groups

### models/
**Purpose:** LLM provider and model registry

Manage configuration for local and remote model providers. This service stores configuration only and does not make network calls.

**Key Services:**
- `models.sh` - Manage providers and models

### extensions/
**Purpose:** External tool extensions registry

Manage registries of extensions for tools such as Taskwarrior.

**Key Services:**
- `extensions.sh` - Extensions registry manager
- `taskwarrior.py` - Taskwarrior extensions scraper/registry

### find/
**Purpose:** Search and discovery services

Search across profiles and data types such as journals, ledgers, and lists.

**Key Services:**
- `find.sh` - Cross-profile search utility
 - `find.py` - Advanced query engine

## Service Structure

### Global Services
Located in `~/ww/services/<category>/`

Global services are available to all profiles and provide system-wide functionality.

### Profile-Specific Services
Located in `<profile-base>/services/<category>/`

Profile-specific services override global services when a profile is active. This allows customization of functionality for individual profiles without affecting others.

### Service Override Behavior

When a service exists in both locations:
1. If a profile is active, the profile-specific version is used
2. If no profile is active, the global version is used
3. Profile-specific services can call global services if needed

## Creating a Service

### Basic Service Script

```bash
#!/usr/bin/env bash
# Service: my-service
# Category: custom
# Description: Brief description of what this service does

set -e  # Exit on error

# Source shared utilities if needed
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/core-utils.sh"

# Check for active profile if required
if [[ -z "$WORKWARRIOR_BASE" ]]; then
  log_error "No active profile. Activate a profile first."
  exit 1
fi

# Service implementation
main() {
  log_info "Running my-service..."
  # Your code here
  log_success "Service completed successfully"
}

# Run main function
main "$@"
```

### Service with Templates

For services that use templates (like questions service):

```
custom/
├── my-service.sh           # Main service script
├── templates/              # Template directory
│   ├── template1.json
│   └── template2.json
├── handlers/               # Handler scripts
│   ├── handler1.sh
│   └── handler2.sh
└── README.md              # Service documentation
```

### Service with Libraries

For services with shared functionality:

```
custom/
├── my-service.sh           # Main service script
├── lib/                    # Shared libraries
│   ├── helpers.sh
│   └── validators.sh
└── README.md              # Service documentation
```

## Environment Variables

Services have access to the following environment variables when a profile is active:

- `WARRIOR_PROFILE` - Name of the active profile
- `WORKWARRIOR_BASE` - Base directory of the active profile
- `TASKRC` - Path to TaskWarrior configuration file
- `TASKDATA` - Path to TaskWarrior data directory
- `TIMEWARRIORDB` - Path to TimeWarrior data directory

## Help Shortcuts

You can access help for most built-in services via:

```bash
ww help profile
ww help service
ww help group
ww help model
ww help custom
ww help shortcut
ww help deps
```

Plural help topics (`ww help groups`, `ww help models`, `ww help journals`, `ww help ledgers`) are accepted aliases.

## Approved Command Examples Library

These examples are the curated baseline used by docs and verifier checks. Each major command family includes:
- `basic` (daily usage)
- `scoped override` (`--profile` or `--global`)
- `advanced` (automation/power-user form)

### Profile
- basic: `ww profile list`
- scoped override: `ww --profile babb profile list`
- advanced: `ww --json profile info babb`

### Service Discovery
- basic: `ww service list`
- scoped override: `ww --profile babb service info custom`
- advanced: `ww --json service list`

### Journal
- basic: `ww journal list`
- scoped override: `ww --profile babb journal list`
- advanced: `ww --json journal list`

### Ledger
- basic: `ww ledger list`
- scoped override: `ww --profile babb ledger list`
- advanced: `ww --json ledger list`

### Group
- basic: `ww group list`
- scoped override: `ww --global group list`
- advanced: `ww groups`

### Model
- basic: `ww model list`
- scoped override: `ww --global model list`
- advanced: `ww model providers`

### Find
- basic: `ww find invoice`
- scoped override: `ww find --profile babb --type task invoice`
- advanced: `ww find --type task --native invoice`

### Issues
- basic: `ww issues uda list`
- scoped override: `ww --profile babb issues uda list`
- advanced: `ww issues uda help`

### Questions
- basic: `ww q list`
- scoped override: `ww --profile babb q list`
- advanced: `ww q journal`

### Timew Extensions
- basic: `ww timew extensions list`
- scoped override: `ww --profile babb timew extensions list`
- advanced: `ww --json timew extensions list`

### Routines
- basic: `ww routines list`
- scoped override: `ww --profile babb routines list`
- advanced: `ww routines add "Clean room" --frequency weekly --run-now`

## Best Practices

### Script Guidelines

1. **Use `set -e`** - Exit immediately on error
2. **Validate inputs** - Check arguments before processing
3. **Check for active profile** - If your service requires a profile
4. **Use logging functions** - `log_info`, `log_success`, `log_warning`, `log_error`
5. **Make scripts executable** - `chmod +x service-script.sh`
6. **Include usage help** - Display help when called with `--help` or invalid arguments

### Naming Conventions

- Use lowercase with hyphens: `my-service.sh`
- Be descriptive: `export-tasks-to-csv.sh` not `export.sh`
- Use `.sh` extension for bash scripts
- Use `.py` extension for Python scripts

### Documentation

- Include a comment header with service name, category, and description
- Create a README.md for complex services
- Document required dependencies
- Provide usage examples

### Error Handling

```bash
# Good error handling
if [[ ! -f "$config_file" ]]; then
  log_error "Configuration file not found: $config_file"
  log_info "Create it with: touch $config_file"
  exit 1
fi

# Validate required tools
if ! command -v jq &> /dev/null; then
  log_error "This service requires jq. Install it with: brew install jq"
  exit 1
fi
```

### Testing

- Write tests for your services in `tests/`
- Use bats for bash script testing
- Test both success and failure cases
- Verify service works with and without active profile

## Service Discovery

The Service Registry discovers services by:

1. Scanning service category directories
2. Identifying executable scripts
3. Checking for profile-specific overrides
4. Loading service metadata from comments

Services are automatically available once placed in the appropriate category directory and made executable.

## Examples

### Simple Export Service

```bash
#!/usr/bin/env bash
# Service: export-tasks-json
# Category: export
# Description: Export all tasks to JSON format

set -e

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core-utils.sh"

if [[ -z "$WORKWARRIOR_BASE" ]]; then
  log_error "No active profile"
  exit 1
fi

output_file="${1:-tasks-export.json}"

log_info "Exporting tasks to $output_file..."
task export > "$output_file"
log_success "Exported $(task count) tasks to $output_file"
```

### Diagnostic Service

```bash
#!/usr/bin/env bash
# Service: check-profile-health
# Category: diagnostic
# Description: Verify profile integrity and configuration

set -e

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/core-utils.sh"

check_profile_health() {
  local profile_name="${1:-$WARRIOR_PROFILE}"
  
  if [[ -z "$profile_name" ]]; then
    log_error "No profile specified and no active profile"
    exit 1
  fi
  
  local profile_dir="$HOME/ww/profiles/$profile_name"
  
  log_info "Checking profile: $profile_name"
  
  # Check directories exist
  local dirs=(".task" ".task/hooks" ".timewarrior" "journals" "ledgers")
  for dir in "${dirs[@]}"; do
    if [[ -d "$profile_dir/$dir" ]]; then
      log_success "✓ $dir exists"
    else
      log_error "✗ $dir missing"
    fi
  done
  
  # Check configuration files
  local configs=(".taskrc" "jrnl.yaml" "ledgers.yaml")
  for config in "${configs[@]}"; do
    if [[ -f "$profile_dir/$config" ]]; then
      log_success "✓ $config exists"
    else
      log_error "✗ $config missing"
    fi
  done
  
  log_success "Profile health check complete"
}

check_profile_health "$@"
```

## Contributing

When adding new services:

1. Choose the appropriate category or use `custom/`
2. Follow the naming conventions and structure guidelines
3. Include proper error handling and logging
4. Document your service with comments and README
5. Test your service thoroughly
6. Make the script executable

## Support

For issues or questions about services:

1. Check service-specific README files
2. Review the main system documentation
3. Examine existing services for examples
4. Test services in isolation before integration
