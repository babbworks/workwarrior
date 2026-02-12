#!/usr/bin/env bash
# Service: configure-issues
# Category: custom
# Description: Interactive guide for configuring bugwarrior issue synchronization

set -e

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/core-utils.sh"

# ============================================================================
# CONFIGURATION
# ============================================================================

BUGWARRIORRC=""
PROFILE_NAME=""
PROFILE_BASE=""
BUGWARRIOR_DIR=""
CONFIG_FORMAT="ini"  # ini or toml

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

show_banner() {
  echo ""
  echo "============================================================"
  echo "         Bugwarrior Issues Configuration Guide"
  echo "============================================================"
  echo ""
  echo "⚠️  IMPORTANT: One-Way Sync Only"
  echo ""
  echo "Bugwarrior pulls issues FROM external services TO TaskWarrior."
  echo "Changes in TaskWarrior do NOT sync back to issue trackers."
  echo "External services (GitHub, Jira, etc.) are authoritative."
  echo ""
  echo "============================================================"
  echo ""
}

check_active_profile() {
  if [[ -z "$WORKWARRIOR_BASE" ]]; then
    log_error "No active profile. Activate a profile first with: p-<profile-name>"
    exit 1
  fi
  
  PROFILE_BASE="$WORKWARRIOR_BASE"
  PROFILE_NAME="$WARRIOR_PROFILE"
  BUGWARRIOR_DIR="$PROFILE_BASE/.config/bugwarrior"
  
  # Check for existing config format
  if [[ -f "$BUGWARRIOR_DIR/bugwarrior.toml" ]]; then
    BUGWARRIORRC="$BUGWARRIOR_DIR/bugwarrior.toml"
    CONFIG_FORMAT="toml"
  else
    BUGWARRIORRC="$BUGWARRIOR_DIR/bugwarriorrc"
    CONFIG_FORMAT="ini"
  fi
  
  # Create bugwarrior directory if it doesn't exist
  if [[ ! -d "$BUGWARRIOR_DIR" ]]; then
    log_info "Creating bugwarrior configuration directory"
    mkdir -p "$BUGWARRIOR_DIR"
  fi
  
  # Create empty config if it doesn't exist
  if [[ ! -f "$BUGWARRIORRC" ]]; then
    log_info "Creating bugwarriorrc configuration file (INI format)"
    cat > "$BUGWARRIORRC" << 'EOF'
# Bugwarrior Configuration
# Supported services: GitHub, GitLab, Jira, Trello, Todoist, and 20+ more
# Documentation: https://bugwarrior.readthedocs.io

[general]
targets = my_tasks

EOF
    chmod 600 "$BUGWARRIORRC"
  fi
}

check_bugwarrior_installed() {
  if ! command -v bugwarrior &> /dev/null; then
    log_error "Bugwarrior is not installed"
    echo ""
    echo "Install bugwarrior with one of these methods:"
    echo "  pip install bugwarrior"
    echo "  pipx install bugwarrior"
    echo ""
    echo "For service-specific extras:"
    echo "  pip install 'bugwarrior[jira]'     # Jira support"
    echo "  pip install 'bugwarrior[gmail]'    # Gmail support"
    echo ""
    exit 1
  fi
}

show_credential_security_info() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Credential Security Options"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "⚠️  SECURITY WARNING"
  echo ""
  echo "By default, credentials are stored in plain text in:"
  echo "  $BUGWARRIORRC"
  echo ""
  echo "For better security, bugwarrior supports secure credential storage:"
  echo ""
  echo "1. System Keyring (Recommended)"
  echo "   Replace: github.token = your_token"
  echo "   With:    github.token = @oracle:use_keyring"
  echo ""
  echo "2. Password Prompt"
  echo "   Replace: github.token = your_token"
  echo "   With:    github.token = @oracle:ask_password"
  echo ""
  echo "3. External Password Manager"
  echo "   Replace: github.token = your_token"
  echo "   With:    github.token = @oracle:eval:pass github/token"
  echo ""
  echo "4. Environment Variable"
  echo "   Replace: github.token = your_token"
  echo "   With:    github.token = @oracle:eval:echo \$GITHUB_TOKEN"
  echo ""
  echo "After configuring services, edit $BUGWARRIORRC"
  echo "and replace plain text credentials with @oracle directives."
  echo ""
  echo "Documentation: https://bugwarrior.readthedocs.io/en/latest/common_configuration.html#passwords"
  echo ""
  read -p "Press Enter to continue..."
}

# ============================================================================
# MAIN MENU
# ============================================================================

show_main_menu() {
  while true; do
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Issues Configuration Menu - Profile: $PROFILE_NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  1. Add/configure external service"
    echo "  2. List configured services"
    echo "  3. Remove service"
    echo "  4. Generate/update UDAs"
    echo "  5. Test configuration (dry-run)"
    echo "  6. View current configuration"
    echo "  7. Credential security information"
    echo "  8. Exit"
    echo ""
    read -p "Choose option [1-8]: " choice
    
    case "$choice" in
      1) configure_service ;;
      2) list_services ;;
      3) remove_service ;;
      4) generate_udas ;;
      5) test_configuration ;;
      6) view_configuration ;;
      7) show_credential_security_info ;;
      8)
        echo ""
        log_success "Configuration complete!"
        echo ""
        echo "Configuration saved to: $BUGWARRIORRC"
        echo ""
        echo "Next steps:"
        echo "  1. Run 'i pull' to sync issues"
        echo "  2. Run 'task list' to view synced tasks"
        echo ""
        exit 0
        ;;
      *)
        log_error "Invalid choice"
        ;;
    esac
  done
}

# ============================================================================
# SERVICE CONFIGURATION FUNCTIONS
# ============================================================================

configure_service() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Add/Configure External Service"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Select service type:"
  echo ""
  echo "  1. GitHub"
  echo "  2. GitLab"
  echo "  3. Jira"
  echo "  4. Trello"
  echo "  5. Generic/Other"
  echo "  6. Back to main menu"
  echo ""
  read -p "Choose service [1-6]: " service_choice
  
  case "$service_choice" in
    1) configure_github ;;
    2) configure_gitlab ;;
    3) configure_jira ;;
    4) configure_trello ;;
    5) configure_generic ;;
    6|"") return 0 ;;
    *)
      log_error "Invalid choice"
      return 1
      ;;
  esac
}

configure_github() {
  echo ""
  log_step "Configuring GitHub Service"
  echo ""
  
  read -p "Enter service name (e.g., my_github): " service_name
  if [[ -z "$service_name" ]]; then
    log_error "Service name cannot be empty"
    return 1
  fi
  
  read -p "Enter GitHub username: " github_username
  if [[ -z "$github_username" ]]; then
    log_error "Username cannot be empty"
    return 1
  fi
  
  echo ""
  echo "GitHub Personal Access Token:"
  echo "  Create at: https://github.com/settings/tokens"
  echo "  Required scope: repo (read-only)"
  echo ""
  read -p "Enter GitHub token: " github_token
  if [[ -z "$github_token" ]]; then
    log_error "Token cannot be empty"
    return 1
  fi
  
  echo ""
  read -p "Enter repositories to sync (comma-separated, e.g., owner/repo1, owner/repo2): " repos
  
  echo ""
  read -p "Only sync issues assigned to you? [y/n]: " only_assigned
  
  echo ""
  read -p "Import labels as tags? [y/n]: " import_labels
  
  # Add service to config
  if ! grep -q "^\[general\]" "$BUGWARRIORRC"; then
    echo "[general]" >> "$BUGWARRIORRC"
    echo "targets = $service_name" >> "$BUGWARRIORRC"
  else
    # Update targets
    if grep -q "^targets = " "$BUGWARRIORRC"; then
      sed -i.bak "s/^targets = .*/&, $service_name/" "$BUGWARRIORRC"
    else
      sed -i.bak "/^\[general\]/a targets = $service_name" "$BUGWARRIORRC"
    fi
  fi
  
  # Add service configuration
  cat >> "$BUGWARRIORRC" << EOF

[$service_name]
service = github
github.login = $github_username
github.token = $github_token
github.username = $github_username
EOF
  
  if [[ -n "$repos" ]]; then
    echo "github.include_repos = $repos" >> "$BUGWARRIORRC"
  fi
  
  if [[ "$only_assigned" == "y" || "$only_assigned" == "Y" ]]; then
    echo "github.only_if_assigned = $github_username" >> "$BUGWARRIORRC"
  fi
  
  if [[ "$import_labels" == "y" || "$import_labels" == "Y" ]]; then
    echo "github.import_labels_as_tags = True" >> "$BUGWARRIORRC"
  fi
  
  log_success "GitHub service '$service_name' configured"
  echo ""
  log_warning "⚠️  Security: Your token is stored in plain text"
  echo "For better security, consider using keyring:"
  echo "  github.token = @oracle:use_keyring"
  echo ""
  read -p "Press Enter to continue..."
}

configure_gitlab() {
  echo ""
  log_step "Configuring GitLab Service"
  echo ""
  
  read -p "Enter service name (e.g., my_gitlab): " service_name
  if [[ -z "$service_name" ]]; then
    log_error "Service name cannot be empty"
    return 1
  fi
  
  read -p "Enter GitLab host (default: gitlab.com): " gitlab_host
  gitlab_host="${gitlab_host:-gitlab.com}"
  
  read -p "Enter GitLab username: " gitlab_username
  if [[ -z "$gitlab_username" ]]; then
    log_error "Username cannot be empty"
    return 1
  fi
  
  echo ""
  echo "GitLab Personal Access Token:"
  echo "  Create at: https://$gitlab_host/-/profile/personal_access_tokens"
  echo "  Required scope: read_api"
  echo ""
  read -p "Enter GitLab token: " gitlab_token
  if [[ -z "$gitlab_token" ]]; then
    log_error "Token cannot be empty"
    return 1
  fi
  
  echo ""
  read -p "Enter project IDs to sync (comma-separated, e.g., 123, 456): " projects
  
  # Add service to config
  if ! grep -q "^\[general\]" "$BUGWARRIORRC"; then
    echo "[general]" >> "$BUGWARRIORRC"
    echo "targets = $service_name" >> "$BUGWARRIORRC"
  else
    if grep -q "^targets = " "$BUGWARRIORRC"; then
      sed -i.bak "s/^targets = .*/&, $service_name/" "$BUGWARRIORRC"
    else
      sed -i.bak "/^\[general\]/a targets = $service_name" "$BUGWARRIORRC"
    fi
  fi
  
  # Add service configuration
  cat >> "$BUGWARRIORRC" << EOF

[$service_name]
service = gitlab
gitlab.host = $gitlab_host
gitlab.login = $gitlab_username
gitlab.token = $gitlab_token
EOF
  
  if [[ -n "$projects" ]]; then
    echo "gitlab.include_repos = $projects" >> "$BUGWARRIORRC"
  fi
  
  log_success "GitLab service '$service_name' configured"
  echo ""
  log_warning "⚠️  Security: Your token is stored in plain text"
  echo "For better security, consider using keyring:"
  echo "  gitlab.token = @oracle:use_keyring"
  echo ""
  read -p "Press Enter to continue..."
}

configure_jira() {
  echo ""
  log_step "Configuring Jira Service"
  echo ""
  
  read -p "Enter service name (e.g., my_jira): " service_name
  if [[ -z "$service_name" ]]; then
    log_error "Service name cannot be empty"
    return 1
  fi
  
  read -p "Enter Jira base URL (e.g., https://mycompany.atlassian.net): " jira_url
  if [[ -z "$jira_url" ]]; then
    log_error "Jira URL cannot be empty"
    return 1
  fi
  
  read -p "Enter Jira username/email: " jira_username
  if [[ -z "$jira_username" ]]; then
    log_error "Username cannot be empty"
    return 1
  fi
  
  echo ""
  echo "Jira API Token:"
  echo "  Create at: https://id.atlassian.com/manage-profile/security/api-tokens"
  echo ""
  read -p "Enter Jira API token: " jira_token
  if [[ -z "$jira_token" ]]; then
    log_error "Token cannot be empty"
    return 1
  fi
  
  echo ""
  read -p "Enter JQL query (e.g., assignee=currentUser() AND status!=Done): " jql_query
  
  # Add service to config
  if ! grep -q "^\[general\]" "$BUGWARRIORRC"; then
    echo "[general]" >> "$BUGWARRIORRC"
    echo "targets = $service_name" >> "$BUGWARRIORRC"
  else
    if grep -q "^targets = " "$BUGWARRIORRC"; then
      sed -i.bak "s/^targets = .*/&, $service_name/" "$BUGWARRIORRC"
    else
      sed -i.bak "/^\[general\]/a targets = $service_name" "$BUGWARRIORRC"
    fi
  fi
  
  # Add service configuration
  cat >> "$BUGWARRIORRC" << EOF

[$service_name]
service = jira
jira.base_uri = $jira_url
jira.username = $jira_username
jira.password = $jira_token
EOF
  
  if [[ -n "$jql_query" ]]; then
    echo "jira.query = $jql_query" >> "$BUGWARRIORRC"
  fi
  
  log_success "Jira service '$service_name' configured"
  echo ""
  log_warning "⚠️  Security: Your token is stored in plain text"
  echo "For better security, consider using keyring:"
  echo "  jira.password = @oracle:use_keyring"
  echo ""
  read -p "Press Enter to continue..."
}

configure_trello() {
  echo ""
  log_step "Configuring Trello Service"
  echo ""
  
  read -p "Enter service name (e.g., my_trello): " service_name
  if [[ -z "$service_name" ]]; then
    log_error "Service name cannot be empty"
    return 1
  fi
  
  echo ""
  echo "Trello API Key and Token:"
  echo "  Get API key at: https://trello.com/app-key"
  echo "  Generate token from the same page"
  echo ""
  read -p "Enter Trello API key: " trello_api_key
  if [[ -z "$trello_api_key" ]]; then
    log_error "API key cannot be empty"
    return 1
  fi
  
  read -p "Enter Trello token: " trello_token
  if [[ -z "$trello_token" ]]; then
    log_error "Token cannot be empty"
    return 1
  fi
  
  echo ""
  read -p "Enter board IDs to sync (comma-separated): " boards
  
  # Add service to config
  if ! grep -q "^\[general\]" "$BUGWARRIORRC"; then
    echo "[general]" >> "$BUGWARRIORRC"
    echo "targets = $service_name" >> "$BUGWARRIORRC"
  else
    if grep -q "^targets = " "$BUGWARRIORRC"; then
      sed -i.bak "s/^targets = .*/&, $service_name/" "$BUGWARRIORRC"
    else
      sed -i.bak "/^\[general\]/a targets = $service_name" "$BUGWARRIORRC"
    fi
  fi
  
  # Add service configuration
  cat >> "$BUGWARRIORRC" << EOF

[$service_name]
service = trello
trello.api_key = $trello_api_key
trello.token = $trello_token
EOF
  
  if [[ -n "$boards" ]]; then
    echo "trello.include_boards = $boards" >> "$BUGWARRIORRC"
  fi
  
  log_success "Trello service '$service_name' configured"
  echo ""
  log_warning "⚠️  Security: Your credentials are stored in plain text"
  echo "For better security, consider using keyring"
  echo ""
  read -p "Press Enter to continue..."
}

configure_generic() {
  echo ""
  log_step "Configuring Generic Service"
  echo ""
  echo "For other services, please refer to bugwarrior documentation:"
  echo "https://bugwarrior.readthedocs.io/en/latest/services/"
  echo ""
  echo "Supported services include:"
  echo "  • Bitbucket, Pagure, Gerrit, Git-Bug"
  echo "  • Bugzilla, Redmine, YouTrack, Phabricator, Trac"
  echo "  • Taiga, Pivotal Tracker, Teamwork Projects, ClickUp, Linear"
  echo "  • Todoist, Logseq, Nextcloud Deck, Kanboard"
  echo "  • Gmail, Azure DevOps, Debian BTS"
  echo ""
  echo "You can manually edit the configuration file:"
  echo "  $BUGWARRIORRC"
  echo ""
  read -p "Press Enter to continue..."
}

list_services() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Configured Services"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  if [[ ! -f "$BUGWARRIORRC" ]]; then
    log_warning "No configuration file found"
    return 0
  fi
  
  # Extract service sections
  local in_service=0
  local service_name=""
  local service_type=""
  
  while IFS= read -r line; do
    # Check for section header
    if [[ "$line" =~ ^\[([^\]]+)\]$ ]]; then
      local section="${BASH_REMATCH[1]}"
      if [[ "$section" != "general" ]]; then
        if [[ -n "$service_name" ]]; then
          echo "  • $service_name ($service_type)"
        fi
        service_name="$section"
        service_type=""
      fi
    elif [[ "$line" =~ ^service[[:space:]]*=[[:space:]]*(.+)$ ]]; then
      service_type="${BASH_REMATCH[1]}"
    fi
  done < "$BUGWARRIORRC"
  
  # Print last service
  if [[ -n "$service_name" ]]; then
    echo "  • $service_name ($service_type)"
  fi
  
  echo ""
  read -p "Press Enter to continue..."
}

remove_service() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Remove Service"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  list_services
  
  echo ""
  read -p "Enter service name to remove: " service_name
  
  if [[ -z "$service_name" ]]; then
    log_error "Service name cannot be empty"
    return 1
  fi
  
  # Check if service exists
  if ! grep -q "^\[$service_name\]" "$BUGWARRIORRC"; then
    log_error "Service '$service_name' not found"
    return 1
  fi
  
  read -p "Are you sure you want to remove '$service_name'? [y/n]: " confirm
  
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "Cancelled"
    return 0
  fi
  
  # Create backup
  cp "$BUGWARRIORRC" "$BUGWARRIORRC.bak"
  
  # Remove service section
  sed -i.tmp "/^\[$service_name\]/,/^\[/{ /^\[$service_name\]/d; /^\[/!d; }" "$BUGWARRIORRC"
  rm -f "$BUGWARRIORRC.tmp"
  
  # Remove from targets
  sed -i.tmp "s/, $service_name//g; s/$service_name, //g; s/targets = $service_name$/targets = /" "$BUGWARRIORRC"
  rm -f "$BUGWARRIORRC.tmp"
  
  log_success "Service '$service_name' removed"
  log_info "Backup saved to: $BUGWARRIORRC.bak"
  echo ""
  log_warning "Note: UDAs for this service remain in .taskrc"
  echo "You may want to regenerate UDAs to clean them up"
  echo ""
  read -p "Press Enter to continue..."
}

generate_udas() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Generate/Update UDAs"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  log_info "Generating UDA definitions from bugwarrior..."
  
  # Generate UDAs
  local uda_output
  if ! uda_output=$(BUGWARRIORRC="$BUGWARRIORRC" bugwarrior uda 2>&1); then
    log_error "Failed to generate UDAs"
    echo "$uda_output"
    read -p "Press Enter to continue..."
    return 1
  fi
  
  if [[ -z "$uda_output" ]]; then
    log_warning "No UDAs generated (no services configured?)"
    read -p "Press Enter to continue..."
    return 0
  fi
  
  local taskrc="$PROFILE_BASE/.taskrc"
  
  # Create backup
  cp "$taskrc" "$taskrc.bak"
  
  # Check if UDAs section exists
  if ! grep -q "# Bugwarrior UDAs" "$taskrc"; then
    echo "" >> "$taskrc"
    echo "# Bugwarrior UDAs" >> "$taskrc"
  fi
  
  # Remove old bugwarrior UDAs
  sed -i.tmp '/# Bugwarrior UDAs/,/^$/{ /# Bugwarrior UDAs/!d; }' "$taskrc"
  rm -f "$taskrc.tmp"
  
  # Append new UDAs
  echo "$uda_output" >> "$taskrc"
  
  log_success "UDAs generated and added to .taskrc"
  log_info "Backup saved to: $taskrc.bak"
  echo ""
  echo "UDA count: $(echo "$uda_output" | grep -c "^uda\.")"
  echo ""
  read -p "Press Enter to continue..."
}

test_configuration() {
  log_info "Testing bugwarrior configuration..."
  if command -v bugwarrior &> /dev/null; then
    BUGWARRIORRC="$BUGWARRIORRC" bugwarrior pull --dry-run
  else
    log_error "Bugwarrior not installed"
  fi
}

view_configuration() {
  if [[ -f "$BUGWARRIORRC" ]]; then
    echo ""
    echo "Configuration file: $BUGWARRIORRC"
    echo "Format: $CONFIG_FORMAT"
    echo ""
    cat "$BUGWARRIORRC" | less
  else
    log_error "Configuration file not found: $BUGWARRIORRC"
  fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
  show_banner
  check_active_profile
  check_bugwarrior_installed
  show_main_menu
}

main "$@"
