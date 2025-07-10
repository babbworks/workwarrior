#!/bin/bash
# JRNL Debug Script - Diagnose and fix journal entry issues

PROFILE_NAME="$1"
if [[ -z "$PROFILE_NAME" ]]; then
    echo "Usage: $0 <profile-name>"
    echo "Example: $0 work"
    exit 1
fi

BASE="$HOME/ww/profiles/$PROFILE_NAME"
JRNL_CONFIG="$BASE/jrnl.yaml"
JOURNAL_DIR="$BASE/journals"
JOURNAL_FILE="$JOURNAL_DIR/$PROFILE_NAME.txt"

echo "=== JRNL Debug for Profile: $PROFILE_NAME ==="
echo

# Check if profile exists
if [[ ! -d "$BASE" ]]; then
    echo "❌ Profile directory not found: $BASE"
    exit 1
fi

echo "✅ Profile directory exists: $BASE"

# Check JRNL config
echo
echo "--- JRNL Configuration ---"
if [[ -f "$JRNL_CONFIG" ]]; then
    echo "✅ JRNL config found: $JRNL_CONFIG"
    echo "Config contents:"
    cat "$JRNL_CONFIG"
else
    echo "❌ JRNL config not found: $JRNL_CONFIG"
fi

# Check journal file
echo
echo "--- Journal File ---"
if [[ -f "$JOURNAL_FILE" ]]; then
    echo "✅ Journal file exists: $JOURNAL_FILE"
    echo "File size: $(stat -f%z "$JOURNAL_FILE" 2>/dev/null || stat -c%s "$JOURNAL_FILE" 2>/dev/null || echo "unknown") bytes"
    echo "File contents:"
    echo "--- START OF FILE ---"
    cat "$JOURNAL_FILE"
    echo "--- END OF FILE ---"
else
    echo "❌ Journal file not found: $JOURNAL_FILE"
fi

# Test JRNL command
echo
echo "--- Testing JRNL Command ---"
echo "Testing: jrnl --config-file '$JRNL_CONFIG' --list"
if jrnl --config-file "$JRNL_CONFIG" --list 2>&1; then
    echo "✅ JRNL command works"
else
    echo "❌ JRNL command failed"
fi

# Test adding an entry
echo
echo "--- Testing Entry Addition ---"
echo "Adding test entry..."
if jrnl --config-file "$JRNL_CONFIG" "$(date): Test entry from debug script" 2>&1; then
    echo "✅ Test entry added successfully"
else
    echo "❌ Failed to add test entry"
fi

# Check file again after test entry
echo
echo "--- Journal File After Test Entry ---"
if [[ -f "$JOURNAL_FILE" ]]; then
    echo "File size: $(stat -f%z "$JOURNAL_FILE" 2>/dev/null || stat -c%s "$JOURNAL_FILE" 2>/dev/null || echo "unknown") bytes"
    echo "File contents:"
    echo "--- START OF FILE ---"
    cat "$JOURNAL_FILE"
    echo "--- END OF FILE ---"
else
    echo "❌ Journal file still not found after test entry"
fi

# Show JRNL version and default config
echo
echo "--- JRNL System Info ---"
echo "JRNL version:"
jrnl --version 2>&1 || echo "Could not get JRNL version"

echo
echo "JRNL default config location:"
python3 -c "
import os
print('XDG_CONFIG_HOME:', os.environ.get('XDG_CONFIG_HOME', 'not set'))
print('Default config would be at:', os.path.expanduser('~/.config/jrnl/jrnl.yaml'))
" 2>/dev/null || echo "Could not run Python check"

echo
echo "=== Debug Complete ==="
echo
echo "If the journal file is still empty, try these fixes:"
echo "1. Fix the config file (run the fix script below)"
echo "2. Use absolute paths instead of ~ in the config"
echo "3. Check JRNL permissions"
echo "4. Try creating a new profile with fixed config"