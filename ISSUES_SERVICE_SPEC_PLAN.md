# Issues Service Integration Plan - Bugwarrior

## Executive Summary

Create an "issues" service that integrates bugwarrior into the Workwarrior ecosystem, allowing users to pull issues from 25+ external services (GitHub, GitLab, Jira, etc.) directly into their TaskWarrior database.

---

## 1. Bugwarrior Overview

### What is Bugwarrior?

**Bugwarrior** is a command-line utility that synchronizes issues from external issue trackers into TaskWarrior. It acts as a bridge between your TaskWarrior database and various forge/project management systems.

**Official Repository**: https://github.com/GothenburgBitFactory/bugwarrior  
**Documentation**: https://bugwarrior.readthedocs.io

### Supported Services (25+)

- **Version Control**: GitHub, GitLab, Bitbucket, Pagure, Gerrit, Git-Bug
- **Issue Trackers**: Jira, Bugzilla, Redmine, YouTrack, Phabricator, Trac
- **Project Management**: Trello, Taiga, Pivotal Tracker, Teamwork Projects, ClickUp, Linear
- **Productivity**: Todoist, Logseq, Nextcloud Deck, Kanboard
- **Email**: Gmail
- **Other**: Azure DevOps, Debian BTS

### Key Features

1. **Automatic Sync**: Pull issues from multiple services into TaskWarrior
2. **UDA Support**: Creates User Defined Attributes for service-specific metadata
3. **Filtering**: Only import assigned issues, specific projects, etc.
4. **Templates**: Customize how issues appear in TaskWarrior
5. **Hooks**: Run scripts before/after import
6. **Secret Management**: Keyring integration, password oracles
7. **Notifications**: Desktop notifications for new/updated tasks

### How It Works

```bash
# Configuration file: ~/.config/bugwarrior/bugwarriorrc (or bugwarrior.toml)
# Command: bugwarrior pull
# Result: Issues synced to TaskWarrior database
```

**Workflow**:
1. User configures services in bugwarriorrc
2. Runs `bugwarrior pull`
3. Bugwarrior fetches issues from configured services
4. Creates/updates TaskWarrior tasks with UDAs
5. Tasks appear in TaskWarrior with service-specific metadata

---

## 2. Integration Strategy

### Service Type: Profile-Bound External Tool

**Category**: `profile` (like TaskWarrior, TimeWarrior, JRNL, Hledger)  
**Requires Active Profile**: Yes  
**Configuration Location**: `$WORKWARRIOR_BASE/.config/bugwarrior/`

### Why Profile-Bound?

1. **Per-Profile Configuration**: Different profiles may track different projects
2. **Isolated Databases**: Each profile has its own TaskWarrior database
3. **Workspace Separation**: Work vs personal issue tracking
4. **Multiple Accounts**: Different GitHub/GitLab accounts per profile

---

## 3. Proposed Architecture

### Directory Structure

```
profiles/<profile-name>/
├── .task/                          # TaskWarrior database
├── .taskrc                         # TaskWarrior config
├── .timewarrior/                   # TimeWarrior data
├── .config/
│   └── bugwarrior/
│       ├── bugwarriorrc            # Bugwarrior config (INI format)
│       └── bugwarrior.toml         # Bugwarrior config (TOML format)
└── jrnl.yaml                       # JRNL config
```

### Service Location

```
services/issues/
├── README.md                       # Service documentation
├── install-bugwarrior.sh           # Installation script
├── configure-issues.sh             # Interactive configuration tool
└── examples/
    ├── github-example.ini          # Example GitHub configuration
    ├── gitlab-example.ini          # Example GitLab configuration
    ├── jira-example.ini            # Example Jira configuration
    └── multi-service-example.ini   # Multiple services example
```

### Shortcut Registry Entry

```yaml
# config/shortcuts.yaml
shortcuts:
  i:
    name: "Issues (Bugwarrior)"
    category: profile
    description: "Issue tracker sync"
    command: "bugwarrior"
    requires_profile: true
```

---

## 4. Implementation Components

### 4.1 Installation Script

**File**: `services/issues/install-bugwarrior.sh`

**Purpose**: Install bugwarrior and its dependencies

**Features**:
- Detect Python 3 availability
- Install via pip or system package manager
- Optional extras (jira, gmail, keyring, etc.)
- Verify installation
- Add to dependency checker

**Example**:
```bash
#!/usr/bin/env bash
# Install bugwarrior for the issues service

# Check Python 3
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 required"
    exit 1
fi

# Install bugwarrior
pip3 install bugwarrior

# Optional: Install extras
read -p "Install Jira support? [y/n]: " jira
if [[ "$jira" == "y" ]]; then
    pip3 install "bugwarrior[jira]"
fi

# Verify
bugwarrior --version
```

### 4.2 Configuration Service

**File**: `services/custom/configure-issues.sh`

**Purpose**: Interactive configuration tool for bugwarrior

**Features**:
1. **Service Selection**: Choose which services to configure (GitHub, GitLab, Jira, etc.)
2. **Credential Management**: Secure credential storage (keyring, password oracle)
3. **Filter Configuration**: Only assigned issues, specific projects, etc.
4. **Template Customization**: Customize task descriptions
5. **UDA Management**: Generate and add UDA definitions to .taskrc
6. **Test Configuration**: Dry-run to test settings

**Menu Structure**:
```
1. Add new service (GitHub, GitLab, Jira, etc.)
2. Edit existing service
3. Remove service
4. Configure general settings
5. Generate UDA definitions for .taskrc
6. Test configuration (dry-run)
7. View current configuration
8. Exit
```

**Service Templates**:
- GitHub: username, token, repos
- GitLab: url, token, projects
- Jira: base_uri, username, password/token
- Trello: api_key, token, boards
- Gmail: query, labels

### 4.3 Shell Integration

**Alias**: `i` (for issues)

**Function**: Wrapper around bugwarrior with profile awareness

**File**: `lib/shell-integration.sh`

**Implementation**:
```bash
# Global issues function - operates on active profile's bugwarrior config
i() {
  # Check if profile is active
  if [[ -z "$WORKWARRIOR_BASE" ]]; then
    echo "Error: No profile is active" >&2
    echo "Activate a profile first with: p-<profile-name>" >&2
    return 1
  fi

  local bugwarrior_config="$WORKWARRIOR_BASE/.config/bugwarrior"
  
  # Set BUGWARRIORRC environment variable
  if [[ -f "$bugwarrior_config/bugwarriorrc" ]]; then
    export BUGWARRIORRC="$bugwarrior_config/bugwarriorrc"
  elif [[ -f "$bugwarrior_config/bugwarrior.toml" ]]; then
    export BUGWARRIORRC="$bugwarrior_config/bugwarrior.toml"
  else
    echo "Error: Bugwarrior configuration not found" >&2
    echo "Run 'custom issues' to configure" >&2
    return 1
  fi
  
  # Handle 'i custom' command
  if [[ "$1" == "custom" ]]; then
    shift
    "$WORKWARRIOR_BASE/../../services/custom/configure-issues.sh" "$@"
    return $?
  fi
  
  # Pass to bugwarrior
  bugwarrior "$@"
}
```

### 4.4 Profile Creation Integration

**File**: `scripts/create-ww-profile.sh`

**Addition**: Create bugwarrior directory structure during profile creation

```bash
# Create bugwarrior config directory
mkdir -p "$PROFILE_DIR/.config/bugwarrior"

# Create empty config file
touch "$PROFILE_DIR/.config/bugwarrior/bugwarriorrc"

log_info "Bugwarrior configuration directory created"
```

### 4.5 Dependency Management

**File**: `lib/dependency-installer.sh`

**Addition**: Add bugwarrior to dependency checks

```bash
check_bugwarrior() {
  if command -v bugwarrior &> /dev/null; then
    BUGWARRIOR_VERSION=$(bugwarrior --version 2>&1 | head -1)
    BUGWARRIOR_INSTALLED=true
    log_success "Bugwarrior: $BUGWARRIOR_VERSION"
  else
    BUGWARRIOR_INSTALLED=false
    log_warning "Bugwarrior: Not installed"
  fi
}
```

---

## 5. User Workflows

### 5.1 Initial Setup

```bash
# 1. Activate profile
p-work

# 2. Configure issues service
i custom
# or: custom issues
# or: ww custom issues

# 3. Add GitHub service (interactive prompts)
# - Service type: GitHub
# - Username: myusername
# - Token: ghp_xxxxx
# - Repos: myorg/myrepo, myorg/another-repo

# 4. Generate UDAs and add to .taskrc
# (done automatically by configure-issues.sh)

# 5. Pull issues
i pull

# 6. View tasks
task list
```

### 5.2 Daily Usage

```bash
# Activate profile
p-work

# Pull latest issues
i pull

# Pull with dry-run (test)
i pull --dry-run

# View UDAs
i uda

# View tasks with GitHub metadata
task list project:github
```

### 5.3 Multiple Services

```bash
# Configure multiple services
i custom

# Add GitHub
# Add GitLab
# Add Jira

# Pull from all services
i pull

# Tasks are tagged by service
task list +github
task list +gitlab
task list +jira
```

---

## 6. Configuration Examples

### 6.1 GitHub Configuration

```ini
[general]
targets = my_github

[my_github]
service = github
github.login = myusername
github.token = @oracle:use_keyring
github.username = myusername
github.include_repos = myorg/repo1, myorg/repo2
github.only_if_assigned = myusername
```

### 6.2 Multiple Services

```ini
[general]
targets = my_github, my_gitlab, my_jira

[my_github]
service = github
github.login = myusername
github.token = @oracle:use_keyring
github.username = myusername

[my_gitlab]
service = gitlab
gitlab.host = gitlab.com
gitlab.login = myusername
gitlab.token = @oracle:use_keyring

[my_jira]
service = jira
jira.base_uri = https://mycompany.atlassian.net
jira.username = myemail@company.com
jira.password = @oracle:use_keyring
```

### 6.3 Advanced Filtering

```ini
[my_github]
service = github
github.login = myusername
github.token = @oracle:use_keyring
github.username = myusername
github.only_if_assigned = myusername
github.also_unassigned = false
github.add_tags = github, work
github.description_template = GH#{{githubnumber}}: {{githubtitle}}
github.default_priority = H
```

---

## 7. Integration Points

### 7.1 Shortcuts Registry

**File**: `config/shortcuts.yaml`

```yaml
i:
  name: "Issues (Bugwarrior)"
  category: profile
  description: "Issue tracker sync"
  command: "i"
  requires_profile: true
```

### 7.2 Shell Configuration

**File**: `~/.bashrc` (via `lib/shell-integration.sh`)

**Additions**:
```bash
# --- Workwarrior Core Functions ---

# Global issues function
i() {
  if [[ -z "$WORKWARRIOR_BASE" ]]; then
    echo "Error: No profile is active" >&2
    return 1
  fi
  
  local bugwarrior_config="$WORKWARRIOR_BASE/.config/bugwarrior"
  
  if [[ -f "$bugwarrior_config/bugwarriorrc" ]]; then
    export BUGWARRIORRC="$bugwarrior_config/bugwarriorrc"
  elif [[ -f "$bugwarrior_config/bugwarrior.toml" ]]; then
    export BUGWARRIORRC="$bugwarrior_config/bugwarrior.toml"
  fi
  
  if [[ "$1" == "custom" ]]; then
    shift
    "$WORKWARRIOR_BASE/../../services/custom/configure-issues.sh" "$@"
    return $?
  fi
  
  bugwarrior "$@"
}
```

### 7.3 Profile Aliases

**File**: `~/.bashrc` (via `scripts/create-ww-profile.sh`)

```bash
# -- Workwarrior Profile Aliases ---
alias p-work='use_task_profile work'
alias work='use_task_profile work'

# Issues alias (automatically available via i() function)
# No separate alias needed - i() function handles it
```

### 7.4 Main CLI Integration

**File**: `bin/ww`

**Addition**: Add issues command

```bash
cmd_issues() {
  local action="${1:-}"
  shift 2>/dev/null || true

  case "$action" in
    pull)
      bugwarrior pull "$@"
      ;;
    uda)
      bugwarrior uda "$@"
      ;;
    configure|config)
      "$WW_BASE/services/custom/configure-issues.sh" "$@"
      ;;
    ""|help|-h|--help)
      cat << EOF
Issues Management (Bugwarrior)

Usage: ww issues <action> [arguments]

Actions:
  pull       Pull issues from configured services
  uda        List bugwarrior-managed UDAs
  configure  Configure issue services

Examples:
  ww issues pull           Pull issues
  ww issues pull --dry-run Test configuration
  ww issues uda            List UDAs
  ww issues configure      Configure services

Note: Requires an active profile.
Activate a profile with: p-<profile-name>

EOF
      ;;
    *)
      log_error "Unknown issues action: $action"
      echo "Run 'ww issues help' for usage"
      exit 1
      ;;
  esac
}
```

### 7.5 Help System

**File**: `services/help/README.md`

**Addition**: Document issues service

```markdown
## Issues Service (Bugwarrior)

Sync issues from external trackers into TaskWarrior.

### Supported Services
- GitHub, GitLab, Bitbucket
- Jira, Bugzilla, Redmine, YouTrack
- Trello, Todoist, Gmail
- And 15+ more...

### Commands
- `i pull` - Pull issues from configured services
- `i uda` - List bugwarrior UDAs
- `i custom` - Configure services

### Configuration
- Location: `$WORKWARRIOR_BASE/.config/bugwarrior/bugwarriorrc`
- Format: INI or TOML
- Interactive setup: `i custom`

### Examples
```bash
# Activate profile
p-work

# Configure GitHub
i custom

# Pull issues
i pull

# View tasks
task list +github
```
```

---

## 8. UDA Management

### 8.1 Automatic UDA Generation

Bugwarrior creates UDAs for each service. These must be added to `.taskrc`.

**Process**:
1. Run `bugwarrior uda` to get UDA definitions
2. Append to `.taskrc`
3. Reload TaskWarrior

**Example UDAs (GitHub)**:
```
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
```

### 8.2 Configure-Issues Integration

The `configure-issues.sh` script should:
1. Generate UDAs after service configuration
2. Check if UDAs already exist in `.taskrc`
3. Append new UDAs automatically
4. Create backup of `.taskrc` before modification

---

## 9. Security Considerations

### 9.1 Credential Storage

**Options**:
1. **Keyring** (Recommended): `@oracle:use_keyring`
2. **Password Prompt**: `@oracle:ask_password`
3. **External Command**: `@oracle:eval:pass my/password`
4. **Plain Text** (Not Recommended): Direct in config file

**Implementation**:
```bash
# In configure-issues.sh
echo "How would you like to store credentials?"
echo "  1. System keyring (recommended)"
echo "  2. Prompt at runtime"
echo "  3. External password manager (e.g., pass)"
echo "  4. Plain text (not recommended)"
```

### 9.2 Token Permissions

**GitHub**: Personal Access Token with `repo` scope  
**GitLab**: Personal Access Token with `read_api` scope  
**Jira**: API Token or Personal Access Token

**Documentation**: Provide clear instructions for creating tokens with minimal permissions.

---

## 10. Testing Strategy

### 10.1 Installation Testing

```bash
# Test bugwarrior installation
bugwarrior --version

# Test with dry-run
bugwarrior pull --dry-run

# Test UDA generation
bugwarrior uda
```

### 10.2 Configuration Testing

```bash
# Test configuration service
custom issues

# Test with minimal GitHub config
# Verify config file created
# Test pull with dry-run
```

### 10.3 Integration Testing

```bash
# Create test profile
ww profile create test-issues

# Activate profile
p-test-issues

# Configure test service
i custom

# Pull issues (dry-run)
i pull --dry-run

# Pull issues (real)
i pull

# Verify tasks created
task list
```

---

## 11. Documentation Requirements

### 11.1 Service README

**File**: `services/issues/README.md`

**Sections**:
1. Overview
2. Installation
3. Configuration
4. Supported Services
5. Usage Examples
6. UDA Management
7. Troubleshooting
8. Advanced Features

### 11.2 User Guide

**File**: `docs/issues-service.md`

**Sections**:
1. Getting Started
2. Service-Specific Guides (GitHub, GitLab, Jira, etc.)
3. Filtering and Templates
4. Automation (cron jobs)
5. Best Practices
6. FAQ

### 11.3 Example Configurations

**Directory**: `services/issues/examples/`

**Files**:
- `github-example.ini`
- `gitlab-example.ini`
- `jira-example.ini`
- `multi-service-example.ini`
- `advanced-filtering-example.ini`

---

## 12. Automation Opportunities

### 12.1 Cron Job

**Purpose**: Automatically pull issues on a schedule

**Example**:
```bash
# Add to crontab
*/30 * * * * source ~/.bashrc && p-work && i pull --quiet
```

### 12.2 Git Hooks

**Purpose**: Pull issues before/after git operations

**Example**: `.git/hooks/post-checkout`
```bash
#!/bin/bash
source ~/.bashrc
p-work
i pull --quiet
```

### 12.3 Profile Activation Hook

**Purpose**: Pull issues when activating profile

**Implementation**: Add to `use_task_profile()` function
```bash
# Optional: Auto-pull issues on profile activation
if [[ -f "$profile_base/.config/bugwarrior/bugwarriorrc" ]]; then
  echo "Pulling issues..."
  bugwarrior pull --quiet 2>/dev/null || true
fi
```

---

## 13. Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Research and planning (DONE)
- [ ] Create service directory structure
- [ ] Add bugwarrior to dependency installer
- [ ] Create installation script
- [ ] Update shortcuts registry

### Phase 2: Shell Integration (Week 1-2)
- [ ] Add `i()` function to shell-integration.sh
- [ ] Update profile creation script
- [ ] Add profile aliases
- [ ] Test shell integration

### Phase 3: Configuration Service (Week 2-3)
- [ ] Create configure-issues.sh
- [ ] Implement service templates
- [ ] Add UDA management
- [ ] Add credential management
- [ ] Test configuration workflow

### Phase 4: CLI Integration (Week 3)
- [ ] Add issues command to bin/ww
- [ ] Update main help text
- [ ] Add to custom services
- [ ] Test CLI commands

### Phase 5: Documentation (Week 4)
- [ ] Create service README
- [ ] Create user guide
- [ ] Add example configurations
- [ ] Update main documentation

### Phase 6: Testing & Polish (Week 4)
- [ ] End-to-end testing
- [ ] Multiple service testing
- [ ] Error handling improvements
- [ ] User feedback incorporation

---

## 14. Success Criteria

### Must Have
- ✓ Bugwarrior installed and accessible
- ✓ Profile-specific configuration
- ✓ `i` command works with active profile
- ✓ Basic GitHub/GitLab configuration
- ✓ UDA management
- ✓ Documentation

### Should Have
- ✓ Interactive configuration tool
- ✓ Multiple service support
- ✓ Credential management
- ✓ Example configurations
- ✓ Integration with ww CLI

### Nice to Have
- ✓ Automation (cron)
- ✓ Advanced filtering
- ✓ Template customization
- ✓ Notification support
- ✓ Git hooks integration

---

## 15. Risks and Mitigations

### Risk 1: Python Dependency
**Impact**: Users without Python 3  
**Mitigation**: Clear installation instructions, system package manager options

### Risk 2: API Rate Limits
**Impact**: GitHub/GitLab API limits  
**Mitigation**: Document rate limits, suggest caching strategies

### Risk 3: Configuration Complexity
**Impact**: Users overwhelmed by options  
**Mitigation**: Interactive configuration tool, templates, examples

### Risk 4: UDA Conflicts
**Impact**: Existing UDAs conflict with bugwarrior  
**Mitigation**: Check before adding, backup .taskrc, clear documentation

### Risk 5: Security
**Impact**: Credentials in plain text  
**Mitigation**: Keyring support, password oracles, clear security guidance

---

## 16. Future Enhancements

### 16.1 Custom Service Plugins
Allow users to create custom bugwarrior service plugins for internal tools.

### 16.2 Bi-Directional Sync
Sync changes from TaskWarrior back to issue trackers (requires bugwarrior extension).

### 16.3 Conflict Resolution
Handle conflicts when issues are modified in both TaskWarrior and source system.

### 16.4 Bulk Operations
Bulk import/export, bulk tag management, bulk filtering.

### 16.5 Web UI
Optional web interface for configuration and monitoring.

---

## 17. References

- **Bugwarrior GitHub**: https://github.com/GothenburgBitFactory/bugwarrior
- **Bugwarrior Docs**: https://bugwarrior.readthedocs.io
- **TaskWarrior UDAs**: https://taskwarrior.org/docs/udas.html
- **GitHub API**: https://docs.github.com/en/rest
- **GitLab API**: https://docs.gitlab.com/ee/api/
- **Jira API**: https://developer.atlassian.com/cloud/jira/platform/rest/v3/

---

## 18. Next Steps

1. **Review this plan** with stakeholders
2. **Create spec document** in `.kiro/specs/issues-service/`
3. **Begin Phase 1** implementation
4. **Iterate based on feedback**

---

**Document Version**: 1.0  
**Created**: 2024-02-11  
**Status**: Planning Complete - Ready for Spec Creation
