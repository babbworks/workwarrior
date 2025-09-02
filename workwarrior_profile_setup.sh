#!/bin/bash

# Workwarrior Profile Setup Script
# This script sets up a new profile with JRNL integration
# Usage: setup_workwarrior_profile.sh <profile_name>

# Configuration
WORKWARRIOR_DIR="$HOME/.workwarrior"
PROFILES_DIR="$WORKWARRIOR_DIR/profiles"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to create directory structure
create_directories() {
    local profile_name="$1"
    local profile_dir="$PROFILES_DIR/$profile_name"
    
    log_info "Creating directory structure for profile: $profile_name"
    
    mkdir -p "$profile_dir/journals"
    mkdir -p "$profile_dir/taskwarrior"
    mkdir -p "$profile_dir/config"
    
    log_success "Directories created at: $profile_dir"
}

# Function to create JRNL config
create_jrnl_config() {
    local profile_name="$1"
    local profile_dir="$PROFILES_DIR/$profile_name"
    local jrnl_config="$profile_dir/jrnl.yaml"
    local journal_file="$profile_dir/journals/main.txt"
    
    log_info "Creating JRNL configuration..."
    
    # Interactive configuration
    echo ""
    echo "=== JRNL Configuration for Profile: $profile_name ==="
    
    # Editor selection
    echo "Available editors: nano, vim, code, emacs"
    read -p "Choose editor [nano]: " editor
    editor=${editor:-"nano"}
    
    # Encryption
    read -p "Enable journal encryption? [y/N]: " encrypt_choice
    if [[ "$encrypt_choice" =~ ^[Yy]$ ]]; then
        encrypt="true"
        log_warning "You'll need to set a password when first using the journal"
    else
        encrypt="false"
    fi
    
    # Time format
    echo "Choose time format:"
    echo "1) %Y-%m-%d %H:%M (2024-01-15 14:30)"
    echo "2) %b %d, %Y at %I:%M %p (Jan 15, 2024 at 02:30 PM)"
    echo "3) %m/%d/%Y %H:%M (01/15/2024 14:30)"
    read -p "Choose format [1]: " time_choice
    
    case "$time_choice" in
        2) timeformat="%b %d, %Y at %I:%M %p" ;;
        3) timeformat="%m/%d/%Y %H:%M" ;;
        *) timeformat="%Y-%m-%d %H:%M" ;;
    esac
    
    # Create the config file
    cat > "$jrnl_config" << EOF
# JRNL Configuration for Workwarrior Profile: $profile_name
# Generated on $(date)

journals:
  default: $journal_file
  
# Editor configuration
editor: $editor

# Security
encrypt: $encrypt

# Formatting
tagsymbols: '@'
default_hour: 9
default_minute: 0
timeformat: "$timeformat"
highlight: true
linewrap: 79

# Display options
colors:
  body: none
  date: blue
  tags: yellow
  title: cyan
EOF
    
    log_success "JRNL config created: $jrnl_config"
    
    # Create initial journal entry
    if [[ "$encrypt" == "false" ]]; then
        echo "$(date +"$timeformat") Welcome to your $profile_name journal! This is your first entry." > "$journal_file"
        log_info "Created initial journal entry"
    fi
}

# Function to setup shell integration
setup_shell_integration() {
    local profile_name="$1"
    local profile_dir="$PROFILES_DIR/$profile_name"
    local shell_config="$profile_dir/shell_setup.sh"
    
    log_info "Creating shell integration setup..."
    
    cat > "$shell_config" << EOF
#!/bin/bash
# Shell setup for Workwarrior profile: $profile_name
# Source this file or add to your shell rc file

# Set current profile environment variable
export WORKWARRIOR_PROFILE="$profile_name"

# Create profile switcher function
workwarrior_switch_profile() {
    local new_profile="\$1"
    local profile_file="$WORKWARRIOR_DIR/current_profile"
    
    if [[ -z "\$new_profile" ]]; then
        echo "Current profile: \$(cat "\$profile_file" 2>/dev/null || echo 'none set')"
        echo "Available profiles:"
        ls "$PROFILES_DIR" 2>/dev/null || echo "No profiles found"
        return
    fi
    
    if [[ -d "$PROFILES_DIR/\$new_profile" ]]; then
        echo "\$new_profile" > "\$profile_file"
        export WORKWARRIOR_PROFILE="\$new_profile"
        echo "Switched to profile: \$new_profile"
    else
        echo "Profile '\$new_profile' not found"
    fi
}

# Alias for easy profile switching
alias wwp='workwarrior_switch_profile'

# Set this as current profile
echo "$profile_name" > "$WORKWARRIOR_DIR/current_profile"

echo "Workwarrior profile '$profile_name' is now active"
echo "Use 'j' for journal commands, 'wwp' to switch profiles"
EOF
    
    chmod +x "$shell_config"
    log_success "Shell integration created: $shell_config"
    
    echo ""
    log_info "To activate this profile, run:"
    echo "    source $shell_config"
    echo ""
    log_info "Or add this line to your ~/.bashrc or ~/.zshrc:"
    echo "    source $shell_config"
}

# Function to create profile info file
create_profile_info() {
    local profile_name="$1"
    local profile_dir="$PROFILES_DIR/$profile_name"
    local info_file="$profile_dir/profile_info.txt"
    
    cat > "$info_file" << EOF
Workwarrior Profile: $profile_name
Created: $(date)
JRNL Config: $profile_dir/jrnl.yaml
Journal File: $profile_dir/journals/main.txt
Shell Setup: $profile_dir/shell_setup.sh

Quick Start:
1. Source the shell setup: source $profile_dir/shell_setup.sh
2. Start journaling: j "Your first entry"
3. List entries: j --list
4. Edit journal: j --edit

Profile Management:
- Switch profiles: wwp <profile_name>
- List profiles: wwp
EOF
    
    log_success "Profile info saved: $info_file"
}

# Main setup function
main() {
    local profile_name="$1"
    
    # Validate input
    if [[ -z "$profile_name" ]]; then
        echo "Usage: $0 <profile_name>"
        echo ""
        echo "Example: $0 work"
        echo "         $0 personal"
        exit 1
    fi
    
    # Check if profile already exists
    if [[ -d "$PROFILES_DIR/$profile_name" ]]; then
        log_error "Profile '$profile_name' already exists!"
        read -p "Do you want to recreate it? [y/N]: " recreate
        if [[ ! "$recreate" =~ ^[Yy]$ ]]; then
            exit 1
        fi
        rm -rf "$PROFILES_DIR/$profile_name"
    fi
    
    log_info "Setting up Workwarrior profile: $profile_name"
    echo ""
    
    # Create all components
    create_directories "$profile_name"
    create_jrnl_config "$profile_name"
    setup_shell_integration "$profile_name"
    create_profile_info "$profile_name"
    
    echo ""
    log_success "Profile '$profile_name' setup complete!"
    echo ""
    echo "Next steps:"
    echo "1. source $PROFILES_DIR/$profile_name/shell_setup.sh"
    echo "2. Try: j 'My first journal entry'"
    echo ""
}

# Run main function
main "$@"