#!/bin/bash

# --- Script: create_task_profile.sh ---

set -e

PROFILE_NAME="$1"
if [[ -z "$PROFILE_NAME" ]]; then
  echo "Usage: $0 <profile-name>"
  exit 1
fi

BASE="$HOME/ww/functions/tasks/$PROFILE_NAME"
TASKRC="$BASE/.taskrc"
TASKDATA="$BASE/.task"
TIMEWDB="$BASE/.timewarrior"
HOOKSRC=$(find ~/ww/services/profile/ -name on-modify.timewarrior 2>/dev/null | head -n 1)

SHELL_RC="$HOME/.bashrc"  # Or ~/.zshrc for Zsh users

# --- Create directories ---
mkdir -p "$TASKDATA/hooks"
mkdir -p "$TIMEWDB"

# --- Generate .taskrc if not present ---
if [[ ! -f "$TASKRC" ]]; then
  cat > "$TASKRC" <<EOF
# Taskwarrior config for profile: $PROFILE_NAME
taskd=off
color=on
EOF
  echo "✓ Created $TASKRC"
fi

# --- Install Timewarrior hook ---
if [[ -f "$HOOKSRC" ]]; then
  cp "$HOOKSRC" "$TASKDATA/hooks/on-modify.timewarrior"
  chmod +x "$TASKDATA/hooks/on-modify.timewarrior"
  echo "✓ Installed on-modify.timewarrior hook"
else
  echo "⚠ Could not find on-modify.timewarrior in /usr/share"
fi

# --- Add reusable function if not already present ---
if ! grep -q 'function use_task_profile' "$SHELL_RC"; then
  cat >> "$SHELL_RC" <<'EOF'

# Load a Taskwarrior + Timewarrior profile by name
function use_task_profile() {
  local profile="\$1"
  export WARRIOR_PROFILE="\$profile"
  export TASKRC="\$HOME/tasks/\$profile/.taskrc"
  export TASKDATA="\$HOME/tasks/\$profile/.task"
  export TIMEWARRIORDB="\$HOME/tasks/\$profile/.timewarrior"
  echo "Now using Taskwarrior profile: \$profile"
}
EOF
  echo "✓ Added use_task_profile() to $SHELL_RC"
fi

# --- Insert alias under '# Per-profile aliases for quick use' section ---
ALIAS_LINE="alias ${PROFILE_NAME}task='use_task_profile $PROFILE_NAME'"

# Check if the section exists
if grep -q '^# Per-profile aliases for quick use' "$SHELL_RC"; then
  if ! grep -Fxq "$ALIAS_LINE" "$SHELL_RC"; then
    sed -i '' "/^# Per-profile aliases for quick use/ a\\
$ALIAS_LINE
" "$SHELL_RC"
    echo "✓ Added alias under '# Per-profile aliases for quick use'"
  else
    echo "ℹ Alias already exists in $SHELL_RC"
  fi
else
  # If the section doesn't exist, append at the end
  echo >> "$SHELL_RC"
  echo "# Per-profile aliases for quick use" >> "$SHELL_RC"
  echo "$ALIAS_LINE" >> "$SHELL_RC"
  echo "✓ Created alias section and added alias"
fi

# --- Done ---
echo
echo "✅ Profile '$PROFILE_NAME' setup complete!"
echo "👉 Run: source $SHELL_RC"
echo "👉 Then use: ${PROFILE_NAME} task"