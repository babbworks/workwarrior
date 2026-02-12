#!/usr/bin/env bash
# Profile Manager Library
# Functions for creating, managing, and configuring profiles
# Source this file: source "$(dirname "$0")/../lib/profile-manager.sh"

# Source core utilities if not already loaded
if [[ -z "$CORE_UTILS_LOADED" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "$SCRIPT_DIR/core-utils.sh"
fi

# ============================================================================
# PROFILE DIRECTORY STRUCTURE CREATION
# ============================================================================

# Create complete profile directory structure
# Creates all required directories for a profile:
#   - Base profile directory
#   - .task directory for TaskWarrior data
#   - .task/hooks directory for TaskWarrior hooks
#   - .timewarrior directory for TimeWarrior data
#   - journals directory for JRNL text files
#   - ledgers directory for Hledger journal files
#
# Usage: create_profile_directories "profile-name"
# Returns: 0 on success, 1 on failure
# Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.9, 1.10
create_profile_directories() {
  local profile_name="$1"
  
  # Validate profile name
  if ! validate_profile_name "$profile_name"; then
    return 1
  fi
  
  local profile_base="$PROFILES_DIR/$profile_name"
  
  log_step "Creating profile directory structure for '$profile_name'"
  
  # Create base profile directory
  if ! ensure_directory "$profile_base"; then
    log_error "Failed to create profile base directory"
    return 1
  fi
  
  # Create .task directory and subdirectories
  if ! ensure_directory "$profile_base/.task"; then
    log_error "Failed to create .task directory"
    return 1
  fi
  
  if ! ensure_directory "$profile_base/.task/hooks"; then
    log_error "Failed to create .task/hooks directory"
    return 1
  fi
  
  # Create .timewarrior directory
  if ! ensure_directory "$profile_base/.timewarrior"; then
    log_error "Failed to create .timewarrior directory"
    return 1
  fi
  
  # Create journals directory
  if ! ensure_directory "$profile_base/journals"; then
    log_error "Failed to create journals directory"
    return 1
  fi
  
  # Create ledgers directory
  if ! ensure_directory "$profile_base/ledgers"; then
    log_error "Failed to create ledgers directory"
    return 1
  fi
  
  # Create .config/bugwarrior directory for issues service
  if ! ensure_directory "$profile_base/.config/bugwarrior"; then
    log_error "Failed to create .config/bugwarrior directory"
    return 1
  fi
  
  # Create bugwarriorrc template
  local bugwarriorrc="$profile_base/.config/bugwarrior/bugwarriorrc"
  if [[ ! -f "$bugwarriorrc" ]]; then
    cat > "$bugwarriorrc" << 'EOF'
# Bugwarrior Configuration
# Run 'i custom' to configure issue synchronization services
#
# Supported services: GitHub, GitLab, Jira, Trello, Todoist, and 20+ more
# Documentation: https://bugwarrior.readthedocs.io
#
# ⚠️  IMPORTANT: One-Way Sync Only
# Bugwarrior pulls issues FROM external services TO TaskWarrior.
# Changes in TaskWarrior do NOT sync back to issue trackers.

[general]
targets = my_tasks

EOF
    chmod 600 "$bugwarriorrc"
    log_info "Created bugwarriorrc template"
  fi
  
  log_success "Profile directory structure created at: $profile_base"
  return 0
}

# ============================================================================
# TASKWARRIOR CONFIGURATION MANAGEMENT
# ============================================================================

# Create .taskrc configuration file for a profile
# Loads from template if available, otherwise creates minimal default
# Updates paths to use absolute paths pointing to profile directories
# Enables hooks for TimeWarrior integration
#
# Usage: create_taskrc "profile-name"
# Returns: 0 on success, 1 on failure
# Validates: Requirements 6.1, 6.2, 6.3, 6.9, 6.10
create_taskrc() {
  local profile_name="$1"

  # Validate profile name
  if ! validate_profile_name "$profile_name"; then
    return 1
  fi

  local profile_base="$PROFILES_DIR/$profile_name"
  local taskrc_path="$profile_base/.taskrc"
  local task_data_dir="$profile_base/.task"
  local hooks_dir="$profile_base/.task/hooks"

  log_step "Creating .taskrc configuration for '$profile_name'"

  # Check if profile directory exists
  if [[ ! -d "$profile_base" ]]; then
    log_error "Profile directory does not exist: $profile_base"
    return 1
  fi

  # Try to load template from DEFAULT_TASKRC
  local template_source=""
  if [[ -f "$DEFAULT_TASKRC" ]]; then
    template_source="$DEFAULT_TASKRC"
    log_info "Using template from: $DEFAULT_TASKRC"
  elif [[ -f "$CONFIG_TEMPLATES_DIR/.taskrc" ]]; then
    template_source="$CONFIG_TEMPLATES_DIR/.taskrc"
    log_info "Using template from: $CONFIG_TEMPLATES_DIR/.taskrc"
  fi

  # Create .taskrc from template or minimal default
  if [[ -n "$template_source" ]]; then
    # Copy template and update paths
    if ! cp "$template_source" "$taskrc_path"; then
      log_error "Failed to copy template from: $template_source"
      return 1
    fi

    # Update data.location to absolute path
    sed -i.bak "s|^data\.location=.*|data.location=$task_data_dir|" "$taskrc_path"

    # Update hooks.location to absolute path
    sed -i.bak "s|^hooks\.location=.*|hooks.location=$hooks_dir|" "$taskrc_path"

    # Ensure hooks are enabled (handle both hooks=on and hooks=1 formats)
    if grep -q "^hooks=" "$taskrc_path"; then
      sed -i.bak "s|^hooks=.*|hooks=on|" "$taskrc_path"
    else
      echo "hooks=on" >> "$taskrc_path"
    fi

    # Remove backup file
    rm -f "$taskrc_path.bak"

  else
    # Create minimal default .taskrc
    log_info "No template found, creating minimal default .taskrc"

    cat > "$taskrc_path" << EOF
# TaskWarrior Configuration for profile: $profile_name
# Created: $(date)

# Data and hooks locations (absolute paths)
data.location=$task_data_dir
hooks.location=$hooks_dir
hooks=on

# Basic settings
verbose=blank,footnote,label,new-id,affected,edit,special,project,sync,unwait

# TimeWarrior integration UDA
uda.timetracked.type=duration
uda.timetracked.label=Time-Tracked

# Color theme (uncomment one to use)
#include dark-256.theme
#include light-256.theme
#include solarized-dark-256.theme
#include solarized-light-256.theme
EOF
  fi

  # Verify the file was created
  if [[ ! -f "$taskrc_path" ]]; then
    log_error "Failed to create .taskrc at: $taskrc_path"
    return 1
  fi

  # Verify required settings are present
  if ! grep -q "^data\.location=" "$taskrc_path"; then
    log_error ".taskrc missing data.location setting"
    return 1
  fi

  if ! grep -q "^hooks\.location=" "$taskrc_path"; then
    log_error ".taskrc missing hooks.location setting"
    return 1
  fi

  if ! grep -q "^hooks=" "$taskrc_path"; then
    log_error ".taskrc missing hooks setting"
    return 1
  fi

  log_success ".taskrc created at: $taskrc_path"
  return 0
}

# Copy .taskrc from an existing profile to a new profile
# Copies the source profile's .taskrc and updates only the paths
# Preserves all other settings including:
#   - User Defined Attributes (UDAs)
#   - Report configurations
#   - Urgency coefficients
#   - Context definitions
#   - Color themes
#   - All other custom settings
#
# Usage: copy_taskrc_from_profile "source-profile" "dest-profile"
# Returns: 0 on success, 1 on failure
# Validates: Requirements 6.4, 6.5, 6.6, 6.7, 6.8
copy_taskrc_from_profile() {
  local source_profile="$1"
  local dest_profile="$2"

  # Validate both profile names
  if ! validate_profile_name "$source_profile"; then
    log_error "Invalid source profile name"
    return 1
  fi

  if ! validate_profile_name "$dest_profile"; then
    log_error "Invalid destination profile name"
    return 1
  fi

  local source_base="$PROFILES_DIR/$source_profile"
  local dest_base="$PROFILES_DIR/$dest_profile"
  local source_taskrc="$source_base/.taskrc"
  local dest_taskrc="$dest_base/.taskrc"
  local dest_task_data="$dest_base/.task"
  local dest_hooks_dir="$dest_base/.task/hooks"

  log_step "Copying .taskrc from '$source_profile' to '$dest_profile'"

  # Check if source profile exists
  if [[ ! -d "$source_base" ]]; then
    log_error "Source profile does not exist: $source_profile"
    return 1
  fi

  # Check if source .taskrc exists
  if [[ ! -f "$source_taskrc" ]]; then
    log_error "Source .taskrc not found: $source_taskrc"
    return 1
  fi

  # Check if destination profile exists
  if [[ ! -d "$dest_base" ]]; then
    log_error "Destination profile does not exist: $dest_profile"
    return 1
  fi

  # Copy the .taskrc file
  if ! cp "$source_taskrc" "$dest_taskrc"; then
    log_error "Failed to copy .taskrc from $source_taskrc to $dest_taskrc"
    return 1
  fi

  log_info "Copied .taskrc from source profile"

  # Update data.location to point to destination profile's .task directory
  # This preserves all other settings while only updating the path
  if grep -q "^data\.location=" "$dest_taskrc"; then
    sed -i.bak "s|^data\.location=.*|data.location=$dest_task_data|" "$dest_taskrc"
    log_info "Updated data.location to: $dest_task_data"
  else
    # If data.location doesn't exist, add it
    echo "data.location=$dest_task_data" >> "$dest_taskrc"
    log_info "Added data.location: $dest_task_data"
  fi

  # Update hooks.location to point to destination profile's hooks directory
  if grep -q "^hooks\.location=" "$dest_taskrc"; then
    sed -i.bak "s|^hooks\.location=.*|hooks.location=$dest_hooks_dir|" "$dest_taskrc"
    log_info "Updated hooks.location to: $dest_hooks_dir"
  else
    # If hooks.location doesn't exist, add it
    echo "hooks.location=$dest_hooks_dir" >> "$dest_taskrc"
    log_info "Added hooks.location: $dest_hooks_dir"
  fi

  # Ensure hooks are enabled (preserve existing format if present)
  if grep -q "^hooks=" "$dest_taskrc"; then
    # Keep existing hooks setting (might be hooks=on or hooks=1)
    log_info "Preserved existing hooks setting"
  else
    # Add hooks=on if not present
    echo "hooks=on" >> "$dest_taskrc"
    log_info "Added hooks=on"
  fi

  # Remove backup file created by sed
  rm -f "$dest_taskrc.bak"

  # Verify the file was created successfully
  if [[ ! -f "$dest_taskrc" ]]; then
    log_error "Failed to create .taskrc at: $dest_taskrc"
    return 1
  fi

  # Verify required settings are present
  if ! grep -q "^data\.location=" "$dest_taskrc"; then
    log_error ".taskrc missing data.location setting"
    return 1
  fi

  if ! grep -q "^hooks\.location=" "$dest_taskrc"; then
    log_error ".taskrc missing hooks.location setting"
    return 1
  fi

  log_success ".taskrc copied and updated at: $dest_taskrc"
  log_info "All UDAs, reports, urgency coefficients, and other settings preserved"
  return 0
}

# ============================================================================
# TIMEWARRIOR HOOK INSTALLATION
# ============================================================================

# Install TimeWarrior hook for TaskWarrior integration
# Copies hook from template if available, otherwise creates basic Python hook
# Makes hook executable and ensures it uses TIMEWARRIORDB environment variable
#
# Usage: install_timewarrior_hook "profile-name"
# Returns: 0 on success, 1 on failure
# Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.10
install_timewarrior_hook() {
  local profile_name="$1"

  # Validate profile name
  if ! validate_profile_name "$profile_name"; then
    return 1
  fi

  local profile_base="$PROFILES_DIR/$profile_name"
  local hooks_dir="$profile_base/.task/hooks"
  local hook_path="$hooks_dir/on-modify.timewarrior"
  local template_path="$WW_BASE/services/profile/on-modify.timewarrior"

  log_step "Installing TimeWarrior hook for '$profile_name'"

  # Check if profile directory exists
  if [[ ! -d "$profile_base" ]]; then
    log_error "Profile directory does not exist: $profile_base"
    return 1
  fi

  # Check if hooks directory exists
  if [[ ! -d "$hooks_dir" ]]; then
    log_error "Hooks directory does not exist: $hooks_dir"
    return 1
  fi

  # Try to copy from template if it exists
  if [[ -f "$template_path" ]]; then
    log_info "Using hook template from: $template_path"
    
    if ! cp "$template_path" "$hook_path"; then
      log_error "Failed to copy hook template from: $template_path"
      return 1
    fi
    
    log_info "Copied hook template to: $hook_path"
  else
    # Create basic Python hook script
    log_info "No template found, creating basic Python hook script"
    
    cat > "$hook_path" <<'EOF'
#!/usr/bin/env python3

###############################################################################
# Basic TimeWarrior Hook for TaskWarrior Integration
# Automatically starts/stops time tracking when tasks are started/stopped
###############################################################################

import json
import subprocess
import sys

try:
    input_stream = sys.stdin.buffer
except AttributeError:
    input_stream = sys.stdin


def extract_tags_from(json_obj):
    """Extract attributes for use as tags."""
    tags = [json_obj['description']]

    if 'project' in json_obj:
        tags.append(json_obj['project'])

    if 'tags' in json_obj:
        tags.extend(json_obj['tags'])

    return tags


def main(old, new):
    """Process task modifications and update TimeWarrior accordingly."""
    start_or_stop = ''

    # Started task
    if 'start' in new and 'start' not in old:
        start_or_stop = 'start'

    # Stopped task
    elif ('start' not in new or 'end' in new) and 'start' in old:
        start_or_stop = 'stop'

    if start_or_stop:
        tags = extract_tags_from(new)
        subprocess.call(['timew', start_or_stop] + tags + [':yes'])

    # Modifications to task other than start/stop
    elif 'start' in new and 'start' in old:
        old_tags = extract_tags_from(old)
        new_tags = extract_tags_from(new)

        if old_tags != new_tags:
            subprocess.call(['timew', 'untag', '@1'] + old_tags + [':yes'])
            subprocess.call(['timew', 'tag', '@1'] + new_tags + [':yes'])


if __name__ == "__main__":
    old = json.loads(input_stream.readline().decode("utf-8", errors="replace"))
    new = json.loads(input_stream.readline().decode("utf-8", errors="replace"))
    print(json.dumps(new))
    main(old, new)
EOF

    if [[ ! -f "$hook_path" ]]; then
      log_error "Failed to create hook script at: $hook_path"
      return 1
    fi
    
    log_info "Created basic hook script at: $hook_path"
  fi

  # Make hook executable
  if ! chmod +x "$hook_path"; then
    log_error "Failed to make hook executable: $hook_path"
    return 1
  fi

  log_success "TimeWarrior hook installed and made executable"
  log_info "Hook will use TIMEWARRIORDB environment variable for data location"
  
  return 0
}

# ============================================================================
# JOURNAL MANAGEMENT
# ============================================================================

# Create journal configuration for a profile
# Creates default journal file with welcome entry and timestamp
# Generates jrnl.yaml with default journal configuration
# Sets editor, timeformat, encryption, and display options
# Supports multiple named journals in configuration
#
# Usage: create_journal_config "profile-name"
# Returns: 0 on success, 1 on failure
# Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.5, 8.6
create_journal_config() {
  local profile_name="$1"

  # Validate profile name
  if ! validate_profile_name "$profile_name"; then
    return 1
  fi

  local profile_base="$PROFILES_DIR/$profile_name"
  local journals_dir="$profile_base/journals"
  local default_journal="$journals_dir/$profile_name.txt"
  local jrnl_config="$profile_base/jrnl.yaml"

  log_step "Creating journal configuration for '$profile_name'"

  # Check if profile directory exists
  if [[ ! -d "$profile_base" ]]; then
    log_error "Profile directory does not exist: $profile_base"
    return 1
  fi

  # Check if journals directory exists
  if [[ ! -d "$journals_dir" ]]; then
    log_error "Journals directory does not exist: $journals_dir"
    return 1
  fi

  # Create default journal file with welcome entry and timestamp
  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M")
  
  cat > "$default_journal" << EOF
[$timestamp] Welcome to your journal!

This is the default journal for the '$profile_name' profile.
You can add entries using the 'j' command when this profile is active.

EOF

  if [[ ! -f "$default_journal" ]]; then
    log_error "Failed to create default journal file: $default_journal"
    return 1
  fi

  log_info "Created default journal with welcome entry: $default_journal"

  # Create jrnl.yaml configuration file
  cat > "$jrnl_config" << EOF
journals:
  default: $default_journal
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
EOF

  if [[ ! -f "$jrnl_config" ]]; then
    log_error "Failed to create jrnl.yaml configuration: $jrnl_config"
    return 1
  fi

  log_success "Journal configuration created at: $jrnl_config"
  log_info "Default journal: $default_journal"
  
  return 0
}

# Add a new journal to an existing profile
# Creates new journal file
# Updates jrnl.yaml with new journal entry
# Validates journal name doesn't already exist
#
# Usage: add_journal_to_profile "profile-name" "journal-name"
# Returns: 0 on success, 1 on failure
# Validates: Requirements 8.16, 8.17
add_journal_to_profile() {
  local profile_name="$1"
  local journal_name="$2"

  # Validate profile name
  if ! validate_profile_name "$profile_name"; then
    return 1
  fi

  # Validate journal name (use same validation as profile names)
  if [[ -z "$journal_name" ]]; then
    log_error "Journal name cannot be empty"
    return 1
  fi

  if [[ ! "$journal_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Journal name must contain only letters, numbers, hyphens, and underscores"
    log_error "Invalid name: '$journal_name'"
    return 1
  fi

  local profile_base="$PROFILES_DIR/$profile_name"
  local journals_dir="$profile_base/journals"
  local journal_file="$journals_dir/$journal_name.txt"
  local jrnl_config="$profile_base/jrnl.yaml"

  log_step "Adding journal '$journal_name' to profile '$profile_name'"

  # Check if profile directory exists
  if [[ ! -d "$profile_base" ]]; then
    log_error "Profile directory does not exist: $profile_base"
    return 1
  fi

  # Check if jrnl.yaml exists
  if [[ ! -f "$jrnl_config" ]]; then
    log_error "Journal configuration not found: $jrnl_config"
    return 1
  fi

  # Check if journal already exists in configuration
  if grep -q "^  $journal_name:" "$jrnl_config"; then
    log_error "Journal '$journal_name' already exists in configuration"
    return 1
  fi

  # Check if journal file already exists
  if [[ -f "$journal_file" ]]; then
    log_warning "Journal file already exists: $journal_file"
  else
    # Create new journal file with welcome entry and timestamp
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M")
    
    cat > "$journal_file" << EOF
[$timestamp] Welcome to the '$journal_name' journal!

This journal is part of the '$profile_name' profile.

EOF

    if [[ ! -f "$journal_file" ]]; then
      log_error "Failed to create journal file: $journal_file"
      return 1
    fi

    log_info "Created journal file: $journal_file"
  fi

  # Add journal entry to jrnl.yaml
  # Insert after the "journals:" line
  if ! awk -v journal="$journal_name" -v path="$journal_file" '
    /^journals:/ {
      print
      print "  " journal ": " path
      next
    }
    { print }
  ' "$jrnl_config" > "$jrnl_config.tmp"; then
    log_error "Failed to update jrnl.yaml"
    rm -f "$jrnl_config.tmp"
    return 1
  fi

  # Replace original with updated version
  if ! mv "$jrnl_config.tmp" "$jrnl_config"; then
    log_error "Failed to save updated jrnl.yaml"
    rm -f "$jrnl_config.tmp"
    return 1
  fi

  log_success "Journal '$journal_name' added to profile '$profile_name'"
  log_info "Journal file: $journal_file"
  
  return 0
}

# Copy journal configuration from an existing profile to a new profile
# Copies journal text files from source profile
# Updates file paths in jrnl.yaml to point to destination profile
#
# Usage: copy_journal_from_profile "source-profile" "dest-profile"
# Returns: 0 on success, 1 on failure
# Validates: Requirements 8.7, 8.8
copy_journal_from_profile() {
  local source_profile="$1"
  local dest_profile="$2"

  # Validate both profile names
  if ! validate_profile_name "$source_profile"; then
    log_error "Invalid source profile name"
    return 1
  fi

  if ! validate_profile_name "$dest_profile"; then
    log_error "Invalid destination profile name"
    return 1
  fi

  local source_base="$PROFILES_DIR/$source_profile"
  local dest_base="$PROFILES_DIR/$dest_profile"
  local source_journals_dir="$source_base/journals"
  local dest_journals_dir="$dest_base/journals"
  local source_jrnl_config="$source_base/jrnl.yaml"
  local dest_jrnl_config="$dest_base/jrnl.yaml"

  log_step "Copying journal configuration from '$source_profile' to '$dest_profile'"

  # Check if source profile exists
  if [[ ! -d "$source_base" ]]; then
    log_error "Source profile does not exist: $source_profile"
    return 1
  fi

  # Check if source jrnl.yaml exists
  if [[ ! -f "$source_jrnl_config" ]]; then
    log_error "Source jrnl.yaml not found: $source_jrnl_config"
    return 1
  fi

  # Check if destination profile exists
  if [[ ! -d "$dest_base" ]]; then
    log_error "Destination profile does not exist: $dest_profile"
    return 1
  fi

  # Check if destination journals directory exists
  if [[ ! -d "$dest_journals_dir" ]]; then
    log_error "Destination journals directory does not exist: $dest_journals_dir"
    return 1
  fi

  # Copy all journal text files from source to destination
  if [[ -d "$source_journals_dir" ]]; then
    local journal_count=0
    for journal_file in "$source_journals_dir"/*.txt; do
      if [[ -f "$journal_file" ]]; then
        local filename
        filename=$(basename "$journal_file")
        
        if ! cp "$journal_file" "$dest_journals_dir/$filename"; then
          log_error "Failed to copy journal file: $filename"
          return 1
        fi
        
        log_info "Copied journal file: $filename"
        ((journal_count++))
      fi
    done
    
    if [[ $journal_count -eq 0 ]]; then
      log_warning "No journal files found in source profile"
    else
      log_info "Copied $journal_count journal file(s)"
    fi
  else
    log_warning "Source journals directory not found: $source_journals_dir"
  fi

  # Copy jrnl.yaml and update paths
  if ! cp "$source_jrnl_config" "$dest_jrnl_config"; then
    log_error "Failed to copy jrnl.yaml from $source_jrnl_config to $dest_jrnl_config"
    return 1
  fi

  log_info "Copied jrnl.yaml from source profile"

  # Update all file paths in jrnl.yaml to point to destination profile
  # Replace source profile base path with destination profile base path
  if ! sed -i.bak "s|$source_base|$dest_base|g" "$dest_jrnl_config"; then
    log_error "Failed to update paths in jrnl.yaml"
    return 1
  fi

  # Remove backup file created by sed
  rm -f "$dest_jrnl_config.bak"

  log_success "Journal configuration copied and updated"
  log_info "Updated paths in: $dest_jrnl_config"
  
  return 0
}

# ============================================================================
# LIBRARY LOADED INDICATOR
# ============================================================================

readonly PROFILE_MANAGER_LOADED=1


# ============================================================================
# LEDGER MANAGEMENT
# ============================================================================

# Create ledger configuration for a profile
# Creates default ledger file with account declarations and opening entry
# Generates ledgers.yaml with default ledger configuration
# Ensures default ledger is named after profile
#
# Usage: create_ledger_config "profile-name"
# Returns: 0 on success, 1 on failure
# Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.10
create_ledger_config() {
  local profile_name="$1"

  # Validate profile name
  if ! validate_profile_name "$profile_name"; then
    return 1
  fi

  local profile_base="$PROFILES_DIR/$profile_name"
  local ledgers_dir="$profile_base/ledgers"
  local default_ledger="$ledgers_dir/$profile_name.journal"
  local ledger_config="$profile_base/ledgers.yaml"
  local default_accounts_template="$HOME/ww/functions/ledgers/defaultaccounts/defaccounts.txt"

  log_step "Creating ledger configuration for '$profile_name'"

  # Check if profile directory exists
  if [[ ! -d "$profile_base" ]]; then
    log_error "Profile directory does not exist: $profile_base"
    return 1
  fi

  # Check if ledgers directory exists
  if [[ ! -d "$ledgers_dir" ]]; then
    log_error "Ledgers directory does not exist: $ledgers_dir"
    return 1
  fi

  # Create default ledger file with account declarations and opening entry
  local current_date
  current_date=$(date "+%Y-%m-%d")
  
  # Try to use template if available, otherwise create basic default
  if [[ -f "$default_accounts_template" ]]; then
    log_info "Using account template from: $default_accounts_template"
    cat "$default_accounts_template" > "$default_ledger"
    
    # Add opening entry after account declarations
    cat >> "$default_ledger" << EOF

; Opening entry for profile: $profile_name
$current_date * Opening Balance
    Assets:Checking                 \$0.00
    Equity:Opening Balances

EOF
  else
    log_info "No template found, creating basic default ledger"
    
    cat > "$default_ledger" << EOF
; Hledger Journal for profile: $profile_name
; Created: $(date)

; Account declarations
account Assets:Checking
account Assets:Savings
account Expenses:Food
account Expenses:Transportation
account Expenses:Utilities
account Expenses:Entertainment
account Income:Salary
account Liabilities:CreditCard
account Equity:Opening Balances

; Opening entry
$current_date * Opening Balance
    Assets:Checking                 \$0.00
    Equity:Opening Balances

EOF
  fi

  if [[ ! -f "$default_ledger" ]]; then
    log_error "Failed to create default ledger file: $default_ledger"
    return 1
  fi

  log_info "Created default ledger with account declarations: $default_ledger"

  # Create ledgers.yaml configuration file
  cat > "$ledger_config" << EOF
ledgers:
  default: $default_ledger
EOF

  if [[ ! -f "$ledger_config" ]]; then
    log_error "Failed to create ledgers.yaml configuration: $ledger_config"
    return 1
  fi

  log_success "Ledger configuration created at: $ledger_config"
  log_info "Default ledger: $default_ledger"
  
  return 0
}

# Copy ledger configuration from an existing profile to a new profile
# Copies ledger journal files from source profile
# Updates file paths in ledgers.yaml to point to destination profile
#
# Usage: copy_ledger_from_profile "source-profile" "dest-profile"
# Returns: 0 on success, 1 on failure
# Validates: Requirements 9.5
copy_ledger_from_profile() {
  local source_profile="$1"
  local dest_profile="$2"

  # Validate both profile names
  if ! validate_profile_name "$source_profile"; then
    log_error "Invalid source profile name"
    return 1
  fi

  if ! validate_profile_name "$dest_profile"; then
    log_error "Invalid destination profile name"
    return 1
  fi

  local source_base="$PROFILES_DIR/$source_profile"
  local dest_base="$PROFILES_DIR/$dest_profile"
  local source_ledgers_dir="$source_base/ledgers"
  local dest_ledgers_dir="$dest_base/ledgers"
  local source_ledger_config="$source_base/ledgers.yaml"
  local dest_ledger_config="$dest_base/ledgers.yaml"

  log_step "Copying ledger configuration from '$source_profile' to '$dest_profile'"

  # Check if source profile exists
  if [[ ! -d "$source_base" ]]; then
    log_error "Source profile does not exist: $source_profile"
    return 1
  fi

  # Check if source ledgers.yaml exists
  if [[ ! -f "$source_ledger_config" ]]; then
    log_error "Source ledgers.yaml not found: $source_ledger_config"
    return 1
  fi

  # Check if destination profile exists
  if [[ ! -d "$dest_base" ]]; then
    log_error "Destination profile does not exist: $dest_profile"
    return 1
  fi

  # Check if destination ledgers directory exists
  if [[ ! -d "$dest_ledgers_dir" ]]; then
    log_error "Destination ledgers directory does not exist: $dest_ledgers_dir"
    return 1
  fi

  # Copy all ledger journal files from source to destination
  if [[ -d "$source_ledgers_dir" ]]; then
    local ledger_count=0
    for ledger_file in "$source_ledgers_dir"/*.journal; do
      if [[ -f "$ledger_file" ]]; then
        local filename
        filename=$(basename "$ledger_file")
        
        if ! cp "$ledger_file" "$dest_ledgers_dir/$filename"; then
          log_error "Failed to copy ledger file: $filename"
          return 1
        fi
        
        log_info "Copied ledger file: $filename"
        ((ledger_count++))
      fi
    done
    
    if [[ $ledger_count -eq 0 ]]; then
      log_warning "No ledger files found in source profile"
    else
      log_info "Copied $ledger_count ledger file(s)"
    fi
  else
    log_warning "Source ledgers directory not found: $source_ledgers_dir"
  fi

  # Copy ledgers.yaml and update paths
  if ! cp "$source_ledger_config" "$dest_ledger_config"; then
    log_error "Failed to copy ledgers.yaml from $source_ledger_config to $dest_ledger_config"
    return 1
  fi

  log_info "Copied ledgers.yaml from source profile"

  # Update all file paths in ledgers.yaml to point to destination profile
  # Replace source profile base path with destination profile base path
  if ! sed -i.bak "s|$source_base|$dest_base|g" "$dest_ledger_config"; then
    log_error "Failed to update paths in ledgers.yaml"
    return 1
  fi

  # Remove backup file created by sed
  rm -f "$dest_ledger_config.bak"

  log_success "Ledger configuration copied and updated"
  log_info "Updated paths in: $dest_ledger_config"
  
  return 0
}
