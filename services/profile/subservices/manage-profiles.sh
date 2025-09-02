#!/usr/bin/env bash
set -e

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly SHELL_RC="$HOME/.bashrc"
readonly PROFILES_DIR="$HOME/ww/profiles"
readonly SERVICES_DIR="$HOME/ww/services/profile"
readonly TASKRC_SRC="$HOME/ww/functions/tasks/default-taskrc/.taskrc"

# Logging utilities
log_info()    { echo "ℹ $*"; }
log_success() { echo "✓ $*"; }
log_warning() { echo "⚠ $*"; }
log_error()   { echo "✗ $*" >&2; }
log_step()    { echo "🔧 $*"; }

# Validate profile names
validate_profile_name() {
  local name="$1"
  if [[ -z $name ]]; then
    log_error "Profile name cannot be empty"
    return 1
  fi
  if [[ ! $name =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Profile name must be letters, numbers, hyphens or underscores"
    return 1
  fi
  if (( ${#name} > 50 )); then
    log_error "Profile name cannot exceed 50 characters"
    return 1
  fi
  return 0
}

# Check existence
profile_exists() {
  [[ -d "$PROFILES_DIR/$1" ]]
}

# List existing profiles
list_profiles() {
  if [[ ! -d $PROFILES_DIR ]]; then
    log_warning "Profiles folder not found at $PROFILES_DIR"
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
  printf '%s\n' "${profiles[@]}" | sort
}

# Create a new profile
create_profile() {
  local name="$1"
  if ! validate_profile_name "$name"; then return 1; fi
  if profile_exists "$name"; then
    log_error "Profile '$name' already exists"
    return 1
  fi

  log_step "Creating profile '$name'..."
  local base="$PROFILES_DIR/$name"
  mkdir -p "$base/.task/hooks" "$base/.timewarrior" "$base/journals" "$base/ledgers"

  # Initialize configs
  create_taskrc "$base"
  create_journals "$base" "$name"
  create_ledgers "$base" "$name"

  # Hook & aliases
  create_aliases "$name"
  install_timewarrior_hook "$base/.task"
  ensure_profile_function

  log_success "Profile '$name' created successfully!"
  log_info "source $SHELL_RC && use taskwarrior with p-$name"
}

# Create .taskrc
create_taskrc() {
  local base="$1"
  local dest="$base/.taskrc"
  if [[ -f "$TASKRC_SRC" ]]; then
    cp "$TASKRC_SRC" "$dest"
  else
    cat > "$dest" <<'EOF'
# Default TaskWarrior config
data.location=~/.task
EOF
  fi
}

# Create journal
create_journals() {
  local base="$1" name="$2"
  local jfile="$base/journals/$name.txt"
  echo "$(date '+%Y-%m-%d %H:%M'): Welcome to $name journal!" >"$jfile"
  cat > "$base/jrnl.yaml" <<EOF
journals:
  $name: $jfile
editor: nano
timeformat: "%Y-%m-%d %H:%M"
EOF
}

# Create ledger
create_ledgers() {
  local base="$1" name="$2"
  local lf="$base/ledgers/$name.journal"
  cat > "$lf" <<EOF
; Hledger journal for $name
$(date '+%Y-%m-%d') * Init
  assets:cash  $0.00
EOF
  cat > "$base/ledgers.yaml" <<EOF
ledgers:
  $name: $lf
EOF
}

# Setup shell aliases
create_aliases() {
  local name="$1" base="$PROFILES_DIR/$name"
  add_alias_if_missing "alias p-$name='use_task_profile $name'"
  add_alias_if_missing "alias $name='use_task_profile $name'"
}

# Helper to append alias if needed
add_alias_if_missing() {
  local line="$1"
  grep -Fxq "$line" "$SHELL_RC" || echo "$line" >> "$SHELL_RC"
}

# Install or create hook for timewarrior
install_timewarrior_hook() {
  local taskdata_dir="$1"
  local hook_path="$taskdata_dir/hooks/on-modify.timewarrior"
  if [[ -f "$SERVICES_DIR/on-modify.timewarrior" ]]; then
    cp "$SERVICES_DIR/on-modify.timewarrior" "$hook_path"
  else
    cat > "$hook_path" <<'EOF'
#!/usr/bin/env python3
import sys, json
for line in sys.stdin:
    print(line.strip())
EOF
  fi
  chmod +x "$hook_path"
}

# Ensure shell function is in rc
ensure_profile_function() {
  local pat="function use_task_profile"
  if ! grep -q "$pat" "$SHELL_RC"; then
    cat >> "$SHELL_RC" <<'EOF'

function use_task_profile() {
  local p="$1"
  export TASKRC="$HOME/ww/profiles/$p/.taskrc"
  export TASKDATA="$HOME/ww/profiles/$p/.task"
  echo "Activated profile: $p"
}
EOF
  fi
}

# Delete a profile
delete_profile() {
  local name="$1"
  if ! validate_profile_name "$name"; then return 1; fi
  if ! profile_exists "$name"; then
    log_error "Profile '$name' doesn't exist"
    return 1
  fi
  rm -rf "$PROFILES_DIR/$name"
  log_success "Deleted profile '$name'"
  sed -i "/p-$name/d" "$SHELL_RC"
}

# Show info
show_profile_info() {
  local name="$1"
  if ! validate_profile_name "$name"; then return 1; fi
  if ! profile_exists "$name"; then
    log_error "Profile '$name' doesn't exist"
    return 1
  fi
  local base="$PROFILES_DIR/$name"
  echo "Profile: $name"
  echo "Location: $base"
  du -sh "$base"
}

# Backup
backup_profile() {
  local name="$1" dest="${2:-$HOME}"
  if ! validate_profile_name "$name"; then return 1; fi
  if ! profile_exists "$name"; then
    log_error "Profile '$name' doesn't exist"
    return 1
  fi
  local tarfile="$dest/${name}_backup_$(date '+%Y%m%d%H%M%S').tar.gz"
  tar -czf "$tarfile" -C "$PROFILES_DIR" "$name"
  log_success "Backup created: $tarfile"
}

# Usage/help
show_usage() {
  cat <<EOF
Usage: $SCRIPT_NAME <command> [args]

Commands:
  create <name>     Create a profile
  delete <name>     Delete a profile
  list              List all profiles
  info <name>       Show profile info
  backup <name> [dir]  Backup profile
  help              Show this message
EOF
  exit 1
}

# Main dispatcher
main() {
  [[ $# -lt 1 ]] && show_usage
  local cmd="$1"; shift
  case "$cmd" in
    create) [[ $# -eq 1 ]] || show_usage; create_profile "$1" ;;
    delete) [[ $# -eq 1 ]] || show_usage; delete_profile "$1" ;;
    list) [[ $# -eq 0 ]] || show_usage; list_profiles ;;
    info) [[ $# -eq 1 ]] || show_usage; show_profile_info "$1" ;;
    backup) [[ $# -ge 1 && $# -le 2 ]] || show_usage; backup_profile "$1" "$2" ;;
    help) show_usage ;;
    *) show_usage ;;
  esac
}

# Execute main
main "$@"