#!/bin/bash

# Usage: ./tw2gh.sh <task_id> <repo>
# Example: ./tw2gh.sh 42 user/repo

TASK_ID="$1"
REPO="$2"

if [[ -z "$TASK_ID" || -z "$REPO" ]]; then
  echo "Usage: $0 <task_id> <repo>"
  exit 1
fi

# Extract description (title) from Taskwarrior
TITLE=$(task "$TASK_ID" export | jq -r '.[0].description')

if [[ -z "$TITLE" ]]; then
  echo "Could not find a description for Taskwarrior task ID $TASK_ID"
  exit 2
fi

# Create GitHub issue using gh CLI
gh issue create --repo "$REPO" --title "$TITLE"

echo "GitHub issue created with title: $TITLE"

