#!/usr/bin/env bash
# Configuration management utilities for Workwarrior
# Provides template loading/saving, path updates, and validation helpers

# ============================================================================
# TEMPLATE MANAGEMENT
# ============================================================================

# Load a configuration template by name
# Usage: load_template "template-name" ["dest-path"]
# If dest-path is provided, copies the template to that path.
# Otherwise, prints template contents to stdout.
load_template() {
  local template_name="$1"
  local dest_path="$2"

  if [[ -z "$template_name" ]]; then
    log_error "Template name is required"
    return 1
  fi

  local template_path="$CONFIG_TEMPLATES_DIR/$template_name"
  if [[ ! -f "$template_path" ]]; then
    log_error "Template not found: $template_path"
    return 1
  fi

  if [[ -n "$dest_path" ]]; then
    if ! cp "$template_path" "$dest_path"; then
      log_error "Failed to copy template to: $dest_path"
      return 1
    fi
    return 0
  fi

  cat "$template_path"
}

# Save a configuration template by name from an existing file
# Usage: save_template "template-name" "source-path"
save_template() {
  local template_name="$1"
  local source_path="$2"

  if [[ -z "$template_name" || -z "$source_path" ]]; then
    log_error "Template name and source path are required"
    return 1
  fi

  if [[ ! -f "$source_path" ]]; then
    log_error "Source file not found: $source_path"
    return 1
  fi

  ensure_directory "$CONFIG_TEMPLATES_DIR" || return 1

  local template_path="$CONFIG_TEMPLATES_DIR/$template_name"
  if ! cp "$source_path" "$template_path"; then
    log_error "Failed to save template to: $template_path"
    return 1
  fi

  return 0
}

# ============================================================================
# PATH UPDATES
# ============================================================================

# Update absolute paths inside known config files
# Usage: update_paths_in_config "config-file" "old-base" "new-base"
# Supports .taskrc and YAML configs (jrnl.yaml, ledgers.yaml).
update_paths_in_config() {
  local config_file="$1"
  local old_base="$2"
  local new_base="$3"

  if [[ -z "$config_file" || -z "$new_base" ]]; then
    log_error "Config file and new base path are required"
    return 1
  fi

  if [[ ! -f "$config_file" ]]; then
    log_error "Config file not found: $config_file"
    return 1
  fi

  if [[ "$config_file" == *.taskrc ]]; then
    local data_path="$new_base/.task"
    local hooks_path="$new_base/.task/hooks"

    if ! awk -v data="$data_path" -v hooks="$hooks_path" '
      BEGIN { found_data=0; found_hooks=0 }
      /^data\.location=/ { print "data.location=" data; found_data=1; next }
      /^hooks\.location=/ { print "hooks.location=" hooks; found_hooks=1; next }
      { print }
      END {
        if (!found_data) print "data.location=" data
        if (!found_hooks) print "hooks.location=" hooks
      }
    ' "$config_file" > "$config_file.tmp"; then
      log_error "Failed to update taskrc paths"
      rm -f "$config_file.tmp"
      return 1
    fi

    if ! mv "$config_file.tmp" "$config_file"; then
      log_error "Failed to save updated taskrc"
      rm -f "$config_file.tmp"
      return 1
    fi

    return 0
  fi

  if [[ "$config_file" == *.yaml || "$config_file" == *.yml ]]; then
    if [[ -z "$old_base" ]]; then
      log_error "Old base path is required for YAML updates"
      return 1
    fi

    if ! sed -i.bak "s|$old_base|$new_base|g" "$config_file"; then
      log_error "Failed to update paths in YAML config"
      return 1
    fi
    rm -f "$config_file.bak"
    return 0
  fi

  if [[ -z "$old_base" ]]; then
    log_error "Old base path is required for generic path updates"
    return 1
  fi

  if ! sed -i.bak "s|$old_base|$new_base|g" "$config_file"; then
    log_error "Failed to update paths in config"
    return 1
  fi
  rm -f "$config_file.bak"
  return 0
}

# ============================================================================
# VALIDATION
# ============================================================================

# Validate a taskrc file for required fields
# Usage: validate_taskrc "/path/to/.taskrc"
validate_taskrc() {
  local taskrc="$1"

  if [[ -z "$taskrc" || ! -f "$taskrc" ]]; then
    log_error "TaskRC not found: $taskrc"
    return 1
  fi

  local data_location
  data_location=$(grep "^data\.location=" "$taskrc" | tail -n1 | cut -d= -f2)
  local hooks_location
  hooks_location=$(grep "^hooks\.location=" "$taskrc" | tail -n1 | cut -d= -f2)
  local hooks_enabled
  hooks_enabled=$(grep "^hooks=" "$taskrc" | tail -n1 | cut -d= -f2)

  if [[ -z "$data_location" || -z "$hooks_location" ]]; then
    log_error "TaskRC missing data.location or hooks.location"
    return 1
  fi

  if [[ "$data_location" != /* || "$hooks_location" != /* ]]; then
    log_error "TaskRC paths must be absolute"
    return 1
  fi

  if [[ "$hooks_enabled" != "on" && "$hooks_enabled" != "1" ]]; then
    log_error "TaskRC hooks not enabled"
    return 1
  fi

  return 0
}

# Validate jrnl.yaml configuration
# Usage: validate_jrnl_config "/path/to/jrnl.yaml"
validate_jrnl_config() {
  local jrnl_config="$1"

  if [[ -z "$jrnl_config" || ! -f "$jrnl_config" ]]; then
    log_error "Journal configuration not found: $jrnl_config"
    return 1
  fi

  if ! grep -q "^journals:" "$jrnl_config"; then
    log_error "jrnl.yaml missing journals section"
    return 1
  fi

  if ! grep -q "^  default:" "$jrnl_config"; then
    log_error "jrnl.yaml missing default journal"
    return 1
  fi

  while IFS= read -r line; do
    local path
    path=$(echo "$line" | awk -F": " '{print $2}')
    if [[ -n "$path" && "$path" != /* ]]; then
      log_error "Journal path is not absolute: $path"
      return 1
    fi
  done < <(grep "^  [a-zA-Z0-9_-]\+:" "$jrnl_config")

  local default_path
  default_path=$(grep "^  default:" "$jrnl_config" | awk -F": " '{print $2}')
  if [[ -n "$default_path" && ! -f "$default_path" ]]; then
    log_error "Default journal file not found: $default_path"
    return 1
  fi

  return 0
}

# Validate ledgers.yaml configuration
# Usage: validate_ledger_config "/path/to/ledgers.yaml"
validate_ledger_config() {
  local ledger_config="$1"

  if [[ -z "$ledger_config" || ! -f "$ledger_config" ]]; then
    log_error "Ledger configuration not found: $ledger_config"
    return 1
  fi

  if ! grep -q "^ledgers:" "$ledger_config"; then
    log_error "ledgers.yaml missing ledgers section"
    return 1
  fi

  if ! grep -q "^  default:" "$ledger_config"; then
    log_error "ledgers.yaml missing default ledger"
    return 1
  fi

  local default_path
  default_path=$(grep "^  default:" "$ledger_config" | awk -F": " '{print $2}')
  if [[ -z "$default_path" || "$default_path" != /* ]]; then
    log_error "Default ledger path must be absolute"
    return 1
  fi

  if [[ ! -f "$default_path" ]]; then
    log_error "Default ledger file not found: $default_path"
    return 1
  fi

  return 0
}

# ============================================================================
# LIBRARY LOADED INDICATOR
# ============================================================================

readonly CONFIG_UTILS_LOADED=1
