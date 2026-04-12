# Plan: Heuristic Evolution System

## Concept

The CMD service processes natural language through two routes:
1. **AI route** — sends to LLM (ollama/openai), gets commands back
2. **Heuristic route** — pattern-matches keywords to commands directly

The goal: gradually reduce AI dependency by learning from AI responses and
encoding successful patterns into the heuristic engine.

## Architecture

```
User input → Heuristic engine → Match found? → Execute directly (⚙)
                                  ↓ No match
                              AI engine → Get commands → Execute (⚡)
                                  ↓
                              Log: {input, ai_commands, results, success}
                                  ↓
                              Digest → New heuristic rules
```

## Phase 1: Logging (current)

Already implemented:
- CMD log records every command with: input, route (ai/heuristic), commands generated,
  results, success/failure, timestamp, profile
- Log stored in `services/cmd/cmd.log` as JSONL

## Phase 2: Pattern Extraction

Build a digest process that reads the CMD log and extracts patterns:

```
Input: "create a task to review the budget due friday"
AI output: "task add review the budget due:friday"
Pattern: "create a task to {desc} due {date}" → "task add {desc} due:{date}"
```

The digest produces a rules file: `config/cmd-heuristics.yaml`

```yaml
rules:
  - pattern: "create a task (to |for )?(.+)"
    action: "task add $2"
    confidence: 0.9
    source: ai-digest
    count: 5

  - pattern: "start tracking (time on )?(.+)"
    action: "timew start $2"
    confidence: 0.95
    source: ai-digest
    count: 12
```

## Phase 3: Heuristic Engine Enhancement

The server's heuristic parser reads `config/cmd-heuristics.yaml` at startup.
Before calling the AI, it checks the rules:

1. Match input against each rule's regex pattern
2. If match with confidence > threshold → execute directly (⚙)
3. If no match → call AI (⚡)
4. Log the result either way

## Phase 4: User-Editable Rules

The CTRL panel exposes the heuristics:
- View all rules with match counts and confidence
- Edit rules (adjust patterns, actions)
- Add manual rules
- Delete rules that produce bad results
- Set confidence threshold for auto-execution

The CLI equivalent: `ww ctrl heuristics list/add/edit/delete`

## Phase 5: Continuous Learning

A background process (or manual `ww ctrl heuristics digest`) that:
1. Reads the CMD log since last digest
2. Groups successful AI responses by pattern similarity
3. Extracts new rules from repeated patterns
4. Merges with existing rules (increment count, adjust confidence)
5. Writes updated `config/cmd-heuristics.yaml`

Over time, the heuristic engine handles more and more requests directly,
and the AI is only called for novel or ambiguous inputs.

## Metrics

Track in the CMD log:
- `route: ai` vs `route: heuristic` ratio over time
- Average response time per route
- Success rate per route
- Most common patterns (candidates for new rules)

The CTRL panel shows these metrics as a dashboard.

## Implementation Priority

1. **Now:** Route indicator in UI (done)
2. **Next:** `config/cmd-heuristics.yaml` with initial rules from current heuristic code
3. **Then:** Digest command that reads CMD log and proposes new rules
4. **Later:** CTRL panel for rule management
5. **Future:** Automatic digest on schedule

## Key Design Decisions

- Rules are YAML, not code — editable by users without programming
- Confidence threshold prevents low-quality rules from auto-executing
- AI is always available as fallback — heuristics reduce load, not replace
- The system is transparent: user always sees which route was taken
- Rules have provenance: `source: ai-digest` vs `source: manual`
