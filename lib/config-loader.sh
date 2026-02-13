#!/usr/bin/env bash
# Configuration Loader for GitHub Sync
# Loads and validates configuration from profile directory

# Load configuration with defaults
# Reads config from $WORKWARRIOR_BASE/.config/github-sync/config.sh
# Falls back to defaults if config file doesn't exist
# Validates configuration values
#
# Usage: load_github_sync_config
# Returns: 0 on success, 1 on failure
# Sets: All GITHUB_* configuration variables
load_github_sync_config() {
  # Check if profile is active
  if [[ -z "${WORKWARRIOR_BASE}" ]]; then
    echo "Error: No profile active (WORKWARRIOR_BASE not set)" >&2
    return 1
  fi

  local config_file="${WORKWARRIOR_BASE}/.config/github-sync/config.sh"
  local template_file="${WW_BASE:-$HOME/ww}/resources/config-files/github-sync-config.sh"

  # Set defaults first
  GITHUB_DEFAULT_REPO="${GITHUB_DEFAULT_REPO:-}"
  GITHUB_SYNC_STRATEGY="${GITHUB_SYNC_STRATEGY:-last_write_wins}"
  GITHUB_AUTO_SYNC="${GITHUB_AUTO_SYNC:-false}"
  GITHUB_SYNC_FIELDS="${GITHUB_SYNC_FIELDS:-description,status,priority,tags,annotations}"
  GITHUB_EXCLUDE_TAGS="${GITHUB_EXCLUDE_TAGS:-}"
  GITHUB_SYSTEM_TAGS="ACTIVE,READY,PENDING,COMPLETED,DELETED,WAITING,RECURRING,PARENT,CHILD,BLOCKED,UNBLOCKED,OVERDUE,TODAY,TOMORROW,WEEK,MONTH,YEAR,sync:*"
  GITHUB_EXCLUDE_LABELS="${GITHUB_EXCLUDE_LABELS:-}"
  GITHUB_ANNOTATION_PREFIX="${GITHUB_ANNOTATION_PREFIX:-[TaskWarrior]}"
  GITHUB_COMMENT_PREFIX="${GITHUB_COMMENT_PREFIX:-[GitHub]}"
  GITHUB_LOG_LEVEL="${GITHUB_LOG_LEVEL:-INFO}"
  GITHUB_LOG_MAX_SIZE="${GITHUB_LOG_MAX_SIZE:-10}"
  GITHUB_LOG_ROTATE_COUNT="${GITHUB_LOG_ROTATE_COUNT:-5}"
  GITHUB_BATCH_DELAY="${GITHUB_BATCH_DELAY:-1}"
  GITHUB_MAX_RETRIES="${GITHUB_MAX_RETRIES:-3}"
  GITHUB_RETRY_DELAY="${GITHUB_RETRY_DELAY:-2}"
  GITHUB_DEBUG="${GITHUB_DEBUG:-false}"
  GITHUB_DRY_RUN_DEFAULT="${GITHUB_DRY_RUN_DEFAULT:-false}"
  GITHUB_VALIDATE_ON_LOAD="${GITHUB_VALIDATE_ON_LOAD:-true}"

  # Load config file if it exists
  if [[ -f "${config_file}" ]]; then
    # Source the config file
    # shellcheck source=/dev/null
    source "${config_file}"
  else
    # Config file doesn't exist - create it from template
    if [[ -f "${template_file}" ]]; then
      mkdir -p "$(dirname "${config_file}")"
      cp "${template_file}" "${config_file}"
      echo "Created configuration file: ${config_file}" >&2
      echo "Edit this file to customize GitHub sync settings" >&2
    fi
  fi

  # Validate configuration
  if [[ "${GITHUB_VALIDATE_ON_LOAD}" == "true" ]]; then
    validate_github_sync_config
    return $?
  fi

  return 0
}

# Validate configuration values
# Checks that all configuration values are valid
# Displays warnings for invalid values
#
# Usage: validate_github_sync_config
# Returns: 0 on success, 1 on validation failure
validate_github_sync_config() {
  local errors=0

  # Validate sync strategy
  case "${GITHUB_SYNC_STRATEGY}" in
    last_write_wins|github_wins|task_wins|manual)
      # Valid
      ;;
    *)
      echo "Warning: Invalid GITHUB_SYNC_STRATEGY '${GITHUB_SYNC_STRATEGY}'" >&2
      echo "  Valid values: last_write_wins, github_wins, task_wins, manual" >&2
      echo "  Using default: last_write_wins" >&2
      GITHUB_SYNC_STRATEGY="last_write_wins"
      ;;
  esac

  # Validate log level
  case "${GITHUB_LOG_LEVEL}" in
    DEBUG|INFO|WARN|ERROR)
      # Valid
      ;;
    *)
      echo "Warning: Invalid GITHUB_LOG_LEVEL '${GITHUB_LOG_LEVEL}'" >&2
      echo "  Valid values: DEBUG, INFO, WARN, ERROR" >&2
      echo "  Using default: INFO" >&2
      GITHUB_LOG_LEVEL="INFO"
      ;;
  esac

  # Validate boolean values
  for var in GITHUB_AUTO_SYNC GITHUB_DEBUG GITHUB_DRY_RUN_DEFAULT GITHUB_VALIDATE_ON_LOAD; do
    local value="${!var}"
    if [[ "${value}" != "true" && "${value}" != "false" ]]; then
      echo "Warning: Invalid boolean value for ${var}: '${value}'" >&2
      echo "  Valid values: true, false" >&2
      echo "  Using default: false" >&2
      eval "${var}=false"
    fi
  done

  # Validate numeric values
  for var in GITHUB_LOG_MAX_SIZE GITHUB_LOG_ROTATE_COUNT GITHUB_BATCH_DELAY GITHUB_MAX_RETRIES GITHUB_RETRY_DELAY; do
    local value="${!var}"
    if ! [[ "${value}" =~ ^[0-9]+$ ]]; then
      echo "Warning: Invalid numeric value for ${var}: '${value}'" >&2
      echo "  Must be a positive integer" >&2
      errors=$((errors + 1))
    fi
  done

  # Validate sync fields
  IFS=',' read -ra fields <<< "${GITHUB_SYNC_FIELDS}"
  for field in "${fields[@]}"; do
    case "${field}" in
      description|status|priority|tags|annotations)
        # Valid
        ;;
      *)
        echo "Warning: Invalid sync field '${field}'" >&2
        echo "  Valid fields: description, status, priority, tags, annotations" >&2
        ;;
    esac
  done

  if [[ ${errors} -gt 0 ]]; then
    echo "Configuration validation failed with ${errors} error(s)" >&2
    return 1
  fi

  return 0
}

# Get configuration value
# Returns the value of a configuration variable
#
# Usage: get_config_value "VARIABLE_NAME"
# Returns: 0 on success, 1 if variable not set
get_config_value() {
  local var_name="$1"
  
  if [[ -z "${var_name}" ]]; then
    echo "Error: Variable name required" >&2
    return 1
  fi

  # Check if variable is set
  if [[ -z "${!var_name+x}" ]]; then
    echo "Error: Variable '${var_name}' is not set" >&2
    return 1
  fi

  echo "${!var_name}"
  return 0
}

# Check if tag should be excluded from sync
# Checks against both system tags and user-configured exclusions
#
# Usage: is_tag_excluded "tag-name"
# Returns: 0 if excluded, 1 if not excluded
is_tag_excluded() {
  local tag="$1"
  
  if [[ -z "${tag}" ]]; then
    return 1
  fi

  # Check system tags
  IFS=',' read -ra system_tags <<< "${GITHUB_SYSTEM_TAGS}"
  for system_tag in "${system_tags[@]}"; do
    # Handle wildcard patterns
    if [[ "${system_tag}" == *"*" ]]; then
      local pattern="${system_tag%\*}"
      if [[ "${tag}" == "${pattern}"* ]]; then
        return 0
      fi
    elif [[ "${tag}" == "${system_tag}" ]]; then
      return 0
    fi
  done

  # Check user-configured exclusions
  if [[ -n "${GITHUB_EXCLUDE_TAGS}" ]]; then
    IFS=',' read -ra exclude_tags <<< "${GITHUB_EXCLUDE_TAGS}"
    for exclude_tag in "${exclude_tags[@]}"; do
      if [[ "${tag}" == "${exclude_tag}" ]]; then
        return 0
      fi
    done
  fi

  return 1
}

# Check if label should be excluded from sync
# Checks against user-configured exclusions
# Priority labels (priority:*) are handled separately by field mapper
#
# Usage: is_label_excluded "label-name"
# Returns: 0 if excluded, 1 if not excluded
is_label_excluded() {
  local label="$1"
  
  if [[ -z "${label}" ]]; then
    return 1
  fi

  # Check user-configured exclusions
  if [[ -n "${GITHUB_EXCLUDE_LABELS}" ]]; then
    IFS=',' read -ra exclude_labels <<< "${GITHUB_EXCLUDE_LABELS}"
    for exclude_label in "${exclude_labels[@]}"; do
      if [[ "${label}" == "${exclude_label}" ]]; then
        return 0
      fi
    done
  fi

  return 1
}

# Export configuration for use by other scripts
export_github_sync_config() {
  export GITHUB_DEFAULT_REPO
  export GITHUB_SYNC_STRATEGY
  export GITHUB_AUTO_SYNC
  export GITHUB_SYNC_FIELDS
  export GITHUB_EXCLUDE_TAGS
  export GITHUB_SYSTEM_TAGS
  export GITHUB_EXCLUDE_LABELS
  export GITHUB_ANNOTATION_PREFIX
  export GITHUB_COMMENT_PREFIX
  export GITHUB_LOG_LEVEL
  export GITHUB_LOG_MAX_SIZE
  export GITHUB_LOG_ROTATE_COUNT
  export GITHUB_BATCH_DELAY
  export GITHUB_MAX_RETRIES
  export GITHUB_RETRY_DELAY
  export GITHUB_DEBUG
  export GITHUB_DRY_RUN_DEFAULT
  export GITHUB_VALIDATE_ON_LOAD
}

# Initialize configuration
# Loads config and exports variables
# Call this at the start of any script that needs config
#
# Usage: init_github_sync_config
# Returns: 0 on success, 1 on failure
init_github_sync_config() {
  if ! load_github_sync_config; then
    return 1
  fi
  
  export_github_sync_config
  return 0
}
