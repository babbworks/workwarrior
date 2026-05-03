#!/bin/bash
# Handler for time service - integrates with TimeWarrior

template_file="$1"
answers_file="$2"

if [[ ! -f "$template_file" || ! -f "$answers_file" ]]; then
    echo "Error: Template or answers file not found" >&2
    exit 1
fi

# Check if TimeWarrior is available
if ! command -v timew &> /dev/null; then
    echo "Error: TimeWarrior (timew) command not found" >&2
    exit 1
fi

echo "Handler: time"
echo "Template: $template_file"
echo ""

# Extract answers and create TimeWarrior entry
time_data=$(python3 -c "
import json
import sys

try:
    with open('$answers_file', 'r') as f:
        data = json.load(f)

    with open('$template_file', 'r') as f:
        template = json.load(f)

    answers = data['answers']
    questions = {q['id']: q['text'] for q in template['questions']}
    tags = template.get('output_format', {}).get('tags', [])

    # Build time tracking entry
    # First answer is typically the activity/task description
    # Look for duration-related questions
    activity = ''
    duration = ''
    extra_tags = []

    for key, value in answers.items():
        question_text = questions.get(key, '').lower()

        if not activity and value:
            # First non-empty answer becomes activity
            activity = value
        elif 'duration' in question_text or 'time' in question_text or 'minutes' in question_text or 'hours' in question_text:
            duration = value
        elif 'tag' in question_text:
            extra_tags.extend(value.split())
        else:
            # Add other answers as tags (cleaned)
            clean_value = value.replace(' ', '_')[:20]
            if clean_value:
                extra_tags.append(clean_value)

    # Combine all tags
    all_tags = tags + extra_tags

    # Output: activity|duration|tag1 tag2 tag3
    print(f\"{activity}|{duration}|{' '.join(all_tags)}\")

except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
")

if [[ $? -ne 0 || -z "$time_data" ]]; then
    echo "Error: Failed to parse answers" >&2
    exit 1
fi

# Parse the output
IFS='|' read -r activity duration tags <<< "$time_data"

if [[ -z "$activity" ]]; then
    echo "Error: No activity description found in answers" >&2
    exit 1
fi

echo "Activity: $activity"
echo "Tags: $tags"

# Determine action: track time or start tracking
if [[ -n "$duration" ]]; then
    # If duration specified, track historical time
    echo "Duration: $duration"

    # Parse duration and track
    # Supports formats like "30m", "1h", "1h30m", "90" (minutes)
    if [[ "$duration" =~ ^([0-9]+)$ ]]; then
        # Just a number, assume minutes
        timew track "${duration}min" ago - now "$activity" $tags
    elif [[ "$duration" =~ ^([0-9]+)m$ ]]; then
        # Minutes format
        timew track "${duration}" ago - now "$activity" $tags
    elif [[ "$duration" =~ ^([0-9]+)h$ ]]; then
        # Hours format
        timew track "${duration}" ago - now "$activity" $tags
    else
        # Try to use as-is
        timew track "$duration" ago - now "$activity" $tags
    fi
    result=$?
else
    # No duration, start tracking now
    echo "Starting time tracking..."
    timew start "$activity" $tags
    result=$?
fi

if [[ $result -eq 0 ]]; then
    echo ""
    echo "Time tracking updated successfully"
    echo ""
    echo "Current tracking status:"
    timew summary :day
    exit 0
else
    echo "Error: TimeWarrior command failed" >&2
    exit 1
fi
