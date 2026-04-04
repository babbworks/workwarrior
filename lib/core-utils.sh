#!/usr/bin/env bash
# Core utilities library for Workwarrior Profiles System
# This file provides logging utilities, validation functions, and standard path constants
# Source this file in other scripts: source "$(dirname "$0")/../lib/core-utils.sh"

# ============================================================================
# CONSTANTS - Standard paths used throughout the system
# ============================================================================

# Base directories
readonly WW_BASE="${WW_BASE:-$HOME/ww}"
PROFILES_DIR="${PROFILES_DIR:-$WW_BASE/profiles}"
readonly SERVICES_DIR="${SERVICES_DIR:-$WW_BASE/services}"
readonly RESOURCES_DIR="${RESOURCES_DIR:-$WW_BASE/resources}"
readonly FUNCTIONS_DIR="${FUNCTIONS_DIR:-$WW_BASE/functions}"

# Configuration paths
readonly SHELL_RC="${SHELL_RC:-$HOME/.bashrc}"
readonly DEFAULT_TASKRC="$FUNCTIONS_DIR/tasks/default-taskrc/.taskrc"
readonly CONFIG_TEMPLATES_DIR="$RESOURCES_DIR/config-files"

# Service categories
readonly PROFILE_SERVICE_DIR="$SERVICES_DIR/profile"
readonly QUESTIONS_SERVICE_DIR="$SERVICES_DIR/questions"
readonly SCRIPTS_SERVICE_DIR="$SERVICES_DIR/scripts"
readonly EXPORT_SERVICE_DIR="$SERVICES_DIR/export"
readonly DIAGNOSTIC_SERVICE_DIR="$SERVICES_DIR/diagnostic"
readonly FIND_SERVICE_DIR="$SERVICES_DIR/find"
readonly VERIFY_SERVICE_DIR="$SERVICES_DIR/verify"
readonly CUSTOM_SERVICE_DIR="$SERVICES_DIR/custom"

# ============================================================================
# LOGGING UTILITIES
# ============================================================================

# Log an informational message
# Usage: log_info "message"
log_info() {
  echo "ℹ $*"
}

# Log a success message
# Usage: log_success "message"
log_success() {
  echo "✓ $*"
}

# Log a warning message
# Usage: log_warning "message"
log_warning() {
  echo "⚠ $*"
}

# Log an error message to stderr
# Usage: log_error "message"
log_error() {
  echo "✗ $*" >&2
}

# Log a step/progress message
# Usage: log_step "message"
log_step() {
  echo "🔧 $*"
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

# Validate profile name according to requirements
# Profile names must:
#   - Not be empty
#   - Contain only letters, numbers, hyphens, and underscores
#   - Not exceed 50 characters
# 
# Usage: validate_profile_name "profile-name"
# Returns: 0 if valid, 1 if invalid
# Validates: Requirements 2.2, 2.3
validate_profile_name() {
  local name="$1"
  
  # Check if name is empty
  if [[ -z "$name" ]]; then
    log_error "Profile name cannot be empty"
    return 1
  fi
  
  # Check for invalid characters (must be alphanumeric, hyphen, or underscore)
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Profile name must contain only letters, numbers, hyphens, and underscores"
    log_error "Invalid name: '$name'"
    return 1
  fi
  
  # Check length (max 50 characters)
  if (( ${#name} > 50 )); then
    log_error "Profile name cannot exceed 50 characters (got ${#name})"
    return 1
  fi
  
  return 0
}

# Check if a profile exists
# Usage: profile_exists "profile-name"
# Returns: 0 if exists, 1 if not
profile_exists() {
  local name="$1"
  [[ -d "$PROFILES_DIR/$name" ]]
}

# Ensure a profile exists, exit with error if not
# Usage: ensure_profile_exists "profile-name"
# Returns: 0 if exists, 1 if not (with error message)
ensure_profile_exists() {
  local name="$1"
  local profile_dir="$PROFILES_DIR/$name"
  
  if [[ ! -d "$profile_dir" ]]; then
    log_error "Profile '$name' does not exist"
    log_info "Available profiles:"
    list_profiles 2>/dev/null | sed 's/^/  /' || echo "  (none)"
    return 1
  fi
  
  return 0
}

# Check if active profile is set
# Usage: require_active_profile
# Returns: 0 if active profile exists, 1 if not
# Validates: Requirements 4.10, 8.18, 9.9
require_active_profile() {
  if [[ -z "${WORKWARRIOR_BASE:-}" ]]; then
    log_error "No profile is currently active"
    log_info "Activate a profile with: p-<profile-name>"
    log_info "Available profiles:"
    list_profiles 2>/dev/null | sed 's/^/  /' || echo "  (none)"
    return 1
  fi
  
  return 0
}

# ============================================================================
# DIRECTORY UTILITIES
# ============================================================================

# Ensure a directory exists, create if needed
# Usage: ensure_directory "/path/to/directory"
# Returns: 0 on success, 1 on failure
ensure_directory() {
  local dir="$1"
  
  if [[ ! -d "$dir" ]]; then
    if ! mkdir -p "$dir" 2>/dev/null; then
      log_error "Failed to create directory: $dir"
      return 1
    fi
  fi
  
  return 0
}

# List all existing profiles (sorted)
# Usage: list_profiles
# Returns: Sorted list of profile names, one per line
# Validates: Requirements 3.1, 3.9
list_profiles() {
  if [[ ! -d "$PROFILES_DIR" ]]; then
    log_warning "Profiles directory not found at $PROFILES_DIR"
    return 0
  fi
  
  local profiles=()
  while IFS= read -r -d '' dir; do
    profiles+=( "$(basename "$dir")" )
  done < <(find "$PROFILES_DIR" -mindepth 1 -maxdepth 1 -type d -print0)
  
  if (( ${#profiles[@]} == 0 )); then
    log_info "No profiles found"
    return 0
  fi
  
  # Sort and print profiles
  printf '%s\n' "${profiles[@]}" | sort
}

# ============================================================================
# FILE UTILITIES
# ============================================================================

# Check if a file exists and is readable
# Usage: file_readable "/path/to/file"
# Returns: 0 if readable, 1 if not
file_readable() {
  local file="$1"
  
  if [[ ! -f "$file" ]]; then
    log_error "File not found: $file"
    return 1
  fi
  
  if [[ ! -r "$file" ]]; then
    log_error "File not readable: $file"
    return 1
  fi
  
  return 0
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

# Exit with error message and code
# Usage: die "error message" [exit_code]
die() {
  local message="$1"
  local code="${2:-1}"
  log_error "$message"
  exit "$code"
}

# ============================================================================
# INITIALIZATION
# ============================================================================

# Ensure base directories exist
# This is called automatically when the library is sourced
_init_base_directories() {
  ensure_directory "$WW_BASE" || return 1
  ensure_directory "$PROFILES_DIR" || return 1
  ensure_directory "$SERVICES_DIR" || return 1
  ensure_directory "$RESOURCES_DIR" || return 1
  ensure_directory "$FUNCTIONS_DIR" || return 1
  return 0
}

# Initialize base directories when library is sourced
# Comment this out if you want manual initialization
# _init_base_directories

# ============================================================================
# SERVICE DISCOVERY FUNCTIONS
# ============================================================================

# Discover services in a specific category
# Scans both global and profile-specific service directories
# Usage: discover_services "category"
# Returns: List of service names (without paths), one per line
# Validates: Requirements 14.1, 14.2, 14.3, 14.4, 14.5
discover_services() {
  local category="$1"
  
  if [[ -z "$category" ]]; then
    log_error "Service category is required"
    return 1
  fi
  
  local services=()
  local seen_services=()
  
  # Check profile-specific services first (if profile is active)
  if [[ -n "${WORKWARRIOR_BASE:-}" ]]; then
    local profile_service_dir="$WORKWARRIOR_BASE/services/$category"
    if [[ -d "$profile_service_dir" ]]; then
      while IFS= read -r -d '' file; do
        local service_name
        service_name="$(basename "$file")"
        # Only include executable files or .sh files
        if [[ -x "$file" ]] || [[ "$file" == *.sh ]]; then
          services+=( "$service_name" )
          seen_services+=( "$service_name" )
        fi
      done < <(find "$profile_service_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    fi
  fi
  
  # Check global services directory
  local global_service_dir="$SERVICES_DIR/$category"
  if [[ -d "$global_service_dir" ]]; then
    while IFS= read -r -d '' file; do
      local service_name
      service_name="$(basename "$file")"
      # Only include executable files or .sh files
      if [[ -x "$file" ]] || [[ "$file" == *.sh ]]; then
        # Skip if already found in profile-specific services
        local already_seen=0
        for seen in "${seen_services[@]}"; do
          if [[ "$seen" == "$service_name" ]]; then
            already_seen=1
            break
          fi
        done
        if (( already_seen == 0 )); then
          services+=( "$service_name" )
        fi
      fi
    done < <(find "$global_service_dir" -maxdepth 1 -type f -print0 2>/dev/null)
  fi
  
  # Sort and print services
  if (( ${#services[@]} > 0 )); then
    printf '%s\n' "${services[@]}" | sort
  fi
  
  return 0
}

# Get the path to a service, with profile override support
# Profile-specific services take precedence over global services
# Usage: get_service_path "category" "service-name"
# Returns: Absolute path to service file, or empty string if not found
# Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5
get_service_path() {
  local category="$1"
  local service_name="$2"
  
  if [[ -z "$category" ]] || [[ -z "$service_name" ]]; then
    log_error "Both category and service name are required"
    return 1
  fi
  
  # Check profile-specific service first (if profile is active)
  if [[ -n "${WORKWARRIOR_BASE:-}" ]]; then
    local profile_service_path="$WORKWARRIOR_BASE/services/$category/$service_name"
    if [[ -f "$profile_service_path" ]]; then
      echo "$profile_service_path"
      return 0
    fi
  fi
  
  # Check global service directory
  local global_service_path="$SERVICES_DIR/$category/$service_name"
  if [[ -f "$global_service_path" ]]; then
    echo "$global_service_path"
    return 0
  fi
  
  # Service not found
  return 1
}

# Check if a service exists in a category
# Checks both global and profile-specific locations
# Usage: service_exists "category" "service-name"
# Returns: 0 if exists, 1 if not
# Validates: Requirements 11.1, 11.2, 11.3, 11.4
service_exists() {
  local category="$1"
  local service_name="$2"
  
  if [[ -z "$category" ]] || [[ -z "$service_name" ]]; then
    return 1
  fi
  
  # Check profile-specific service first (if profile is active)
  if [[ -n "${WORKWARRIOR_BASE:-}" ]]; then
    local profile_service_path="$WORKWARRIOR_BASE/services/$category/$service_name"
    if [[ -f "$profile_service_path" ]]; then
      return 0
    fi
  fi
  
  # Check global service directory
  local global_service_path="$SERVICES_DIR/$category/$service_name"
  if [[ -f "$global_service_path" ]]; then
    return 0
  fi
  
  return 1
}

# ============================================================================
# LIBRARY LOADED INDICATOR
# ============================================================================

# Set a variable to indicate this library has been loaded
readonly CORE_UTILS_LOADED=1
