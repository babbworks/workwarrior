#!/bin/bash
# --- Debug Script: debug_create_task_profile.sh ---
set -e

# Enable debug mode
set -x

PROFILE_NAME="$1"
if [[ -z "$PROFILE_NAME" ]]; then
  echo "Usage: $0 <profile-name>"
  exit 1
fi

echo "=== DEBUG: Starting profile creation for '$PROFILE_NAME' ==="

BASE="$HOME/ww/profiles/$PROFILE_NAME"
TASKDATA="$BASE/.task"
TIMEWDB="$BASE/.timewarrior"
JOURNALS="$BASE/journals"

echo "DEBUG: BASE = $BASE"
echo "DEBUG: TASKDATA = $TASKDATA"
echo "DEBUG: TIMEWDB = $TIMEWDB"
echo "DEBUG: JOURNALS = $JOURNALS"

# Check if source directories exist
echo "=== DEBUG: Checking source directories ==="
if [[ -d "$HOME/ww/services" ]]; then
  echo "✓ $HOME/ww/services exists"
  find "$HOME/ww/services" -type f -name "*taskrc*" -o -name "*timewarrior*" | head -5
else
  echo "✗ $HOME/ww/services does not exist"
fi

# Find source files with debug output
echo "=== DEBUG: Looking for source files ==="
HOOKSRC=$(find ~/ww/services/profile/ -name "on-modify.timewarrior" 2>/dev/null | head -n 1)
TASKRC=$(find ~/ww/services/profile/taskrc/default -name ".taskrc" 2>/dev/null | head -n 1)

echo "DEBUG: HOOKSRC = '$HOOKSRC'"
echo "DEBUG: TASKRC = '$TASKRC'"

if [[ -f "$HOOKSRC" ]]; then
  echo "✓ Found hook source: $HOOKSRC"
else
  echo "✗ Hook source not found"
fi

if [[ -f "$TASKRC" ]]; then
  echo "✓ Found taskrc source: $TASKRC"
else
  echo "✗ Taskrc source not found"
fi

SHELL_RC="$HOME/.bashrc"
echo "DEBUG: SHELL_RC = $SHELL_RC"

# Test directory creation
echo "=== DEBUG: Creating directories ==="
echo "Creating: $TASKDATA/hooks"
mkdir -p "$TASKDATA/hooks" && echo "✓ Created $TASKDATA/hooks" || echo "✗ Failed to create $TASKDATA/hooks"

echo "Creating: $TIMEWDB"
mkdir -p "$TIMEWDB" && echo "✓ Created $TIMEWDB" || echo "✗ Failed to create $TIMEWDB"

echo "Creating: $JOURNALS"
mkdir -p "$JOURNALS" && echo "✓ Created $JOURNALS" || echo "✗ Failed to create $JOURNALS"

# Test file operations
echo "=== DEBUG: Testing file operations ==="
echo "Creating journal file: $JOURNALS/$PROFILE_NAME.txt"
if touch "$JOURNALS/$PROFILE_NAME.txt"; then
  echo "✓ Created journal file"
else
  echo "✗ Failed to create journal file"
fi

# Test shell RC modifications
echo "=== DEBUG: Testing shell RC ==="
if [[ -f "$SHELL_RC" ]]; then
  echo "✓ Shell RC exists: $SHELL_RC"
  echo "Current size: $(wc -l < "$SHELL_RC") lines"
else
  echo "✗ Shell RC does not exist: $SHELL_RC"
  echo "Creating shell RC..."
  touch "$SHELL_RC"
fi

# Check write permissions
if [[ -w "$SHELL_RC" ]]; then
  echo "✓ Shell RC is writable"
else
  echo "✗ Shell RC is not writable"
fi

echo "=== DEBUG: Finished diagnostic checks ==="
echo "Profile directory structure:"
find "$BASE" -type f 2>/dev/null | sort || echo "No files created yet"

set +x
echo
echo "Debug complete. Check output above for any issues."