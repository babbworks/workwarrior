# Heuristic Engine

The CMD service translates natural language into tool commands. It tries 627 compiled regex rules first — no network, no latency, no LLM. If no rule matches, it optionally falls back to a local LLM (ollama) or a remote provider.

## How It Works

Every natural language input goes through this pipeline:

1. **Compound split** — if the input contains "and", "then", "also", or "plus", it's split into segments
2. **Heuristic match** — each segment is tested against 627 regex rules, highest confidence wins
3. **AI fallback** — if no rule matches above the confidence threshold (0.8), the input goes to the configured LLM
4. **Execution** — matched commands are executed against the active profile's tools

## What Works Without AI

```
"add a task to review the budget"              → task add review the budget
"create task deploy server due friday"         → task add deploy server due:friday
"please make a high priority task for the bug" → task add the bug priority:H
"start tracking time on code review"           → timew start code review
"stop tracking"                                → timew stop
"show my profiles"                             → profile list
"list all journals"                            → journal list
"backup profile work"                          → profile backup work
"can you show me the models"                   → model list
```

Compound commands:
```
"add task fix login and annotate it with       → task add fix login
 check mobile layout"                            + task annotate LAST check mobile layout
"create task review and start tracking time"   → task add review + timew start review
"finish task 5 and stop tracking"              → task 5 done + timew stop
```

## Coverage

627 rules across 19 domains: task, time, journal, ledger, profile, group, model, ctrl, service, issues, find, schedule, gun, next, mcp, browser, extensions, custom, shortcut.

Each command gets up to 6 phrasing variations:
- **Passthrough** (confidence 1.0): `task add groceries`
- **Imperative** (0.95): `add a task for groceries`
- **Declarative** (0.90): `I need a task for groceries`
- **Interrogative** (0.90): `can you create a task for groceries`
- **Shorthand** (0.90): `task: groceries due friday`
- **Verbose** (0.85): `I would like to create a new task called groceries`

Date expressions are mapped automatically: "tomorrow", "next week", "friday", "end of month", "in 3 days" → `due:tomorrow`, `due:1w`, `due:friday`, `due:eom`, `due:3d`.

## Recompiling Rules

The compiler scans all command sources, generates patterns, validates against a synthetic corpus, resolves conflicts, fills coverage gaps, and writes the output:

```bash
ww compile-heuristics              # Standard run
ww compile-heuristics --verbose    # Every rule with test results
ww compile-heuristics --digest     # Also analyze CMD log for AI translations
```

The compiler reads: `system/config/command-syntax.yaml`, `bin/ww` case branches, `config/shortcuts.yaml`, and optionally `services/cmd/cmd.log`.

## Self-Improvement

Every CMD submission is logged to `services/cmd/cmd.log` as JSONL with the route (heuristic or AI), input, output, and success status. Running `ww compile-heuristics --digest` reads this log and converts successful AI translations into new heuristic rules. Over time, more requests are handled by heuristics, reducing AI dependency.

## AI Configuration

```yaml
# config/ai.yaml
mode: local-only          # off | local-only | local+remote
preferred_provider: ollama
access_points:
  cmd_ai: true
```

Per-profile override via `profiles/<name>/ai.yaml`. Controls available via `ww ctrl ai-on/off/status` and the browser CTRL panel.
