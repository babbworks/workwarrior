# Sword — Task Splitting

Native weapon (ww-native, no external binary).

## Usage

```
ww sword <task-id> -p <parts> [--interval <dur>] [--prefix <text>]
ww sword 5 -p 3                    # Split task 5 into 3 parts
ww sword 5 -p 4 --interval 2d     # 2-day intervals between parts
ww sword 12 -p 2 --prefix "Phase" # Custom prefix
```

## How Splitting Works

**Mechanical mode (default):** Sword creates N subtasks with descriptions
"Part N of: <original description>". Each subtask:
- Inherits the parent task's project and tags
- Gets a due date offset by N × interval from now
- Depends on the previous subtask (sequential chain)

The user then edits each subtask's description to be specific.

**AI mode (future, --ai flag):** Sword sends the task description to the
configured LLM and asks it to suggest N logical subtask descriptions.
The LLM breaks the work into meaningful phases rather than generic parts.
Requires: ollama running locally or OPENAI_API_KEY set.
Mechanism: same provider resolution as CMD AI (config/models.yaml).

## Task Card

TASK-EXT-SWORD-002 (complete)
