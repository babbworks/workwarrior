#!/bin/bash
# Handler for journal service to write to the default journal of the active Workwarrior profile

template_file="$1"
answers_file="$2"

if [[ ! -f "$template_file" || ! -f "$answers_file" ]]; then
    echo "Error: Template or answers file not found" >&2
    exit 1
fi

# Check if Workwarrior profile is active
if [[ -z "$WORKWARRIOR_BASE" ]]; then
    echo "Error: No Workwarrior profile is currently active. Please activate one with 'p-<profile-name>'." >&2
    exit 1
fi

echo "Handler: journal"
echo "Template: $template_file"
echo "Answers: $answers_file"
echo ""

# Determine the default journal for the active profile
# Check for profile-specific JRNL config (e.g., $WORKWARRIOR_BASE/config/jrnl_config)
jrnl_config="$WORKWARRIOR_BASE/config/jrnl_config"
default_journal=""

if [[ -f "$jrnl_config" ]]; then
    # Extract the default journal from the profile's JRNL config
    default_journal=$(python3 -c "
import json
try:
    with open('$jrnl_config', 'r') as f:
        config = json.load(f)
    print(config.get('default', ''))
except Exception:
    print('')
")
fi

# Fallback to global JRNL config if profile-specific config is missing or doesn't specify a default
if [[ -z "$default_journal" && -f "$HOME/.jrnl_config" ]]; then
    default_journal=$(python3 -c "
import json
try:
    with open('$HOME/.jrnl_config', 'r') as f:
        config = json.load(f)
    print(config.get('default', ''))
except Exception:
    print('')
")
fi

# If no default journal is found, use a fallback journal name
if [[ -z "$default_journal" ]]; then
    default_journal="default"
    echo "Warning: No default journal found in profile or global JRNL config. Using journal 'default'." >&2
fi

# Extract answers and format for JRNL
entry=$(python3 -c "
import json
from datetime import datetime
with open('$answers_file', 'r') as f:
    data = json.load(f)

# Get timestamp for JRNL entry
timestamp = datetime.now().strftime('%Y-%m-%d %H:%M')

# Format answers as a journal entry
entry = f'{timestamp} {data['template'].split('/')[-1].replace('.json', '')}\n'
for key, value in data['answers'].items():
    entry += f'{key}: {value}\n'

print(entry)
")

if [[ -z "$entry" ]]; then
    echo "Error: Failed to format journal entry" >&2
    exit 1
fi

# Write to the profile's default JRNL journal
echo -e "$entry" | jrnl "$default_journal"

if [[ $? -eq 0 ]]; then
    echo "✓ Successfully wrote to JRNL journal '$default_journal'"
    exit 0
else
    echo "✗ Error writing to JRNL journal '$default_journal'" >&2
    exit 1
fi