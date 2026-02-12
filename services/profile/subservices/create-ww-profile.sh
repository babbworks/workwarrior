#!/usr/bin/env bash
set -e

SHELL_RC="$HOME/.bashrc"

# --- Normal Profile Creation ---
PROFILE_NAME="$1"
if [[ -z "$PROFILE_NAME" ]]; then
  echo "Usage: $0 <profile-name>     (or: $0 --delete <profile-name>)"
  exit 1
fi

BASE="$HOME/ww/profiles/$PROFILE_NAME"
TASKDATA="$BASE/.task"
TIMEWDB="$BASE/.timewarrior"
JOURNALS="$BASE/journals"
LEDGERS="$BASE/ledgers"
LIST_DIR="$BASE/list"
DEFAULT_LIST_FILE="$LIST_DIR/${PROFILE_NAME}_default.list"

HOOKSRC=$(find ~/ww/services/profile/ -name "on-modify.timewarrior" 2>/dev/null | head -n 1)
TASKRC_SRC="$HOME/ww/functions/tasks/default-taskrc/.taskrc"
DEF_ACCOUNTS="$HOME/ww/functions/ledgers/defaultaccounts/defaccounts.txt"

list_profiles() {
  if [[ -d "$HOME/ww/profiles" ]]; then
    find "$HOME/ww/profiles" -maxdepth 1 -type d -exec basename {} \; | grep -v "^profiles$" | sort
  fi
}

# Function to add aliases to the correct section in bashrc
add_alias_to_section() {
  local alias_line="$1"
  local section_marker="$2"
  local temp_file=$(mktemp)

  if grep -Fxq "$alias_line" "$SHELL_RC"; then
    return 0
  fi

  if ! grep -Fxq "$section_marker" "$SHELL_RC"; then
    echo "" >> "$SHELL_RC"
    echo "$section_marker" >> "$SHELL_RC"
  fi

  awk -v section="$section_marker" -v new_alias="$alias_line" '
    {
      print $0
      if ($0 == section && !added) {
        print new_alias
        added = 1
      }
    }
  ' "$SHELL_RC" > "$temp_file" && mv "$temp_file" "$SHELL_RC"
}

echo "🔧 Creating Workwarrior profile: $PROFILE_NAME"
echo

mkdir -p "$TASKDATA/hooks" "$TIMEWDB" "$JOURNALS" "$LEDGERS" "$LIST_DIR"
touch "$DEFAULT_LIST_FILE"

# --- Customization Prompts ---
taskrc_custom_path=""; taskrc_source=""
jrnl_custom_path=""; jrnl_source=""
ledger_custom_path=""; ledger_source=""

# --- .taskrc ---
TASKRC_DEST="$BASE/.taskrc"
if [[ -f "$TASKRC_SRC" ]]; then
  cp "$TASKRC_SRC" "$TASKRC_DEST"
  echo "✓ Copied .taskrc from default template: $TASKRC_SRC"
else
  touch "$TASKRC_DEST"
  echo "✓ Created empty .taskrc file at $TASKRC_DEST"
fi

# --- jrnl.yaml + default journal ---
default_journal_file="$JOURNALS/$PROFILE_NAME.txt"
echo "$(date '+%Y-%m-%d %H:%M'): Welcome to your $PROFILE_NAME journal!" > "$default_journal_file"
cat > "$BASE/jrnl.yaml" << EOF
journals:
  default: $default_journal_file
editor: nano
encrypt: false
tagsymbols: '@'
default_hour: 9
default_minute: 0
timeformat: "%Y-%m-%d %H:%M"
highlight: true
linewrap: 79
template: false
colors:
  body: none
  date: blue
  tags: yellow
  title: cyan
EOF

echo "✓ Created default journal: $default_journal_file"
echo "✓ Created jrnl.yaml with default journal: $default_journal_file"

# --- Ledger ---
default_ledger_file="$LEDGERS/$PROFILE_NAME.journal"
cat > "$default_ledger_file" <<EOF
; Hledger journal for $PROFILE_NAME
; Initialized on $(date '+%Y-%m-%d')
account assets:cash
account expenses:misc
account equity:opening-balances

$(date '+%Y-%m-%d') * Profile initialization
    assets:cash          \$0.00
    equity:opening-balances   \$0.00
EOF

echo "✓ Created default ledger: $default_ledger_file"

# --- Journal Aliases Creation ---
MAIN_J_ALIAS="alias j-$PROFILE_NAME='jrnl --config-file \"$BASE/jrnl.yaml\"'"
add_alias_to_section "$MAIN_J_ALIAS" "# -- Direct Alias for Journals ---"
echo "✓ Created main journal alias: j-$PROFILE_NAME"

# --- Ledger Aliases Creation ---
L_ALIAS="alias l-$PROFILE_NAME='hledger -f \"$default_ledger_file\"'"
add_alias_to_section "$L_ALIAS" "# -- Direct Aliases for Hledger ---"
echo "✓ Created ledger alias: l-$PROFILE_NAME"

# --- Profile Aliases Creation ---
P_ALIAS="alias p-$PROFILE_NAME='use_task_profile $PROFILE_NAME'"
MAIN_ALIAS="alias $PROFILE_NAME='use_task_profile $PROFILE_NAME'"
add_alias_to_section "$P_ALIAS" "# -- Workwarrior Profile Aliases ---"
add_alias_to_section "$MAIN_ALIAS" "# -- Workwarrior Profile Aliases ---"
echo "✓ Created profile aliases: p-$PROFILE_NAME and $PROFILE_NAME"

# --- List Tool Alias Creation ---
LIST_ALIAS="alias list-$PROFILE_NAME='python3 \"$HOME/ww/tools/list/list.py\" -t \"$LIST_DIR\"'"
add_alias_to_section "$LIST_ALIAS" "# -- Direct Aliases for List tool ---"
echo "✓ Created list-$PROFILE_NAME alias"
echo "✓ Created default list file: $DEFAULT_LIST_FILE"

# --- Install Timewarrior hook ---
if [[ -f "$HOOKSRC" ]]; then
  cp "$HOOKSRC" "$TASKDATA/hooks/on-modify.timewarrior"
  chmod +x "$TASKDATA/hooks/on-modify.timewarrior"
  echo "✓ Installed on-modify.timewarrior hook"
else
  cat > "$TASKDATA/hooks/on-modify.timewarrior" <<'EOF'
#!/usr/bin/env python3
import sys, json, subprocess
def timewarrior(*args): return subprocess.call(['timew'] + list(args))
def main():
    original = modified = None
    for line in sys.stdin:
        if line.strip() == '': break
        if original is None: original = json.loads(line)
        else: modified = json.loads(line)
    print(json.dumps(modified))
if __name__ == '__main__': main()
EOF
  chmod +x "$TASKDATA/hooks/on-modify.timewarrior"
  echo "✓ Created fallback timewarrior hook"
fi

# --- Add/Update use_task_profile and global t function in .bashrc ---
if ! grep -q 'function use_task_profile' "$SHELL_RC"; then
  cat >> "$SHELL_RC" <<'EOF'

# --- Workwarrior Core Functions ---

function j() {
  local ww_base="${WW_BASE:-$HOME/ww}"
  if [[ -f "$ww_base/lib/shell-integration.sh" ]]; then
    unset -f j
    source "$ww_base/lib/shell-integration.sh"
    j "$@"
    return $?
  fi
  echo "Error: shell integration not found at $ww_base/lib/shell-integration.sh" >&2
  return 1
}

function l() {
  local ww_base="${WW_BASE:-$HOME/ww}"
  if [[ -f "$ww_base/lib/shell-integration.sh" ]]; then
    unset -f l
    source "$ww_base/lib/shell-integration.sh"
    l "$@"
    return $?
  fi
  echo "Error: shell integration not found at $ww_base/lib/shell-integration.sh" >&2
  return 1
}

function list() {
  local ww_base="${WW_BASE:-$HOME/ww}"
  if [[ -f "$ww_base/lib/shell-integration.sh" ]]; then
    unset -f list
    source "$ww_base/lib/shell-integration.sh"
    list "$@"
    return $?
  fi
  echo "Error: shell integration not found at $ww_base/lib/shell-integration.sh" >&2
  return 1
}

function use_task_profile() {
  local profile="$1"
  if [[ -z "$profile" ]]; then
    echo "Usage: use_task_profile <profile-name>" >&2
    return 1
  fi

  local base="$HOME/ww/profiles/$profile"
  if [[ ! -d "$base" ]]; then
    echo "Error: Profile '$profile' not found at $base" >&2
    return 1
  fi

  export WARRIOR_PROFILE="$profile"
  export WORKWARRIOR_BASE="$base"
  export TASKRC="$base/.taskrc"
  export TASKDATA="$base/.task"
  export TIMEWARRIORDB="$base/.timewarrior"

  eval "$(declare -f j)"
  eval "$(declare -f l)"
  eval "$(declare -f list)"

  echo "Now using Workwarrior profile: $profile"
  echo "✓ Global 'j' command now writes to $profile's default journal"
  echo "✓ Global 'l' command now uses $profile's default ledger"
  echo "✓ Global 'list' command now uses $profile's default list directory"
  echo "✓ Use 'task start <id>' to start tasks with timewarrior integration"
}
EOF
  echo "✓ Added core Workwarrior functions and global 'list' function to $SHELL_RC"
fi

source "$SHELL_RC" > /dev/null 2>&1

echo
echo "✅ Profile '$PROFILE_NAME' setup complete!"
echo "📁 Location: $BASE"
echo "📝 Default Journal: $default_journal_file"
echo "💰 Ledgers: $PROFILE_NAME"
echo "🗂  TaskRC: $TASKRC_DEST"
echo "🗒  List: $DEFAULT_LIST_FILE"
echo
echo "👉 Run: source $SHELL_RC"
echo "👉 Then use: j-$PROFILE_NAME for direct journal access"
echo "👉 Or: p-$PROFILE_NAME or $PROFILE_NAME to activate profile (enables simple 'j', 'l' and 'list' commands)"
echo "👉 Use: list-$PROFILE_NAME to run list tool inside this profile"
echo
