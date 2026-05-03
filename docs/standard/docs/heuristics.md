---
layout: doc
title: Heuristic Engine
eyebrow: Documentation
description: 627 compiled regex rules across 19 domains. Natural language commands without AI.
permalink: /docs/heuristics
doc_section: features
doc_order: 2
---

The heuristic engine translates natural language into tool commands using compiled regex rules. 627 rules across 19 command domains. No network, no latency, no API key.

## How It Works

```
Input
  → Compound split (if "and"/"then"/"also"/"plus")
  → Each segment: test against 627 rules
  → Highest confidence match above 0.8 wins
  → No match? → AI fallback if configured
  → AI not configured? → Clear error
```

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
```

Compound commands:
```
"add task fix login and annotate it with       → task add fix login
 check mobile layout"                            task annotate LAST check mobile layout

"create task review and start tracking time"   → task add review
                                                 timew start review

"finish task 5 and stop tracking"              → task 5 done
                                                 timew stop
```

If any segment fails to match, the entire compound goes to AI.

## Phrasing Variations

Six variations per command, with different confidence scores:

| Variation | Confidence | Example |
|-----------|-----------|---------|
| Passthrough | 1.0 | `task add review budget` |
| Imperative | 0.95 | `add a task to review the budget` |
| Declarative | 0.90 | `I need a task for reviewing the budget` |
| Interrogative | 0.90 | `can you create a task to review the budget` |
| Shorthand | 0.90 | `task: review budget due friday` |
| Verbose | 0.85 | `I would like to add a new task for reviewing the budget` |

## Date Expressions

| Input | Output |
|-------|--------|
| "tomorrow" | `due:tomorrow` |
| "next week" | `due:1w` |
| "friday" | `due:friday` |
| "end of month" | `due:eom` |
| "in 3 days" | `due:3d` |
| "next monday" | `due:monday` |

## Command Domains

Coverage across 19 domains: task · time · journal · ledger · profile · group · model · ctrl · service · issues · find · schedule · gun · next · mcp · browser · extensions · custom · shortcut

## Recompiling Rules

```bash
ww compile-heuristics              # Standard run
ww compile-heuristics --verbose    # Every rule with test results
ww compile-heuristics --digest     # + CMD log analysis
```

The compiler scans `bin/ww` case branches, `config/shortcuts.yaml`, and `config/command-syntax.yaml`. Generates patterns, validates against a synthetic corpus, resolves conflicts, fills coverage gaps.

## Self-Improvement

Every CMD submission is logged to `services/cmd/cmd.log` as JSONL: `{input, route, output, success}`.

`--digest` reads this log and converts successful AI translations into new heuristic rules. Run it after using the system for a while to expand coverage from your actual usage patterns.

AI dependency decreases over time. Heuristic coverage increases.
