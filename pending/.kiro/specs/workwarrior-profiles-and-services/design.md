# Design Document: Workwarrior Profiles System and Services Registry

## Overview

The Workwarrior Profiles System and Services Registry is a shell-based productivity framework that integrates TaskWarrior, TimeWarrior, JRNL, and Hledger into isolated, switchable profiles. The system provides a plugin architecture for extensible services while maintaining strict data isolation between profiles.

### Key Design Principles

1. **Isolation First**: Each profile maintains completely separate data and configuration
2. **Shell-Native**: Deep integration with bash for seamless command-line workflows
3. **Extensible by Default**: Service-based architecture allows adding functionality without core modifications
4. **Convention over Configuration**: Sensible defaults with customization options
5. **Fail-Safe Operations**: Validation and error handling prevent data corruption

### Technology Stack

- **Shell**: Bash 4.0+ for scripting and integration
- **TaskWarrior**: Task management (v3.0+)
- **TimeWarrior**: Time tracking (v1.4+)
- **JRNL**: Journaling (v4.0+)
- **Hledger**: Financial tracking (v1.30+)
- **Python**: For hook scripts and JSON processing (v3.8+)

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                     User Shell (Bash)                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Aliases    │  │  Functions   │  │ Environment  │      │
│  │ p-profile    │  │ j(), l()     │  │  Variables   │      │
│  │ j-profile    │  │ use_task_    │  │ TASKRC, etc  │      │
│  │ l-ledger     │  │  profile()   │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Profile Management Layer                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Profile Manager                                      │  │
│  │  - create_profile()                                   │  │
│  │  - delete_profile()                                   │  │
│  │  - list_profiles()                                    │  │
│  │  - backup_profile()                                   │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Service Registry                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Profile    │  │  Questions   │  │   Export     │      │
│  │   Service    │  │   Service    │  │   Service    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Diagnostic   │  │    Find      │  │   Verify     │      │
│  │   Service    │  │   Service    │  │   Service    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Profile Storage                           │
│  ~/ww/profiles/<profile-name>/                              │
│  ├── .taskrc                                                 │
│  ├── .task/                                                  │
│  │   ├── taskchampion.sqlite3                              │
│  │   └── hooks/                                             │
│  │       └── on-modify.timewarrior                         │
│  ├── .timewarrior/                                          │
│  │   ├── timewarrior.cfg                                   │
│  │   └── data/                                              │
│  ├── journals/                                               │
│  │   ├── <profile-name>.txt                                │
│  │   └── <journal-name>.txt                                │
│  ├── ledgers/                                                │
│  │   └── <ledger-name>.journal                             │
│  ├── jrnl.yaml                                              │
│  ├── ledgers.yaml                                           │
│  └── services/                                               │
│      └── <service-category>/                                │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

#### Profile Activation Flow

```
User: p-work
    │
    ▼
use_task_profile("work")
    │
    ├─> Validate profile exists
    │
    ├─> Export WARRIOR_PROFILE="work"
    ├─> Export WORKWARRIOR_BASE="~/ww/profiles/work"
    ├─> Export TASKRC="~/ww/profiles/work/.taskrc"
    ├─> Export TASKDATA="~/ww/profiles/work/.task"
    └─> Export TIMEWARRIORDB="~/ww/profiles/work/.timewarrior"
    │
    ▼
Display confirmation message
```

#### Journal Entry Flow

```
User: j "Today's entry"
    │
    ▼
j() function
    │
    ├─> Check WORKWARRIOR_BASE is set
    │
    ├─> Locate jrnl.yaml: $WORKWARRIOR_BASE/jrnl.yaml
    │
    ├─> Execute: jrnl --config-file <path> "Today's entry"
    │
    └─> JRNL writes to default journal
```

#### Named Journal Entry Flow

```
User: j work-log "Completed feature X"
    │
    ▼
j() function
    │
    ├─> Parse arguments: journal_name="work-log", entry="Completed feature X"
    │
    ├─> Check WORKWARRIOR_BASE is set
    │
    ├─> Locate jrnl.yaml: $WORKWARRIOR_BASE/jrnl.yaml
    │
    ├─> Validate journal_name exists in jrnl.yaml
    │
    ├─> Execute: jrnl --config-file <path> work-log "Completed feature X"
    │
    └─> JRNL writes to named journal
```

#### Task Start with Time Tracking Flow

```
User: task start 42
    │
    ▼
TaskWarrior (using TASKRC, TASKDATA)
    │
    ├─> Load task 42
    ├─> Set start time
    ├─> Trigger on-modify hook
    │
    ▼
on-modify.timewarrior hook
    │
    ├─> Read task JSON from stdin
    ├─> Detect task started
    ├─> Execute: timew start <task-description>
    │   (using TIMEWARRIORDB)
    ├─> Output modified task JSON to stdout
    │
    ▼
TaskWarrior saves modified task
```

## Components and Interfaces

### Profile Manager Component

**Responsibilities:**
- Create, delete, list, and backup profiles
- Initialize profile directory structure
- Manage configuration files
- Validate profile names and operations

**Interface:**

```bash
# Command-line interface
create-ww-profile.sh <profile-name>
manage-profiles.sh create <profile-name>
manage-profiles.sh delete <profile-name>
manage-profiles.sh list
manage-profiles.sh info <profile-name>
manage-profiles.sh backup <profile-name> [destination]

# Internal functions
create_profile(name: string) -> Result<ProfilePath, Error>
delete_profile(name: string) -> Result<void, Error>
list_profiles() -> List<string>
profile_exists(name: string) -> bool
validate_profile_name(name: string) -> Result<void, Error>
```

**Configuration:**
- Profile base directory: `~/ww/profiles`
- Template directory: `~/ww/resources/config-files`
- Default taskrc: `~/ww/functions/tasks/default-taskrc/.taskrc`

### Shell Integration Component

**Responsibilities:**
- Manage shell aliases and functions
- Handle profile activation
- Provide global tool access functions
- Maintain environment variables

**Interface:**

```bash
# Global functions
use_task_profile(profile_name: string) -> void
j([journal_name: string], entry: string) -> void
l([ledger_name: string], ...args) -> void

# Alias patterns
alias p-<profile-name>='use_task_profile <profile-name>'
alias <profile-name>='use_task_profile <profile-name>'
alias j-<profile-name>='jrnl --config-file <path>'
alias l-<ledger-name>='hledger -f <path>'

# Environment variables
WARRIOR_PROFILE: string          # Active profile name
WORKWARRIOR_BASE: string         # Profile base directory
TASKRC: string                   # Path to .taskrc
TASKDATA: string                 # Path to .task directory
TIMEWARRIORDB: string            # Path to .timewarrior directory
```

**Shell Configuration Management:**

```bash
# Section markers in ~/.bashrc
"# -- Workwarrior Profile Aliases ---"
"# -- Direct Alias for Journals ---"
"# -- Direct Aliases for Hledger ---"
"# --- Workwarrior Core Functions ---"

# Functions
add_alias_to_section(alias_line: string, section_marker: string) -> void
ensure_section_exists(section_marker: string) -> void
alias_exists(alias_line: string) -> bool
```

### Service Registry Component

**Responsibilities:**
- Organize services by category
- Discover available services
- Provide service access interface
- Support profile-specific service overrides

**Interface:**

```bash
# Directory structure
~/ww/services/<category>/<service-files>
<profile-base>/services/<category>/<service-files>

# Service categories
- profile/      # Profile management
- questions/    # Question templates
- scripts/      # Utility scripts
- export/       # Data export
- diagnostic/   # System diagnostics
- find/         # Search and discovery
- verify/       # Validation
- custom/       # User-defined services

# Service discovery
discover_services(category: string) -> List<ServiceInfo>
get_service_path(category: string, service: string) -> Path
service_exists(category: string, service: string) -> bool
```

**Service Structure:**

```
service-category/
├── service-script.sh          # Main service script
├── lib/                       # Shared libraries
│   └── helper-functions.sh
├── templates/                 # Service templates
│   └── template.json
├── handlers/                  # Processing handlers
│   └── handler.sh
└── README.md                  # Service documentation
```

### Questions Service Component

**Responsibilities:**
- Manage question templates
- Prompt users for structured input
- Process answers through handlers
- Integrate with productivity tools

**Interface:**

```bash
# Command-line interface
q                              # Show help
q <service>                    # List templates for service
q <service> <template>         # Use template
q new                          # Create custom template
q new <service>                # Create template for service
q list                         # List all templates
q edit <template>              # Edit template
q delete <template>            # Delete template

# Internal functions
create_template(service: string, name: string, questions: List<Question>) -> Result<Path, Error>
use_template(service: string, template: string) -> Result<void, Error>
prompt_questions(template: Template) -> Result<Answers, Error>
process_answers(service: string, answers: Answers) -> Result<void, Error>
```

**Template Format (JSON):**

```json
{
  "name": "Daily Standup",
  "description": "Daily standup questions",
  "service": "journal",
  "questions": [
    {
      "id": "q1",
      "text": "What did you accomplish yesterday?",
      "type": "text",
      "required": true
    },
    {
      "id": "q2",
      "text": "What will you work on today?",
      "type": "text",
      "required": true
    },
    {
      "id": "q3",
      "text": "Any blockers?",
      "type": "text",
      "required": false
    }
  ],
  "output_format": {
    "title": "Daily Standup - {date}",
    "tags": ["standup", "daily"]
  }
}
```

**Handler Interface:**

```bash
# Handler script signature
handler.sh <template-file> <answers-file>

# Answers file format (JSON)
{
  "template": "/path/to/template.json",
  "timestamp": "2024-01-15T14:30:00",
  "answers": {
    "q1": "Completed feature X",
    "q2": "Will work on feature Y",
    "q3": "Waiting for API access"
  }
}
```

### Configuration Manager Component

**Responsibilities:**
- Generate configuration files
- Update paths in configurations
- Validate configuration syntax
- Manage configuration templates

**Interface:**

```bash
# TaskRC management
create_taskrc(profile_base: string, template: Path) -> Result<void, Error>
update_taskrc_paths(taskrc: Path, profile_base: string) -> Result<void, Error>
validate_taskrc(taskrc: Path) -> Result<void, Error>

# JRNL configuration
create_jrnl_config(profile_base: string, journals: Map<string, Path>) -> Result<void, Error>
add_journal_to_config(config: Path, journal_name: string, journal_path: Path) -> Result<void, Error>
list_journals_in_config(config: Path) -> Result<List<string>, Error>

# Ledger configuration
create_ledger_config(profile_base: string, ledgers: Map<string, Path>) -> Result<void, Error>
add_ledger_to_config(config: Path, ledger_name: string, ledger_path: Path) -> Result<void, Error>
```

**Configuration File Formats:**

**.taskrc:**
```ini
data.location=/absolute/path/to/.task
hooks.location=/absolute/path/to/.task/hooks
hooks=1
# ... other TaskWarrior settings
```

**jrnl.yaml:**
```yaml
journals:
  default: /absolute/path/to/journals/profile.txt
  work-log: /absolute/path/to/journals/work-log.txt
  personal: /absolute/path/to/journals/personal.txt
editor: nano
encrypt: false
tagsymbols: '@'
default_hour: 9
default_minute: 0
timeformat: "%Y-%m-%d %H:%M"
highlight: true
linewrap: 79
colors:
  body: none
  date: blue
  tags: yellow
  title: cyan
```

**ledgers.yaml:**
```yaml
ledgers:
  main: /absolute/path/to/ledgers/profile.journal
  business: /absolute/path/to/ledgers/business.journal
  personal: /absolute/path/to/ledgers/personal.journal
```

## Data Models

### Profile Model

```typescript
interface Profile {
  name: string;                    // Profile identifier
  base_path: string;               // Absolute path to profile directory
  created_at: Date;                // Creation timestamp
  
  // Configuration files
  taskrc: string;                  // Path to .taskrc
  jrnl_config: string;             // Path to jrnl.yaml
  ledger_config: string;           // Path to ledgers.yaml
  
  // Data directories
  task_data: string;               // Path to .task directory
  timewarrior_db: string;          // Path to .timewarrior directory
  journals_dir: string;            // Path to journals directory
  ledgers_dir: string;             // Path to ledgers directory
  services_dir: string;            // Path to profile services directory
  
  // Metadata
  disk_usage: number;              // Size in bytes
  task_count: number;              // Number of tasks
  journal_count: number;           // Number of journals
  ledger_count: number;            // Number of ledgers
}
```

### Service Model

```typescript
interface Service {
  name: string;                    // Service identifier
  category: string;                // Service category
  path: string;                    // Absolute path to service directory
  type: ServiceType;               // script | function | module
  
  // Optional components
  templates_dir?: string;          // Path to templates directory
  handlers_dir?: string;           // Path to handlers directory
  lib_dir?: string;                // Path to library directory
  config_file?: string;            // Path to service configuration
  
  // Metadata
  description: string;             // Service description
  version: string;                 // Service version
  dependencies: string[];          // Required services
}

enum ServiceType {
  Script = "script",               // Executable script
  Function = "function",           // Shell function
  Module = "module"                // Python/other module
}
```

### Template Model

```typescript
interface Template {
  name: string;                    // Display name
  description: string;             // Template description
  service: string;                 // Target service (task, journal, etc.)
  questions: Question[];           // List of questions
  output_format: OutputFormat;     // Output formatting options
}

interface Question {
  id: string;                      // Question identifier
  text: string;                    // Question prompt
  type: QuestionType;              // Question type
  required: boolean;               // Whether answer is required
  default?: string;                // Default value
  validation?: ValidationRule;     // Validation rule
}

enum QuestionType {
  Text = "text",                   // Free-form text
  Number = "number",               // Numeric input
  Date = "date",                   // Date input
  Choice = "choice",               // Multiple choice
  MultiChoice = "multi-choice"     // Multiple selection
}

interface OutputFormat {
  title: string;                   // Output title template
  description?: string;            // Output description
  tags: string[];                  // Tags to apply
  format?: string;                 // Custom format string
}
```

### Journal Model

```typescript
interface Journal {
  name: string;                    // Journal identifier
  file_path: string;               // Absolute path to journal file
  profile: string;                 // Parent profile name
  
  // Metadata
  entry_count: number;             // Number of entries
  first_entry: Date;               // Date of first entry
  last_entry: Date;                // Date of last entry
  size: number;                    // File size in bytes
  encrypted: boolean;              // Whether journal is encrypted
}
```

### Ledger Model

```typescript
interface Ledger {
  name: string;                    // Ledger identifier
  file_path: string;               // Absolute path to ledger file
  profile: string;                 // Parent profile name
  
  // Metadata
  transaction_count: number;       // Number of transactions
  account_count: number;           // Number of accounts
  first_transaction: Date;         // Date of first transaction
  last_transaction: Date;          // Date of last transaction
  size: number;                    // File size in bytes
}
```

### Environment State Model

```typescript
interface EnvironmentState {
  active_profile: string | null;   // Currently active profile
  workwarrior_base: string | null; // WORKWARRIOR_BASE value
  taskrc: string | null;           // TASKRC value
  taskdata: string | null;         // TASKDATA value
  timewarriordb: string | null;    // TIMEWARRIORDB value
  
  // Shell state
  aliases: Map<string, string>;    // Active aliases
  functions: Set<string>;          // Loaded functions
  
  // Validation
  is_valid(): boolean;             // Check if state is consistent
  validate_paths(): boolean;       // Verify all paths exist
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*


### Property 1: Complete Directory Structure Creation

*For any* valid profile name, when a profile is created, the Profile_Manager should create all required directories (.task, .task/hooks, .timewarrior, journals, ledgers) within the profile base directory, and all parent directories should exist.

**Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.9, 1.10**

### Property 2: Profile Name Validation

*For any* string containing characters outside [a-zA-Z0-9_-], the Profile_Manager should reject it as an invalid profile name and return an error.

**Validates: Requirements 2.2**

### Property 3: Default Configuration Initialization

*For any* profile created without custom configuration options, the Profile_Manager should create valid default configuration files (.taskrc, jrnl.yaml, ledgers.yaml) and initialize default journal and ledger files with welcome entries.

**Validates: Requirements 2.9, 2.10**

### Property 4: Profile Deletion Completeness

*For any* existing profile, after deletion, the profile directory should not exist and all associated aliases should be removed from ~/.bashrc.

**Validates: Requirements 3.3, 3.4**

### Property 5: Backup Filename Timestamp

*For any* profile backup operation, the generated backup filename should contain a timestamp in the format YYYYMMDDHHMMSS.

**Validates: Requirements 3.7**

### Property 6: Profile List Sorting

*For any* set of existing profiles, the list command should return profile names in lexicographically sorted order.

**Validates: Requirements 3.9**

### Property 7: Error Exit Codes

*For any* profile operation that fails (invalid name, non-existent profile, permission error), the command should return a non-zero exit code.

**Validates: Requirements 3.10**

### Property 8: Complete Alias Creation

*For any* created profile with name N, the Shell_Integration should create aliases p-N, N, and j-N in ~/.bashrc, and for each ledger L, create alias l-L.

**Validates: Requirements 4.1, 4.2, 4.3, 4.4**

### Property 9: Alias Section Organization

*For any* alias added to ~/.bashrc, it should appear after its designated section marker and before the next section marker or end of file.

**Validates: Requirements 4.5**

### Property 10: Alias Idempotence

*For any* profile, creating it multiple times should result in each alias appearing exactly once in ~/.bashrc (idempotence property).

**Validates: Requirements 4.6**

### Property 11: Global Function Error Handling

*For any* call to global functions (j, l) when no profile is active (WORKWARRIOR_BASE is unset), the function should display an error message and return a non-zero exit code.

**Validates: Requirements 4.10, 8.18, 9.9**

### Property 12: Complete Environment Variable Export

*For any* profile activation, all required environment variables (WARRIOR_PROFILE, WORKWARRIOR_BASE, TASKRC, TASKDATA, TIMEWARRIORDB) should be exported with correct absolute paths pointing to the activated profile.

**Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5**

### Property 13: Invalid Profile Activation Error

*For any* non-existent profile name, attempting to activate it should display an error message and return a non-zero exit code.

**Validates: Requirements 5.8**

### Property 14: Profile Switching Updates Environment

*For any* two existing profiles A and B, switching from A to B should update all environment variables to point to B's directories and configuration files.

**Validates: Requirements 5.9**

### Property 15: TaskRC Path Configuration

*For any* created profile, the .taskrc file should have data.location and hooks.location set to absolute paths pointing to the profile's .task and .task/hooks directories respectively, and hooks should be enabled (hooks=1).

**Validates: Requirements 6.1, 6.2, 6.3, 6.10**

### Property 16: TaskRC Copy Path Update

*For any* profile created by copying another profile's .taskrc, all path references (data.location, hooks.location) should be updated to point to the new profile's directories, while all other settings (UDAs, reports, urgency coefficients) should be preserved.

**Validates: Requirements 6.4, 6.5, 6.6, 6.7, 6.8**

### Property 17: TimeWarrior Hook Installation

*For any* created profile, the on-modify.timewarrior hook should exist at .task/hooks/on-modify.timewarrior and be executable (have execute permissions).

**Validates: Requirements 7.1, 7.2, 7.3, 7.4**

### Property 18: Hook Environment Variable Usage

*For any* execution of the on-modify.timewarrior hook, it should use the TIMEWARRIORDB environment variable to determine the TimeWarrior data location.

**Validates: Requirements 7.10**

### Property 19: Journal System Initialization

*For any* created profile with name N, a default journal file should exist at journals/N.txt with a welcome entry, and jrnl.yaml should exist with the default journal configured and proper editor, timeformat, and display settings.

**Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.5**

### Property 20: Multiple Journals Support

*For any* profile, the jrnl.yaml file should support multiple named journal entries, each mapping a journal name to an absolute file path.

**Validates: Requirements 8.6**

### Property 21: Journal Routing by Name

*For any* active profile with journals J1, J2, ..., Jn defined in jrnl.yaml, calling `j J1 "entry"` should write to J1's file, calling `j J2 "entry"` should write to J2's file, and calling `j "entry"` should write to the default journal.

**Validates: Requirements 8.11, 8.12, 8.13, 8.14**

### Property 22: Invalid Journal Name Error

*For any* active profile, calling `j` with a journal name that doesn't exist in jrnl.yaml should display an error message listing all available journals.

**Validates: Requirements 8.15**

### Property 23: Journal Addition

*For any* existing profile, adding a new journal should create the journal file and update jrnl.yaml with the new journal entry.

**Validates: Requirements 8.16, 8.17**

### Property 24: Ledger System Initialization

*For any* created profile with name N, a default ledger file should exist at ledgers/N.journal with account declarations and an opening entry, and ledgers.yaml should exist with the default ledger configured.

**Validates: Requirements 9.1, 9.2, 9.3, 9.4**

### Property 25: Ledger Naming Convention

*For any* created profile with name N, the default ledger file should be named N.journal.

**Validates: Requirements 9.10**

### Property 26: Ledger Alias Creation

*For any* profile with ledgers L1, L2, ..., Ln, the Shell_Integration should create aliases l-L1, l-L2, ..., l-Ln in ~/.bashrc.

**Validates: Requirements 9.6, 9.7**

### Property 27: Profile-Specific Service Override

*For any* service S that exists both in ~/ww/services/category/S and in <active-profile>/services/category/S, the system should use the profile-specific version when the profile is active.

**Validates: Requirements 11.3, 11.4**

### Property 28: Service Discovery

*For any* service category C, the Service_Registry should discover all services in ~/ww/services/C/ by scanning for executable scripts and shell functions.

**Validates: Requirements 14.1, 14.2, 14.3, 14.4, 14.5**

### Property 29: Configuration Path Updates

*For any* configuration file copied from one profile to another, all absolute paths should be updated to reference the destination profile's directories.

**Validates: Requirements 16.5, 16.6, 16.7**

### Property 30: Data Isolation

*For any* two profiles A and B, when profile A is active, all operations (task, timew, jrnl, hledger) should only read from and write to A's directories, never B's directories.

**Validates: Requirements 19.1, 19.2, 19.3, 19.4, 19.5, 19.6, 19.7**

### Property 31: Environment Variable Atomic Update

*For any* profile switch operation, either all environment variables should be updated to the new profile, or none should be updated (atomic update property).

**Validates: Requirements 19.8**

### Property 32: Backup Completeness

*For any* profile backup operation, the resulting tar.gz archive should contain all profile directories (.task, .timewarrior, journals, ledgers, services if present) and all configuration files (.taskrc, jrnl.yaml, ledgers.yaml).

**Validates: Requirements 20.1, 20.2, 20.3, 20.4, 20.5**

### Property 33: Backup Portability

*For any* profile backup archive, extracting it to a different system and updating paths in configuration files should result in a fully functional profile.

**Validates: Requirements 20.10**

## Error Handling

### Error Categories

1. **Validation Errors**
   - Invalid profile names (special characters, too long)
   - Invalid paths (non-existent directories, permission issues)
   - Invalid configuration syntax

2. **State Errors**
   - Profile already exists
   - Profile doesn't exist
   - No active profile
   - Conflicting operations

3. **System Errors**
   - Disk space issues
   - Permission denied
   - Missing dependencies (task, timew, jrnl, hledger)
   - File system errors

4. **Configuration Errors**
   - Malformed configuration files
   - Missing required fields
   - Invalid paths in configuration

### Error Handling Strategy

**Validation First:**
- Validate all inputs before performing operations
- Check profile name format before creating directories
- Verify paths exist before reading/writing
- Validate configuration syntax before applying

**Fail-Safe Operations:**
- Use atomic operations where possible
- Create temporary files before overwriting
- Backup before destructive operations
- Rollback on failure

**Clear Error Messages:**
```bash
# Good error message format
echo "Error: Profile 'my-profile' already exists at ~/ww/profiles/my-profile" >&2
echo "Use 'manage-profiles.sh delete my-profile' to remove it first" >&2
return 1

# Include context
echo "Error: Cannot activate profile 'work'" >&2
echo "Profile directory not found: ~/ww/profiles/work" >&2
echo "Available profiles:" >&2
list_profiles
return 1
```

**Error Recovery:**
- Provide suggestions for fixing errors
- List available options when selection is invalid
- Offer to create missing directories/files
- Suggest commands to resolve issues

### Error Handling Implementation

```bash
# Profile name validation
validate_profile_name() {
  local name="$1"
  
  if [[ -z "$name" ]]; then
    log_error "Profile name cannot be empty"
    return 1
  fi
  
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Profile name must contain only letters, numbers, hyphens, and underscores"
    log_error "Invalid name: '$name'"
    return 1
  fi
  
  if (( ${#name} > 50 )); then
    log_error "Profile name cannot exceed 50 characters (got ${#name})"
    return 1
  fi
  
  return 0
}

# Profile existence check
ensure_profile_exists() {
  local name="$1"
  local profile_dir="$PROFILES_DIR/$name"
  
  if [[ ! -d "$profile_dir" ]]; then
    log_error "Profile '$name' does not exist"
    log_info "Available profiles:"
    list_profiles | sed 's/^/  /'
    return 1
  fi
  
  return 0
}

# Active profile check
require_active_profile() {
  if [[ -z "$WORKWARRIOR_BASE" ]]; then
    log_error "No profile is currently active"
    log_info "Activate a profile with: p-<profile-name>"
    log_info "Available profiles:"
    list_profiles | sed 's/^/  /'
    return 1
  fi
  
  return 0
}

# Configuration file validation
validate_jrnl_config() {
  local config_file="$1"
  
  if [[ ! -f "$config_file" ]]; then
    log_error "JRNL configuration not found: $config_file"
    return 1
  fi
  
  # Validate YAML syntax using Python
  if ! python3 -c "import yaml; yaml.safe_load(open('$config_file'))" 2>/dev/null; then
    log_error "Invalid YAML syntax in: $config_file"
    return 1
  fi
  
  # Check required fields
  if ! grep -q "^journals:" "$config_file"; then
    log_error "Missing 'journals' section in: $config_file"
    return 1
  fi
  
  return 0
}
```

## Testing Strategy

### Dual Testing Approach

The system requires both unit tests and property-based tests for comprehensive coverage:

**Unit Tests:**
- Specific examples of profile creation, deletion, activation
- Edge cases: empty names, special characters, very long names
- Error conditions: non-existent profiles, permission issues
- Integration points: TaskWarrior hooks, JRNL configuration
- Shell alias creation and removal
- Configuration file parsing and generation

**Property-Based Tests:**
- Universal properties across all valid inputs
- Profile name validation across random strings
- Directory structure completeness for random profile names
- Environment variable correctness for random profile switches
- Configuration path updates for random profile copies
- Data isolation across random operation sequences

### Property-Based Testing Configuration

**Testing Library:** Use `bats` (Bash Automated Testing System) with custom property test helpers for bash scripts, and `pytest` with `hypothesis` for Python components.

**Test Configuration:**
- Minimum 100 iterations per property test
- Each test tagged with feature name and property number
- Tag format: `# Feature: workwarrior-profiles-and-services, Property N: <property text>`

**Example Property Test Structure:**

```bash
#!/usr/bin/env bats
# Feature: workwarrior-profiles-and-services

# Property 1: Complete Directory Structure Creation
@test "Property 1: Profile creation creates all required directories" {
  # Feature: workwarrior-profiles-and-services, Property 1: Complete Directory Structure Creation
  
  for i in {1..100}; do
    # Generate random valid profile name
    profile_name="test-$(random_alphanumeric 10)"
    
    # Create profile
    run create-ww-profile.sh "$profile_name"
    assert_success
    
    # Verify all directories exist
    assert_dir_exists "$HOME/ww/profiles/$profile_name"
    assert_dir_exists "$HOME/ww/profiles/$profile_name/.task"
    assert_dir_exists "$HOME/ww/profiles/$profile_name/.task/hooks"
    assert_dir_exists "$HOME/ww/profiles/$profile_name/.timewarrior"
    assert_dir_exists "$HOME/ww/profiles/$profile_name/journals"
    assert_dir_exists "$HOME/ww/profiles/$profile_name/ledgers"
    
    # Cleanup
    rm -rf "$HOME/ww/profiles/$profile_name"
  done
}

# Property 2: Profile Name Validation
@test "Property 2: Invalid characters are rejected" {
  # Feature: workwarrior-profiles-and-services, Property 2: Profile Name Validation
  
  invalid_chars=('!' '@' '#' '$' '%' '^' '&' '*' '(' ')' '+' '=' '[' ']' '{' '}' '|' '\' ';' ':' '"' "'" '<' '>' ',' '.' '?' '/' '~' '`')
  
  for i in {1..100}; do
    # Generate name with random invalid character
    char="${invalid_chars[$RANDOM % ${#invalid_chars[@]}]}"
    profile_name="test${char}profile"
    
    # Attempt to create profile
    run create-ww-profile.sh "$profile_name"
    assert_failure
    assert_output --partial "invalid"
  done
}

# Property 30: Data Isolation
@test "Property 30: Operations on profile A never affect profile B" {
  # Feature: workwarrior-profiles-and-services, Property 30: Data Isolation
  
  for i in {1..100}; do
    # Create two profiles
    profile_a="test-a-$(random_alphanumeric 8)"
    profile_b="test-b-$(random_alphanumeric 8)"
    
    create-ww-profile.sh "$profile_a"
    create-ww-profile.sh "$profile_b"
    
    # Activate profile A
    source <(use_task_profile "$profile_a")
    
    # Perform operations
    task add "Test task for A"
    jrnl "Test entry for A"
    
    # Get counts for A
    task_count_a=$(task count)
    journal_lines_a=$(wc -l < "$HOME/ww/profiles/$profile_a/journals/$profile_a.txt")
    
    # Verify B is unchanged
    task_count_b=$(TASKRC="$HOME/ww/profiles/$profile_b/.taskrc" task count)
    journal_lines_b=$(wc -l < "$HOME/ww/profiles/$profile_b/journals/$profile_b.txt")
    
    assert_equal "$task_count_b" "0"
    assert_equal "$journal_lines_b" "1"  # Only welcome entry
    
    # Cleanup
    rm -rf "$HOME/ww/profiles/$profile_a"
    rm -rf "$HOME/ww/profiles/$profile_b"
  done
}
```

### Unit Test Examples

```bash
#!/usr/bin/env bats

@test "Create profile with default configuration" {
  profile_name="test-default"
  
  run create-ww-profile.sh "$profile_name"
  assert_success
  
  # Verify configuration files exist
  assert_file_exists "$HOME/ww/profiles/$profile_name/.taskrc"
  assert_file_exists "$HOME/ww/profiles/$profile_name/jrnl.yaml"
  assert_file_exists "$HOME/ww/profiles/$profile_name/ledgers.yaml"
  
  # Verify default journal has welcome entry
  assert_file_contains "$HOME/ww/profiles/$profile_name/journals/$profile_name.txt" "Welcome"
  
  # Cleanup
  manage-profiles.sh delete "$profile_name"
}

@test "Delete profile removes all files and aliases" {
  profile_name="test-delete"
  
  # Create profile
  create-ww-profile.sh "$profile_name"
  assert_dir_exists "$HOME/ww/profiles/$profile_name"
  
  # Delete profile
  run manage-profiles.sh delete "$profile_name"
  assert_success
  
  # Verify directory is gone
  assert_dir_not_exists "$HOME/ww/profiles/$profile_name"
  
  # Verify aliases are removed
  assert_not_in_file "$HOME/.bashrc" "p-$profile_name"
  assert_not_in_file "$HOME/.bashrc" "j-$profile_name"
}

@test "Profile activation sets all environment variables" {
  profile_name="test-env"
  
  # Create profile
  create-ww-profile.sh "$profile_name"
  
  # Activate profile
  source <(use_task_profile "$profile_name")
  
  # Verify environment variables
  assert_equal "$WARRIOR_PROFILE" "$profile_name"
  assert_equal "$WORKWARRIOR_BASE" "$HOME/ww/profiles/$profile_name"
  assert_equal "$TASKRC" "$HOME/ww/profiles/$profile_name/.taskrc"
  assert_equal "$TASKDATA" "$HOME/ww/profiles/$profile_name/.task"
  assert_equal "$TIMEWARRIORDB" "$HOME/ww/profiles/$profile_name/.timewarrior"
  
  # Cleanup
  manage-profiles.sh delete "$profile_name"
}

@test "Global j function writes to correct journal" {
  profile_name="test-journal"
  
  # Create profile
  create-ww-profile.sh "$profile_name"
  
  # Activate profile
  source <(use_task_profile "$profile_name")
  
  # Write to default journal
  j "Test entry 1"
  
  # Verify entry was written
  assert_file_contains "$HOME/ww/profiles/$profile_name/journals/$profile_name.txt" "Test entry 1"
  
  # Cleanup
  manage-profiles.sh delete "$profile_name"
}

@test "Named journal routing works correctly" {
  profile_name="test-multi-journal"
  
  # Create profile
  create-ww-profile.sh "$profile_name"
  
  # Add additional journal
  add-journal.sh "$profile_name" "work-log"
  
  # Activate profile
  source <(use_task_profile "$profile_name")
  
  # Write to named journal
  j work-log "Work entry 1"
  
  # Write to default journal
  j "Default entry 1"
  
  # Verify entries went to correct journals
  assert_file_contains "$HOME/ww/profiles/$profile_name/journals/work-log.txt" "Work entry 1"
  assert_file_not_contains "$HOME/ww/profiles/$profile_name/journals/work-log.txt" "Default entry 1"
  assert_file_contains "$HOME/ww/profiles/$profile_name/journals/$profile_name.txt" "Default entry 1"
  assert_file_not_contains "$HOME/ww/profiles/$profile_name/journals/$profile_name.txt" "Work entry 1"
  
  # Cleanup
  manage-profiles.sh delete "$profile_name"
}
```

### Integration Testing

**TaskWarrior + TimeWarrior Integration:**
```bash
@test "Starting task starts time tracking" {
  profile_name="test-integration"
  
  # Create and activate profile
  create-ww-profile.sh "$profile_name"
  source <(use_task_profile "$profile_name")
  
  # Add and start task
  task add "Test task"
  task 1 start
  
  # Verify TimeWarrior is tracking
  timew_output=$(timew)
  assert_output --partial "Test task"
  
  # Stop task
  task 1 stop
  
  # Verify TimeWarrior stopped
  timew_output=$(timew)
  assert_output --partial "There is no active time tracking"
  
  # Cleanup
  manage-profiles.sh delete "$profile_name"
}
```

### Test Coverage Goals

- **Unit Tests**: 80%+ code coverage
- **Property Tests**: All correctness properties implemented
- **Integration Tests**: All tool integrations verified
- **Error Handling**: All error paths tested

### Continuous Testing

- Run unit tests on every commit
- Run property tests nightly (due to longer execution time)
- Run integration tests before releases
- Monitor test execution time and optimize slow tests
