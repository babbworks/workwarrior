#!/bin/bash
# --- Script: create_task_profile.sh ---
set -e

PROFILE_NAME="$1"
if [[ -z "$PROFILE_NAME" ]]; then
  echo "Usage: $0 <profile-name>"
  exit 1
fi

BASE="$HOME/ww/profiles/$PROFILE_NAME"
TASKDATA="$BASE/.task"
TIMEWDB="$BASE/.timewarrior"
JOURNALS="$BASE/journals"  # Fixed: was undefined variable $journals

# Fixed: More robust path finding
HOOKSRC=$(find ~/ww/services/profile/ -name "on-modify.timewarrior" 2>/dev/null | head -n 1)
TASKRC=$(find ~/ww/services/profile/taskrc/default -name ".taskrc" 2>/dev/null | head -n 1)

SHELL_RC="$HOME/.bashrc"  # Or ~/.zshrc for Zsh users

# --- Create directories ---
echo "Creating directories..."
mkdir -p "$TASKDATA/hooks"
mkdir -p "$TIMEWDB"
mkdir -p "$JOURNALS"  # Fixed: was $journals (undefined)

# --- Install TaskRC File ---
if [[ -f "$TASKRC" ]]; then
  cp "$TASKRC" "$BASE/.taskrc"  # Fixed: proper destination
  echo "✓ Created .taskrc from $TASKRC"
else
  echo "⚠ Could not find default taskrc file in services/profile"
  echo "Creating basic .taskrc..."
  cat > "$BASE/.taskrc" << 'EOF'
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
EOF
  echo "✓ Created basic .taskrc"
fi

# --- Install Timewarrior hook ---
if [[ -f "$HOOKSRC" ]]; then
  cp "$HOOKSRC" "$TASKDATA/hooks/on-modify.timewarrior"
  chmod +x "$TASKDATA/hooks/on-modify.timewarrior"
  echo "✓ Installed on-modify.timewarrior hook"
else
  echo "⚠ Could not find on-modify.timewarrior hook"
  echo "Creating basic hook..."
  cat > "$TASKDATA/hooks/on-modify.timewarrior" << 'EOF'
#!/usr/bin/env python3
# Basic Timewarrior hook for task integration
import sys
import json
import subprocess
import os

def timewarrior(*args):
    return subprocess.call(['timew'] + list(args))

def main():
    original = None
    modified = None
    
    # Read input
    for line in sys.stdin:
        if line.strip() == '':
            break
        if original is None:
            original = json.loads(line)
        else:
            modified = json.loads(line)
    
    # Basic integration logic here
    print(json.dumps(modified))

if __name__ == '__main__':
    main()
EOF
  chmod +x "$TASKDATA/hooks/on-modify.timewarrior"
  echo "✓ Created basic timewarrior hook"
fi

# --- Install JRNL File ---
# Fixed: The line had strange characters ∫˚ and improper syntax
touch "$JOURNALS/$PROFILE_NAME.txt"
echo "✓ Created journal file: $JOURNALS/$PROFILE_NAME.txt"

# --- Create JRNL config ---
cat > "$BASE/jrnl.yaml" << EOF
journals:
  default: $JOURNALS/$PROFILE_NAME.txt
editor: nano
encrypt: false
tagsymbols: '@'
default_hour: 9
default_minute: 0
timeformat: "%Y-%m-%d %H:%M"
highlight: true
linewrap: 79
EOF
echo "✓ Created JRNL configuration"

# --- Add reusable function if not already present ---
if ! grep -q 'function use_task_profile' "$SHELL_RC"; then
  cat >> "$SHELL_RC" <<'EOF'

# Load a Taskwarrior + Timewarrior profile by name
function use_task_profile() {
  local profile="$1"
  if [[ -z "$profile" ]]; then
    echo "Usage: use_task_profile <profile-name>"
    return 1
  fi
  
  local profile_base="$HOME/ww/profiles/$profile"
  
  if [[ ! -d "$profile_base" ]]; then
    echo "Error: Profile '$profile' not found at $profile_base"
    return 1
  fi
  
  export WARRIOR_PROFILE="$profile"
  export TASKRC="$profile_base/.taskrc"
  export TASKDATA="$profile_base/.task"
  export TIMEWARRIORDB="$profile_base/.timewarrior"
  
  # Set up JRNL alias for this profile
  alias j="jrnl --config-file '$profile_base/jrnl.yaml'"
  
  echo "Now using Taskwarrior profile: $profile"
  echo "  TASKRC: $TASKRC"
  echo "  TASKDATA: $TASKDATA"
  echo "  TIMEWARRIORDB: $TIMEWARRIORDB"
  echo "  Journal: $profile_base/journals/$profile.txt"
  echo ""
  echo "Use 'j' for journal entries, 'task' for tasks, 'timew' for time tracking"
}

# Function to list available profiles
function list_task_profiles() {
  echo "Available profiles:"
  if [[ -d "$HOME/ww/profiles" ]]; then
    ls -1 "$HOME/ww/profiles" | while read profile; do
      if [[ -f "$HOME/ww/profiles/$profile/.taskrc" ]]; then
        echo "  $profile"
      fi
    done
  else
    echo "  No profiles found"
  fi
}

# Alias for convenience
alias lsp='list_task_profiles'
EOF
  echo "✓ Added use_task_profile() function to $SHELL_RC"
else
  echo "ℹ use_task_profile() function already exists in $SHELL_RC"
fi

# --- Insert alias under '# Workwarrior Profile Aliases' section ---
ALIAS_LINE="alias ${PROFILE_NAME}='use_task_profile $PROFILE_NAME'"

# Check if the section exists
if grep -q '^# Workwarrior Profile Aliases' "$SHELL_RC"; then
  if ! grep -Fxq "$ALIAS_LINE" "$SHELL_RC"; then
    # Fixed: sed syntax for different platforms
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS
      sed -i '' "/^# Workwarrior Profile Aliases/ a\\
$ALIAS_LINE
" "$SHELL_RC"
    else
      # Linux
      sed -i "/^# Workwarrior Profile Aliases/ a\\$ALIAS_LINE" "$SHELL_RC"
    fi
    echo "✓ Added alias under '# Workwarrior Profile Aliases'"
  else
    echo "ℹ Alias already exists in $SHELL_RC"
  fi
else
  # If the section doesn't exist, append at the end
  echo >> "$SHELL_RC"
  echo "# Workwarrior Profile Aliases" >> "$SHELL_RC"
  echo "$ALIAS_LINE" >> "$SHELL_RC"
  echo "✓ Created alias section and added alias"
fi

# --- Done ---
echo
echo "✅ Profile '$PROFILE_NAME' setup complete!"
echo "📁 Profile location: $BASE"
echo "📝 Journal: $JOURNALS/$PROFILE_NAME.txt"
echo "⚙️  JRNL config: $BASE/jrnl.yaml"
echo
echo "👉 Run: source $SHELL_RC"
echo "👉 Then use: $PROFILE_NAME"
echo "👉 Or use: use_task_profile $PROFILE_NAME"
echo
echo "Available commands after loading profile:"
echo "  j 'journal entry'  - Add journal entry"
echo "  task add 'task'    - Add task"
echo "  timew start 'work' - Start time tracking"
echo "  lsp                - List all profiles"