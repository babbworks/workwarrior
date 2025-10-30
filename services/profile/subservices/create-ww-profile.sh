#!/usr/bin/env bash
set -e

SHELL_RC="$HOME/.bashrc"
<<<<<<< HEAD

# --- Normal Profile Creation ---
PROFILE_NAME="$1"
if [[ -z "$PROFILE_NAME" ]]; then
  echo "Usage: $0 <profile-name>     (or: $0 --delete <profile-name>)"
  exit 1
fi

=======
PROFILE_NAME="$1"
PROFILE_TYPE="$2"  # "quick" or "custom"

if [[ -z "$PROFILE_NAME" ]]; then
  echo "Usage: $0 <profile-name> [quick|custom]"
  exit 1
fi

PROFILE_TYPE="${PROFILE_TYPE:-quick}"  # default to quick if not provided
>>>>>>> b78e8d2 (updating for transfer to Lenovo)
BASE="$HOME/ww/profiles/$PROFILE_NAME"
TASKDATA="$BASE/.task"
TIMEWDB="$BASE/.timewarrior"
JOURNALS="$BASE/journals"
LEDGERS="$BASE/ledgers"
TODO_DIR="$BASE/todo"
DEFAULT_TODO_FILE="$TODO_DIR/${PROFILE_NAME}_default.todo"
<<<<<<< HEAD

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

=======
HOOKSRC=$(find ~/ww/services/profile/ -name "on-modify.timewarrior" 2>/dev/null | head -n 1)
TASKRC_SRC="$HOME/ww/functions/tasks/default-taskrc/.taskrc"

mkdir -p "$TASKDATA/hooks" "$TIMEWDB" "$JOURNALS" "$LEDGERS" "$TODO_DIR"
touch "$DEFAULT_TODO_FILE"

# Function to add aliases in a dedicated section
add_alias_to_section() {
  local alias_line="$1"
  local section_marker="$2"
  local temp_file
  temp_file=$(mktemp)

  if grep -Fxq "$alias_line" "$SHELL_RC"; then return 0; fi
>>>>>>> b78e8d2 (updating for transfer to Lenovo)
  if ! grep -Fxq "$section_marker" "$SHELL_RC"; then
    echo "" >> "$SHELL_RC"
    echo "$section_marker" >> "$SHELL_RC"
  fi

  awk -v section="$section_marker" -v new_alias="$alias_line" '
<<<<<<< HEAD
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

mkdir -p "$TASKDATA/hooks" "$TIMEWDB" "$JOURNALS" "$LEDGERS" "$TODO_DIR"
touch "$DEFAULT_TODO_FILE"

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
=======
    { print $0 }
    $0 == section && !added { print new_alias; added=1 }
  ' "$SHELL_RC" > "$temp_file" && mv "$temp_file" "$SHELL_RC"
}

echo "🔧 Creating Workwarrior profile: $PROFILE_NAME ($PROFILE_TYPE mode)"
echo

# --------------------------
# Setup .taskrc & Work List
# --------------------------
TASKRC_DEST="$BASE/.taskrc"
if [[ -f "$TASKRC_SRC" ]]; then
  cp "$TASKRC_SRC" "$TASKRC_DEST"
else
  touch "$TASKRC_DEST"
fi
echo "✓ Work List (.taskrc) created"

# --------------------------
# Setup jrnl.yaml & Notebook
# --------------------------
DEFAULT_NOTEBOOK="$JOURNALS/$PROFILE_NAME.txt"
echo "$(date '+%Y-%m-%d %H:%M'): Welcome to your $PROFILE_NAME Notebook!" > "$DEFAULT_NOTEBOOK"
cat > "$BASE/jrnl.yaml" << EOF
journals:
  default: $DEFAULT_NOTEBOOK
>>>>>>> b78e8d2 (updating for transfer to Lenovo)
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
<<<<<<< HEAD

echo "✓ Created default journal: $default_journal_file"
echo "✓ Created jrnl.yaml with default journal: $default_journal_file"

# --- Ledger ---
default_ledger_file="$LEDGERS/$PROFILE_NAME.journal"
cat > "$default_ledger_file" <<EOF
=======
echo "✓ Notebook (jrnl.yaml) created"

# --------------------------
# Setup Ledger & Workbook
# --------------------------
DEFAULT_WORKBOOK="$LEDGERS/$PROFILE_NAME.journal"
cat > "$DEFAULT_WORKBOOK" <<EOF
>>>>>>> b78e8d2 (updating for transfer to Lenovo)
; Hledger journal for $PROFILE_NAME
; Initialized on $(date '+%Y-%m-%d')
account assets:cash
account expenses:misc
account equity:opening-balances

$(date '+%Y-%m-%d') * Profile initialization
    assets:cash          \$0.00
    equity:opening-balances   \$0.00
EOF
<<<<<<< HEAD

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

# --- TODO Tool Alias Creation ---
T_ALIAS="alias t-$PROFILE_NAME='python3 \"$HOME/ww/tools/todo/t/t.py\" -t \"$TODO_DIR\"'"
add_alias_to_section "$T_ALIAS" "# -- Direct Aliases for TODO tool ---"
echo "✓ Created t-$PROFILE_NAME alias"
echo "✓ Created default TODO list: $DEFAULT_TODO_FILE"

# --- Install Timewarrior hook ---
if [[ -f "$HOOKSRC" ]]; then
  cp "$HOOKSRC" "$TASKDATA/hooks/on-modify.timewarrior"
  chmod +x "$TASKDATA/hooks/on-modify.timewarrior"
  echo "✓ Installed on-modify.timewarrior hook"
=======
echo "✓ Workbook (ledger) created"

# --------------------------
# Setup TODO & Plain List
# --------------------------
echo "✓ Plain List created at $DEFAULT_TODO_FILE"

# --------------------------
# Setup Time List (Timewarrior)
# --------------------------
if [[ -f "$HOOKSRC" ]]; then
  cp "$HOOKSRC" "$TASKDATA/hooks/on-modify.timewarrior"
  chmod +x "$TASKDATA/hooks/on-modify.timewarrior"
>>>>>>> b78e8d2 (updating for transfer to Lenovo)
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
<<<<<<< HEAD
  echo "✓ Created fallback timewarrior hook"
fi

# --- Add/Update use_task_profile and global t function in .bashrc ---
if ! grep -q 'function use_task_profile' "$SHELL_RC"; then
  cat >> "$SHELL_RC" <<'EOF'

# --- Workwarrior Core Functions ---

function j() {
  if [[ -z "$WORKWARRIOR_BASE" ]]; then
    echo "Error: No Workwarrior profile is currently active. Please use 'p-<profile-name>' first." >&2
    return 1
  fi
  local jrnl_config="$WORKWARRIOR_BASE/jrnl.yaml"
  if [[ ! -f "$jrnl_config" ]]; then
    echo "Error: jrnl.yaml not found for current profile at '$jrnl_config'." >&2
    return 1
  fi
  jrnl --config-file "$jrnl_config" "$@"
}

function l() {
  if [[ -z "$WORKWARRIOR_BASE" ]]; then
    echo "Error: No Workwarrior profile is currently active. Please use 'p-<profile-name>' first." >&2
    return 1
  fi
  local ledger_file="$WORKWARRIOR_BASE/ledgers/$(basename "$WORKWARRIOR_BASE").journal"
  if [[ ! -f "$ledger_file" ]]; then
    echo "Error: Default ledger file not found for current profile at '$ledger_file'." >&2
    return 1
  fi
  hledger -f "$ledger_file" "$@"
}

function t() {
  if [[ -z "$WORKWARRIOR_BASE" ]]; then
    echo "Error: No Workwarrior profile is currently active. Please use 'p-<profile-name>' first." >&2
    return 1
  fi

  if [[ -z "$WARRIOR_PROFILE" ]]; then
    echo "Error: Profile name (WARRIOR_PROFILE) not set." >&2
    return 1
  fi

  local todo_dir="$WORKWARRIOR_BASE/todo"
  local default_todo_file="$todo_dir/${WARRIOR_PROFILE}_default.todo"

  if [[ ! -f "$default_todo_file" ]]; then
    echo "Warning: Default TODO file not found for profile '$WARRIOR_PROFILE' at '$default_todo_file'. Creating empty file."
    mkdir -p "$todo_dir"
    touch "$default_todo_file"
  fi

  python3 "$HOME/ww/tools/todo/t/t.py" -t "$todo_dir" "$@"
}

=======
fi
echo "✓ Time List hook installed"

# --------------------------
# Aliases for Lists
# --------------------------
add_alias_to_section "alias Work='$TASKRC_DEST'" "# -- Lists ---"
add_alias_to_section "alias List='$DEFAULT_TODO_FILE'" "# -- Lists ---"
add_alias_to_section "alias Time='$TIMEWDB'" "# -- Lists ---"

# --------------------------
# Aliases for Books
# --------------------------
add_alias_to_section "alias Notebook='jrnl --config-file \"$BASE/jrnl.yaml\"'" "# -- Books ---"
add_alias_to_section "alias journal='jrnl --config-file \"$BASE/jrnl.yaml\"'" "# -- Books ---"
add_alias_to_section "alias Workbook='hledger -f \"$DEFAULT_WORKBOOK\"'" "# -- Books ---"
add_alias_to_section "alias ledger='hledger -f \"$DEFAULT_WORKBOOK\"'" "# -- Books ---"

# --------------------------
# Profile activation function
# --------------------------
if ! grep -q 'function use_task_profile' "$SHELL_RC"; then
  cat >> "$SHELL_RC" <<'EOF'

>>>>>>> b78e8d2 (updating for transfer to Lenovo)
function use_task_profile() {
  local profile="$1"
  if [[ -z "$profile" ]]; then
    echo "Usage: use_task_profile <profile-name>" >&2
    return 1
  fi

  local base="$HOME/ww/profiles/$profile"
  if [[ ! -d "$base" ]]; then
<<<<<<< HEAD
    echo "Error: Profile '$profile' not found at $base" >&2
=======
    echo "Error: Profile not found at $base" >&2
>>>>>>> b78e8d2 (updating for transfer to Lenovo)
    return 1
  fi

  export WARRIOR_PROFILE="$profile"
  export WORKWARRIOR_BASE="$base"
  export TASKRC="$base/.taskrc"
  export TASKDATA="$base/.task"
  export TIMEWARRIORDB="$base/.timewarrior"

<<<<<<< HEAD
  eval "$(declare -f j)"
  eval "$(declare -f l)"
  eval "$(declare -f t)"

  echo "Now using Workwarrior profile: $profile"
  echo "✓ Global 'j' command now writes to $profile's default journal"
  echo "✓ Global 'l' command now uses $profile's default ledger"
  echo "✓ Global 't' command now uses $profile's default TODO directory"
  echo "✓ Use 'task start <id>' to start tasks with timewarrior integration"
}
EOF
  echo "✓ Added core Workwarrior functions and global 't' function to $SHELL_RC"
=======
  echo "✓ Profile '$profile' activated. Lists and Books ready."
}
EOF
>>>>>>> b78e8d2 (updating for transfer to Lenovo)
fi

source "$SHELL_RC" > /dev/null 2>&1

echo
echo "✅ Profile '$PROFILE_NAME' setup complete!"
echo "📁 Location: $BASE"
<<<<<<< HEAD
echo "📝 Default Journal: $default_journal_file"
echo "💰 Ledgers: $PROFILE_NAME"
echo "🗂  TaskRC: $TASKRC_DEST"
echo "🗒  TODO: $DEFAULT_TODO_FILE"
echo
echo "👉 Run: source $SHELL_RC"
echo "👉 Then use: j-$PROFILE_NAME for direct journal access"
echo "👉 Or: p-$PROFILE_NAME or $PROFILE_NAME to activate profile (enables simple 'j', 'l' and 't' commands)"
echo "👉 Use: t-$PROFILE_NAME to run TODO tool inside this profile"
echo
=======
echo "📝 Notebook: $DEFAULT_NOTEBOOK"
echo "💰 Workbook: $DEFAULT_WORKBOOK"
echo "🗒 Plain List: $DEFAULT_TODO_FILE"
echo "⌛ Time List DB: $TIMEWDB"
echo
echo "👉 Aliases: Work, List, Time, Notebook, journal, Workbook, ledger"
echo "👉 Activate profile: use_task_profile $PROFILE_NAME"
>>>>>>> b78e8d2 (updating for transfer to Lenovo)
