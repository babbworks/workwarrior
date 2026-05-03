#!/usr/bin/env bash
# GitHub Two-Way Sync Configuration
# This file should be copied to: $WORKWARRIOR_BASE/.config/github-sync/config.sh
# 
# Configuration options for GitHub bidirectional sync

# ============================================================================
# REPOSITORY SETTINGS
# ============================================================================

# Default repository (owner/repo format)
# Used when no repository is specified in commands
# Example: GITHUB_DEFAULT_REPO="myorg/myproject"
GITHUB_DEFAULT_REPO="${GITHUB_DEFAULT_REPO:-}"

# ============================================================================
# CONFLICT RESOLUTION
# ============================================================================

# Conflict resolution strategy
# Options:
#   - last_write_wins: Use the most recently modified version (default)
#   - github_wins: Always prefer GitHub state in conflicts
#   - task_wins: Always prefer TaskWarrior state in conflicts
#   - manual: Prompt user for each conflict (future feature)
GITHUB_SYNC_STRATEGY="${GITHUB_SYNC_STRATEGY:-last_write_wins}"

# ============================================================================
# SYNC BEHAVIOR
# ============================================================================

# Auto-sync on task modify (future feature)
# When enabled, tasks will automatically sync to GitHub on modification
# Currently not implemented - manual sync only
GITHUB_AUTO_SYNC="${GITHUB_AUTO_SYNC:-false}"

# Fields to sync (comma-separated)
# Available fields: description, status, priority, tags, annotations
# Default: all fields
GITHUB_SYNC_FIELDS="${GITHUB_SYNC_FIELDS:-description,status,priority,tags,annotations}"

# ============================================================================
# TAG AND LABEL FILTERING
# ============================================================================

# Tags to exclude from syncing (comma-separated)
# System tags are automatically excluded
# Add custom tags here that should not sync to GitHub labels
# Example: GITHUB_EXCLUDE_TAGS="private,internal,local"
GITHUB_EXCLUDE_TAGS="${GITHUB_EXCLUDE_TAGS:-}"

# System tags (automatically excluded, do not modify)
GITHUB_SYSTEM_TAGS="ACTIVE,READY,PENDING,COMPLETED,DELETED,WAITING,RECURRING,PARENT,CHILD,BLOCKED,UNBLOCKED,OVERDUE,TODAY,TOMORROW,WEEK,MONTH,YEAR,sync:*"

# Labels to exclude from syncing (comma-separated)
# Priority labels (priority:*) are automatically handled
# Add custom labels here that should not sync to TaskWarrior tags
# Example: GITHUB_EXCLUDE_LABELS="wontfix,duplicate"
GITHUB_EXCLUDE_LABELS="${GITHUB_EXCLUDE_LABELS:-}"

# ============================================================================
# ANNOTATION AND COMMENT PREFIXES
# ============================================================================

# Prefix for annotations synced to GitHub comments
# This helps identify which comments originated from TaskWarrior
GITHUB_ANNOTATION_PREFIX="${GITHUB_ANNOTATION_PREFIX:-[TaskWarrior]}"

# Prefix for comments synced to TaskWarrior annotations
# Format: "[GitHub @username]" - username is added automatically
GITHUB_COMMENT_PREFIX="${GITHUB_COMMENT_PREFIX:-[GitHub}"

# ============================================================================
# LOGGING
# ============================================================================

# Log level
# Options: DEBUG, INFO, WARN, ERROR
# DEBUG: Verbose logging for troubleshooting
# INFO: Normal operation logging (default)
# WARN: Only warnings and errors
# ERROR: Only errors
GITHUB_LOG_LEVEL="${GITHUB_LOG_LEVEL:-INFO}"

# Maximum log file size (in MB)
# When exceeded, logs will be rotated
GITHUB_LOG_MAX_SIZE="${GITHUB_LOG_MAX_SIZE:-10}"

# Number of rotated log files to keep
GITHUB_LOG_ROTATE_COUNT="${GITHUB_LOG_ROTATE_COUNT:-5}"

# ============================================================================
# RATE LIMITING
# ============================================================================

# Delay between batch operations (in seconds)
# Helps avoid hitting GitHub API rate limits
# Default: 1 second between operations
GITHUB_BATCH_DELAY="${GITHUB_BATCH_DELAY:-1}"

# Maximum retries for failed operations
# After this many retries, the operation will be skipped
GITHUB_MAX_RETRIES="${GITHUB_MAX_RETRIES:-3}"

# Retry delay (in seconds)
# Time to wait before retrying a failed operation
GITHUB_RETRY_DELAY="${GITHUB_RETRY_DELAY:-2}"

# ============================================================================
# ADVANCED OPTIONS
# ============================================================================

# Enable debug mode
# Prints additional diagnostic information
GITHUB_DEBUG="${GITHUB_DEBUG:-false}"

# Dry-run mode by default
# When enabled, all operations will be dry-run unless explicitly disabled
GITHUB_DRY_RUN_DEFAULT="${GITHUB_DRY_RUN_DEFAULT:-false}"

# Validate configuration on load
# Checks that all required tools are installed and configured
GITHUB_VALIDATE_ON_LOAD="${GITHUB_VALIDATE_ON_LOAD:-true}"

# ============================================================================
# NOTES
# ============================================================================

# This configuration file is sourced by the GitHub sync engine
# All variables should use the GITHUB_ prefix to avoid conflicts
# Boolean values should be "true" or "false" (lowercase)
# Paths should be absolute or use environment variables
# 
# To apply changes, no restart is needed - changes take effect immediately
# 
# For more information, see:
#   - docs/manual-testing-guide.md
#   - .kiro/specs/github-two-way-sync/design.md
