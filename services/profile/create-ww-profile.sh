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

  # Check if the alias already exists
  if grep -Fxq "$alias_line" "$SHELL_RC"; then
    return 0
  fi

  # Check if section marker exists
  if ! grep -Fxq "$section_marker" "$SHELL_RC"; then
    echo "" >> "$SHELL_RC"
    echo "$section_marker" >> "$SHELL_RC"
  fi

  # Add alias after the section marker using awk
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

mkdir -p "$TASKDATA/hooks" "$TIMEWDB" "$JOURNALS" "$LEDGERS"

# --- Customization Prompts ---
taskrc_custom_path=""; taskrc_source=""
jrnl_custom_path=""; jrnl_source=""
ledger_custom_path=""; ledger_source=""

echo
read -p "Would you like to customize this profile by adopting an existing TaskRC, jrnl.yaml, or hledger accounts? (y/N): " customize
if [[ "$customize" =~ ^[Yy] ]]; then
  # --- TASKRC SELECTION ---
  echo
  echo "Available profiles for TaskRC:"
  profiles=("$PROFILE_NAME")
  while IFS= read -r line; do
    [[ "$line" == "$PROFILE_NAME" ]] && continue
    profiles+=("$line")
  done < <(list_profiles)
  for i in "${!profiles[@]}"; do
    printf "   %d. %s\n" $((i+1)) "${profiles[$i]}"
  done
  read -p "Copy TaskRC from which profile? (number/name, or type 'add <path>', Enter for default): " taskrc_input
  if [[ "$taskrc_input" =~ ^[0-9]+$ ]]; then
    idx=$((taskrc_input-1))
    if (( idx >= 0 && idx < ${#profiles[@]} )); then
      taskrc_source="${profiles[$idx]}"
    fi
  elif [[ "$taskrc_input" =~ ^add[[:space:]]+(.+) ]]; then
    taskrc_custom_path="${BASH_REMATCH[1]}"
  elif [[ -n "$taskrc_input" ]]; then
    taskrc_source="$taskrc_input"
  fi

  # --- JRNL YAML SELECTION ---
  echo
  echo "Available profiles for jrnl.yaml:"
  for i in "${!profiles[@]}"; do
    printf "   %d. %s\n" $((i+1)) "${profiles[$i]}"
  done
  read -p "Copy jrnl.yaml from which profile? (number/name, or type 'add <path>', Enter for default): " jrnl_input
  if [[ "$jrnl_input" =~ ^[0-9]+$ ]]; then
    idx=$((jrnl_input-1))
    if (( idx >= 0 && idx < ${#profiles[@]} )); then
      jrnl_source="${profiles[$idx]}"
    fi
  elif [[ "$jrnl_input" =~ ^add[[:space:]]+(.+) ]]; then
    jrnl_custom_path="${BASH_REMATCH[1]}"
  elif [[ -n "$jrnl_input" ]]; then
    jrnl_source="$jrnl_input"
  fi

  # --- LEDGER ACCOUNTS SELECTION ---
  echo
  echo "Available profiles for hledger accounts:"
  for i in "${!profiles[@]}"; do
    printf "   %d. %s\n" $((i+1)) "${profiles[$i]}"
  done
  read -p "Copy hledger journal from which profile? (number/name, or type 'add <path>', Enter for default): " ledger_input
  if [[ "$ledger_input" =~ ^[0-9]+$ ]]; then
    idx=$((ledger_input-1))
    if (( idx >= 0 && idx < ${#profiles[@]} )); then
      ledger_source="${profiles[$idx]}"
    fi
  elif [[ "$ledger_input" =~ ^add[[:space:]]+(.+) ]]; then
    ledger_custom_path="${BASH_REMATCH[1]}"
  elif [[ -n "$ledger_input" ]]; then
    ledger_source="$ledger_input"
  fi
fi

# --- .taskrc Creation ---
TASKRC_DEST="$BASE/.taskrc"
if [[ -n "$taskrc_custom_path" && -f "$taskrc_custom_path" ]]; then
  cp "$taskrc_custom_path" "$TASKRC_DEST"
  echo "✓ Copied .taskrc from custom file: $taskrc_custom_path"
elif [[ -n "$taskrc_source" && -f "$HOME/ww/profiles/$taskrc_source/.taskrc" ]]; then
  cp "$HOME/ww/profiles/$taskrc_source/.taskrc" "$TASKRC_DEST"
  echo "✓ Copied .taskrc from profile: $taskrc_source"
elif [[ -f "$TASKRC_SRC" ]]; then
  cp "$TASKRC_SRC" "$TASKRC_DEST"
  echo "✓ Copied .taskrc from default template: $TASKRC_SRC"
else
  cat > "$TASKRC_DEST" <<'EOF'
# Basic TaskWarrior configuration
data.location=~/.task
report.next.columns=id,start.age,entry.age,depends,priority,project,tag,recur,scheduled.countdown,due.relative,until.remaining,description,urgency
report.next.description=Next tasks
report.next.labels=ID,Active,Age,Deps,P,Project,Tag,Recur,S,Due,Until,Description,Urg
uda.priority.values=H,M,,L
urgency.user.project.Inbox.coefficient=100.0
urgency.user.priority.H.coefficient=6.0
urgency.user.priority.M.coefficient=3.9
urgency.user.priority.L.coefficient=1.8
verbose=blank,footnote,label,new-id,affected,edit,special,project,sync,unwait
EOF
  echo "✓ Created fallback .taskrc at $TASKRC_DEST"
fi

# Ensure .taskrc points to the correct data location and has timewarrior hook enabled
awk -v old_line_start="data.location=" -v new_data_path="$TASKDATA" '
BEGIN {FS=OFS=""}
{
    if ($0 ~ "^" old_line_start) {
        print old_line_start new_data_path
    } else {
        print $0
    }
}' "$TASKRC_DEST" > "$TASKRC_DEST.tmp" && mv "$TASKRC_DEST.tmp" "$TASKRC_DEST"

# Ensure hooks.location is correctly set
HOOKS_LOCATION="$TASKDATA/hooks" # Define the correct hooks path
awk -v old_line_start="hooks.location=" -v new_hooks_path="$HOOKS_LOCATION" '
BEGIN {FS=OFS=""}
{
    if ($0 ~ "^" old_line_start) {
        print old_line_start new_hooks_path
    } else {
        print $0
    }
}' "$TASKRC_DEST" > "$TASKRC_DEST.tmp" && mv "$TASKRC_DEST.tmp" "$TASKRC_DEST"

if ! grep -q "hooks=" "$TASKRC_DEST"; then
  echo "hooks=1" >> "$TASKRC_DEST"
fi

# --- jrnl.yaml Creation ---
declare -A journal_files
journal_names=()

default_journal_name="default"
default_journal_file="$JOURNALS/$PROFILE_NAME.txt"

if [[ -n "$jrnl_custom_path" && -f "$jrnl_custom_path" ]]; then
  cp "$jrnl_custom_path" "$default_journal_file"
  echo "✓ Copied journal from custom file: $jrnl_custom_path"
elif [[ -n "$jrnl_source" && -f "$HOME/ww/profiles/$jrnl_source/journals/$jrnl_source.txt" ]]; then
  cp "$HOME/ww/profiles/$jrnl_source/journals/$jrnl_source.txt" "$default_journal_file"
  echo "✓ Copied journal from profile: $jrnl_source"
else
  echo "$(date '+%Y-%m-%d %H:%M'): Welcome to your $PROFILE_NAME journal!" > "$default_journal_file"
  echo "✓ Created default journal: $default_journal_file"
fi

journal_files["$default_journal_name"]="$default_journal_file"
journal_names+=("$default_journal_name")

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

echo "✓ Created jrnl.yaml with default journal: $default_journal_file"

# --- Journal Aliases Creation ---
MAIN_J_ALIAS="alias j-$PROFILE_NAME='jrnl --config-file \"$BASE/jrnl.yaml\"'"
add_alias_to_section "$MAIN_J_ALIAS" "# -- Direct Alias for Journals ---"
echo "✓ Created main journal alias: j-$PROFILE_NAME"

# --- Ledgers ---
declare -A ledger_files
ledger_names=()
default_ledger_name="$PROFILE_NAME"
default_ledger_file="$LEDGERS/$default_ledger_name.journal"
if [[ -n "$ledger_custom_path" && -f "$ledger_custom_path" ]]; then
  cp "$ledger_custom_path" "$default_ledger_file"
  echo "✓ Copied ledger from custom file: $ledger_custom_path"
elif [[ -n "$ledger_source" && -f "$HOME/ww/profiles/$ledger_source/ledgers/$ledger_source.journal" ]]; then
  cp "$HOME/ww/profiles/$ledger_source/ledgers/$ledger_source.journal" "$default_ledger_file"
  echo "✓ Copied ledger from profile: $ledger_source"
else
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
fi
ledger_files["$default_ledger_name"]="$default_ledger_file"
ledger_names+=("$default_ledger_name")

cat > "$BASE/ledgers.yaml" << EOF
ledgers:
EOF
for ln in "${ledger_names[@]}"; do
  echo "   $ln: ${ledger_files[$ln]}" >> "$BASE/ledgers.yaml"
done

# --- Ledger Aliases Creation ---
for ln in "${ledger_names[@]}"; do
  L_ALIAS="alias l-$ln='hledger -f \"${ledger_files[$ln]}\"'"
  add_alias_to_section "$L_ALIAS" "# -- Direct Aliases for Hledger ---"
  echo "✓ Created ledger alias: l-$ln"

  if [[ "$ln" != "$PROFILE_NAME" ]]; then
    L_ALIAS_LONG="alias l-$PROFILE_NAME-$ln='hledger -f \"${ledger_files[$ln]}\"'"
    add_alias_to_section "$L_ALIAS_LONG" "# -- Direct Aliases for Hledger ---"
    echo "✓ Created ledger alias: l-$PROFILE_NAME-$ln"
  fi
done

# --- Profile Aliases Creation ---
P_ALIAS="alias p-$PROFILE_NAME='use_task_profile $PROFILE_NAME'"
MAIN_ALIAS="alias $PROFILE_NAME='use_task_profile $PROFILE_NAME'"
add_alias_to_section "$P_ALIAS" "# -- Workwarrior Profile Aliases ---"
add_alias_to_section "$MAIN_ALIAS" "# -- Workwarrior Profile Aliases ---"
echo "✓ Created profile aliases: p-$PROFILE_NAME and $PROFILE_NAME"

# --- Install Timewarrior hook (unchanged) ---
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

# --- Add/Update use_task_profile function in .bashrc ---
if ! grep -q 'function use_task_profile' "$SHELL_RC"; then
  cat >> "$SHELL_RC" <<'EOF'

# --- Workwarrior Core Functions ---

# Global 'j' function for journaling
function j() {
  # Use WORKWARRIOR_BASE directly, which is set by use_task_profile
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

# Global 'hl' function for hledger
function l() {
  # Use WORKWARRIOR_BASE directly, which is set by use_task_profile
  if [[ -z "$WORKWARRIOR_BASE" ]]; then
    echo "Error: No Workwarrior profile is currently active. Please use 'p-<profile-name>' first." >&2
    return 1
  fi
  local ledger_file="$WORKWARRIOR_BASE/ledgers/$(basename "$WORKWARRIOR_BASE").journal" # Derive ledger name from base
  if [[ ! -f "$ledger_file" ]]; then
    echo "Error: Default ledger file not found for current profile at '$ledger_file'." >&2
    return 1
  fi
  hledger -f "$ledger_file" "$@"
}

# Load a Taskwarrior + Timewarrior + Hledger profile
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

  # Set ALL necessary environment variables for the current session
  export WARRIOR_PROFILE="$profile"
  export WORKWARRIOR_BASE="$base" # NEW: Export the base path directly for j and hl
  export TASKRC="$base/.taskrc"
  export TASKDATA="$base/.task"
  export TIMEWARRIORDB="$base/.timewarrior"

  # These 'eval' lines are still useful to ensure the *function definitions*
  # are refreshed in the current shell, but j/hl now rely directly on exported vars.
  eval "$(declare -f j)"
  eval "$(declare -f hl)"

  echo "Now using Workwarrior profile: $profile"
  echo "✓ Global 'j' command now writes to $profile's default journal"
  echo "✓ Global 'hl' command now uses $profile's default ledger"
  echo "✓ Use 'task start <id>' to start tasks with timewarrior integration"
}
EOF
  echo "✓ Added core Workwarrior functions to $SHELL_RC"
fi

# Ensure the functions are loaded in the current shell session
source "$SHELL_RC" > /dev/null 2>&1

echo
echo "✅ Profile '$PROFILE_NAME' setup complete!"
echo "📁 Location: $BASE"
echo "📝 Default Journal: $default_journal_file"
echo "💰 Ledgers: ${ledger_names[*]}"
echo "🗂  TaskRC: $TASKRC_DEST"
echo
echo "👉 Run: source $SHELL_RC"
echo "👉 Then use: j-$PROFILE_NAME for direct journal access"
echo "👉 Or: p-$PROFILE_NAME or $PROFILE_NAME to activate profile (enables simple 'j' and 'hl' commands)"
echo