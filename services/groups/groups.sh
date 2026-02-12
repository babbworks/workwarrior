#!/usr/bin/env bash
# Service: groups
# Category: groups
# Description: Manage profile groupings for easy listing and association

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/core-utils.sh"

GROUPS_CONFIG="${WW_BASE:-$HOME/ww}/config/groups.yaml"

ensure_groups_config() {
  local cfg="$GROUPS_CONFIG"
  if [[ ! -f "$cfg" ]]; then
    mkdir -p "$(dirname "$cfg")"
    cat > "$cfg" << 'EOF'
groups:
EOF
  fi
}

validate_group_name() {
  local name="$1"
  if [[ -z "$name" ]]; then
    log_error "Group name cannot be empty"
    return 1
  fi
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Group name must contain only letters, numbers, hyphens, and underscores"
    return 1
  fi
  return 0
}

group_exists() {
  local name="$1"
  grep -q "^  ${name}:" "$GROUPS_CONFIG"
}

list_groups() {
  ensure_groups_config
  echo "Groups:"
  if ! grep -q "^  " "$GROUPS_CONFIG"; then
    echo "  (none)"
    return 0
  fi
  grep "^  [a-zA-Z0-9_-]\+:" "$GROUPS_CONFIG" | sed 's/^  /  • /'
}

show_group() {
  local name="$1"
  validate_group_name "$name" || return 1
  ensure_groups_config
  if ! group_exists "$name"; then
    log_error "Group not found: $name"
    return 1
  fi

  echo "Group: $name"
  local in_block=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]{2}${name}:[[:space:]]*$ ]]; then
      in_block=1
      continue
    fi
    if [[ $in_block -eq 1 && "$line" =~ ^[[:space:]]{2}[a-zA-Z0-9_-]+:[[:space:]]*$ ]]; then
      break
    fi
    if [[ $in_block -eq 1 ]]; then
      if [[ "$line" =~ ^[[:space:]]{6}-[[:space:]]*(.+)$ ]]; then
        echo "  • ${BASH_REMATCH[1]}"
      fi
    fi
  done < "$GROUPS_CONFIG"
}

create_group() {
  local name="$1"
  shift || true
  validate_group_name "$name" || return 1
  ensure_groups_config
  if group_exists "$name"; then
    log_error "Group already exists: $name"
    return 1
  fi

  {
    echo "  ${name}:"
    echo "    profiles:"
    for profile in "$@"; do
      validate_profile_name "$profile" || return 1
      if ! profile_exists "$profile"; then
        log_warning "Profile does not exist: $profile (still adding)"
      fi
      echo "      - $profile"
    done
  } >> "$GROUPS_CONFIG"

  log_success "Created group: $name"
}

add_to_group() {
  local name="$1"
  shift || true
  validate_group_name "$name" || return 1
  ensure_groups_config
  if ! group_exists "$name"; then
    log_error "Group not found: $name"
    return 1
  fi

  local tmp_file="${GROUPS_CONFIG}.tmp"
  local added_any=0

  awk -v name="$name" -v profiles="$*" '
    BEGIN {
      split(profiles, p, " ");
      for (i in p) wanted[p[i]] = 1;
    }
    {
      print
      if ($0 ~ "^  " name ":[[:space:]]*$") {
        in_group = 1
      } else if (in_group && $0 ~ "^  [a-zA-Z0-9_-]+:[[:space:]]*$") {
        if (!inserted) {
          for (k in wanted) {
            if (!seen[k]) {
              print "      - " k
              added_any = 1
            }
          }
          inserted = 1
        }
        in_group = 0
      } else if (in_group && $0 ~ "^      - ") {
        val = $0
        sub("^      - ", "", val)
        seen[val] = 1
      }
    }
    END {
      if (in_group && !inserted) {
        for (k in wanted) {
          if (!seen[k]) {
            print "      - " k
            added_any = 1
          }
        }
      }
    }
  ' "$GROUPS_CONFIG" > "$tmp_file"

  mv "$tmp_file" "$GROUPS_CONFIG"

  if [[ $added_any -eq 1 ]]; then
    log_success "Updated group: $name"
  else
    log_info "No changes (all profiles already present)"
  fi
}

remove_from_group() {
  local name="$1"
  shift || true
  validate_group_name "$name" || return 1
  ensure_groups_config
  if ! group_exists "$name"; then
    log_error "Group not found: $name"
    return 1
  fi

  local tmp_file="${GROUPS_CONFIG}.tmp"
  local removed_any=0

  awk -v name="$name" -v profiles="$*" '
    BEGIN {
      split(profiles, p, " ");
      for (i in p) remove[p[i]] = 1;
    }
    {
      if ($0 ~ "^  " name ":[[:space:]]*$") {
        in_group = 1
        print
        next
      }
      if (in_group && $0 ~ "^  [a-zA-Z0-9_-]+:[[:space:]]*$") {
        in_group = 0
      }
      if (in_group && $0 ~ "^      - ") {
        val = $0
        sub("^      - ", "", val)
        if (remove[val]) {
          removed_any = 1
          next
        }
      }
      print
    }
  ' "$GROUPS_CONFIG" > "$tmp_file"

  mv "$tmp_file" "$GROUPS_CONFIG"

  if [[ $removed_any -eq 1 ]]; then
    log_success "Updated group: $name"
  else
    log_info "No changes (profiles not found in group)"
  fi
}

delete_group() {
  local name="$1"
  validate_group_name "$name" || return 1
  ensure_groups_config
  if ! group_exists "$name"; then
    log_error "Group not found: $name"
    return 1
  fi

  local tmp_file="${GROUPS_CONFIG}.tmp"
  awk -v name="$name" '
    BEGIN { in_group = 0 }
    $0 ~ "^  " name ":[[:space:]]*$" { in_group = 1; next }
    in_group && $0 ~ "^  [a-zA-Z0-9_-]+:[[:space:]]*$" { in_group = 0 }
    in_group { next }
    { print }
  ' "$GROUPS_CONFIG" > "$tmp_file"

  mv "$tmp_file" "$GROUPS_CONFIG"
  log_success "Deleted group: $name"
}

show_help() {
  cat << EOF
Groups Service

Usage: ww groups <action> [arguments]

Actions:
  list                          List all groups
  show <group>                  Show profiles in a group
  create <group> [profiles...]  Create a group with optional profiles
  add <group> <profiles...>     Add profiles to a group
  remove <group> <profiles...>  Remove profiles from a group
  delete <group>                Delete a group

Examples:
  ww groups create focus work personal
  ww groups add focus client-x
  ww groups show focus
  ww groups list
  ww groups delete focus
EOF
}

main() {
  local action="${1:-}"
  shift 2>/dev/null || true

  case "$action" in
    list|"")
      list_groups
      ;;
    show)
      if [[ -z "${1:-}" ]]; then
        log_error "Group name required"
        exit 1
      fi
      show_group "$1"
      ;;
    create)
      if [[ -z "${1:-}" ]]; then
        log_error "Group name required"
        exit 1
      fi
      create_group "$@"
      ;;
    add)
      if [[ -z "${1:-}" || -z "${2:-}" ]]; then
        log_error "Group name and profiles required"
        exit 1
      fi
      local name="$1"
      shift
      add_to_group "$name" "$@"
      ;;
    remove)
      if [[ -z "${1:-}" || -z "${2:-}" ]]; then
        log_error "Group name and profiles required"
        exit 1
      fi
      local name="$1"
      shift
      remove_from_group "$name" "$@"
      ;;
    delete)
      if [[ -z "${1:-}" ]]; then
        log_error "Group name required"
        exit 1
      fi
      delete_group "$1"
      ;;
    help|-h|--help)
      show_help
      ;;
    *)
      log_error "Unknown action: $action"
      show_help
      exit 1
      ;;
  esac
}

main "$@"
