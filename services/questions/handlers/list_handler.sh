#!/bin/bash
# Handler for list service - creates simple list items
# Stores list items in a profile-specific list.txt file

template_file="$1"
answers_file="$2"

if [[ ! -f "$template_file" || ! -f "$answers_file" ]]; then
    echo "Error: Template or answers file not found" >&2
    exit 1
fi

# Check if profile is active
if [[ -z "$WORKWARRIOR_BASE" ]]; then
    echo "Error: No Workwarrior profile active" >&2
    exit 1
fi

echo "Handler: list"
echo "Template: $template_file"
echo ""

# List file location
list_file="$WORKWARRIOR_BASE/list.txt"
done_file="$WORKWARRIOR_BASE/done.txt"

# Create list file if it doesn't exist
if [[ ! -f "$list_file" ]]; then
    touch "$list_file"
    echo "Created list file: $list_file"
fi

# Extract answers and create list entry
list_data=$(python3 -c "
import json
import sys
from datetime import datetime

try:
    with open('$answers_file', 'r') as f:
        data = json.load(f)

    with open('$template_file', 'r') as f:
        template = json.load(f)

    answers = data['answers']
    questions = {q['id']: q['text'] for q in template['questions']}
    tags = template.get('output_format', {}).get('tags', [])

    # Build list entry in list.txt format
    # Format: (priority) creation-date description +project @context

    list_text = ''
    priority = ''
    project = ''
    context = ''
    due_date = ''

    for key, value in answers.items():
        question_text = questions.get(key, '').lower()

        if 'priority' in question_text:
            # Map to A, B, C priority
            value_upper = value.upper().strip()
            if value_upper in ['A', 'B', 'C', 'D', 'E']:
                priority = f'({value_upper}) '
            elif value_upper in ['HIGH', 'H', '1']:
                priority = '(A) '
            elif value_upper in ['MEDIUM', 'MED', 'M', '2']:
                priority = '(B) '
            elif value_upper in ['LOW', 'L', '3']:
                priority = '(C) '
        elif 'project' in question_text:
            project = f' +{value.replace(\" \", \"_\")}'
        elif 'context' in question_text or 'where' in question_text:
            context = f' @{value.replace(\" \", \"_\")}'
        elif 'due' in question_text or 'deadline' in question_text:
            due_date = f' due:{value}'
        elif not list_text:
            # First non-metadata answer is the list description
            list_text = value
        else:
            # Append additional info to description
            list_text += f' [{questions.get(key, key)}: {value}]'

    # Build final list entry
    creation_date = datetime.now().strftime('%Y-%m-%d')

    # Add tags as projects
    for tag in tags:
        if not project or tag not in project:
            project += f' +{tag}'

    entry = f'{priority}{creation_date} {list_text}{project}{context}{due_date}'
    print(entry.strip())

except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
")

if [[ $? -ne 0 || -z "$list_data" ]]; then
    echo "Error: Failed to parse answers" >&2
    exit 1
fi

echo "List entry: $list_data"
echo ""

# Append to list file
echo "$list_data" >> "$list_file"

if [[ $? -eq 0 ]]; then
    echo "List item added successfully to: $list_file"
    echo ""
    echo "Current list:"
    echo "=============="
    cat -n "$list_file" | tail -10
    exit 0
else
    echo "Error: Failed to write list entry" >&2
    exit 1
fi
