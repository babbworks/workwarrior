# services/questions/q.sh

**Type:** Executed service script  
**Invoked by:** `q [args]` shell function or `ww questions`

---

## Role

Structured prompt template system. Presents question sequences to the user and routes answers to the appropriate service (journal, task, ledger). Templates are YAML files defining question flows. Handlers are shell scripts that process the answers.

---

## Command Surface

```
q                       Run default question flow for active profile
q help                  Show available templates
q list                  List all templates
q <service>             Run default template for a service
q <service> <template>  Run a specific template
q new [service]         Create a new template interactively
q edit <template>       Edit an existing template
q delete <template>     Delete a template (--yes to skip confirmation)
```

---

## Template Structure

Templates live in `services/questions/templates/` (global) or `$WORKWARRIOR_BASE/templates/` (profile-specific, takes precedence).

YAML format:
```yaml
name: daily_reflection
service: journal
questions:
  - id: mood
    prompt: "How are you feeling today?"
    type: text
  - id: focus
    prompt: "What is your main focus?"
    type: text
answers:
  format: "Mood: {mood}\nFocus: {focus}"
  target: journal
```

---

## Handlers

`services/questions/handlers/` contains per-service handlers that receive the collected answers and route them to the appropriate tool:
- `journal.sh` — writes to JRNL via the `j` function
- `task.sh` — creates TaskWarrior tasks
- `ledger.sh` — appends to Hledger ledger

---

## Profile Override

Profile-specific templates at `$WORKWARRIOR_BASE/templates/` shadow global templates with the same name. This allows per-profile question flows without modifying global templates.

---

## Workpad Algorithm

`wp-algorithm.sh` implements a "workpad" concept — a structured daily planning session that combines question templates with task review. `workpad-blocks.sh` defines the block structure for workpad sessions.

## Changelog

- 2026-04-10 — Initial version
