#!/bin/bash
# Handler for journal service

template_file="$1"
answers_file="$2"

if [[ ! -f "$template_file" || ! -f "$answers_file" ]]; then
    echo "Error: Template or answers file not found" >&2
    exit 1
fi

echo "Handler: journal"
echo "Template: $template_file"
echo "Answers: $answers_file"
echo ""

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

# Write to JRNL default journal
echo -e "$entry" | jrnl

if [[ $? -eq 0 ]]; then
    echo "✓ Successfully wrote to JRNL default journal"
    exit 0
else
    echo "✗ Error writing to JRNL default journal" >&2
    exit 1
fi