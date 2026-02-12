#!/bin/bash
# Handler for task service - integrates with TaskWarrior

template_file="$1"
answers_file="$2"

if [[ ! -f "$template_file" || ! -f "$answers_file" ]]; then
    echo "Error: Template or answers file not found" >&2
    exit 1
fi

# Check if TaskWarrior is available
if ! command -v task &> /dev/null; then
    echo "Error: TaskWarrior (task) command not found" >&2
    exit 1
fi

echo "Handler: task"
echo "Template: $template_file"
echo ""

# Extract answers and create TaskWarrior task
task_data=$(python3 -c "
import json
import sys

try:
    with open('$answers_file', 'r') as f:
        data = json.load(f)

    with open('$template_file', 'r') as f:
        template = json.load(f)

    answers = data['answers']
    questions = {q['id']: q['text'] for q in template['questions']}

    # Build task description from first answer (usually the main task description)
    # and annotations from subsequent answers
    description = ''
    annotations = []
    tags = template.get('output_format', {}).get('tags', [])

    for i, (key, value) in enumerate(answers.items()):
        if i == 0:
            # First answer becomes the task description
            description = value
        else:
            # Subsequent answers become annotations
            question_text = questions.get(key, key)
            annotations.append(f'{question_text}: {value}')

    # Output: description|tag1,tag2|annotation1|annotation2|...
    output_parts = [description, ','.join(tags)] + annotations
    print('|'.join(output_parts))

except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
")

if [[ $? -ne 0 || -z "$task_data" ]]; then
    echo "Error: Failed to parse answers" >&2
    exit 1
fi

# Parse the output
IFS='|' read -ra parts <<< "$task_data"
description="${parts[0]}"
tags="${parts[1]}"

if [[ -z "$description" ]]; then
    echo "Error: No task description found in answers" >&2
    exit 1
fi

# Build task command
task_cmd="task add \"$description\""

# Add tags if present
if [[ -n "$tags" ]]; then
    IFS=',' read -ra tag_array <<< "$tags"
    for tag in "${tag_array[@]}"; do
        task_cmd="$task_cmd +$tag"
    done
fi

echo "Creating task: $description"

# Execute task add command
eval "$task_cmd"
task_result=$?

if [[ $task_result -ne 0 ]]; then
    echo "Error: Failed to create task" >&2
    exit 1
fi

# Get the ID of the newly created task (last task added)
new_task_id=$(task +LATEST ids 2>/dev/null | tail -1)

# Add annotations for additional answers
for ((i=2; i<${#parts[@]}; i++)); do
    annotation="${parts[i]}"
    if [[ -n "$annotation" && -n "$new_task_id" ]]; then
        task "$new_task_id" annotate "$annotation" 2>/dev/null
    fi
done

echo ""
echo "Task created successfully"
if [[ -n "$new_task_id" ]]; then
    echo "Task ID: $new_task_id"
    task "$new_task_id" info 2>/dev/null | head -20
fi

exit 0
