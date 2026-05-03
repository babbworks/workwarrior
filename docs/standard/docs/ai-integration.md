---
layout: doc
title: AI Integration
eyebrow: Documentation
description: Optional AI integration — local and remote providers, per-profile override, fallback chains.
permalink: /docs/ai-integration
doc_section: features
doc_order: 4
---

AI is optional. The heuristic engine handles the vast majority of natural language commands without any AI configuration. AI adds flexibility for unusual phrasings and complex instructions the heuristics don't cover.

## Modes

| Mode | Behavior |
|------|---------|
| `off` | Heuristics only. Unmatched inputs return a clear error. Default. |
| `local-only` | Heuristics → ollama if no match. No data leaves your machine. |
| `local+remote` | Heuristics → local LLM → remote provider fallback chain. |

## Configuration

```yaml
# config/ai.yaml
mode: off
preferred_provider: ollama
access_points:
  cmd_ai: true
```

Per-profile override in `profiles/<name>/ai.yaml`. Profile config takes precedence.

## CLI Controls

```bash
ww ctrl ai-on              # Enable (uses mode from config)
ww ctrl ai-off             # Disable
ww ctrl ai-status          # Show resolved state (global + profile + effective)
ww ctrl ai-mode local-only # Set mode
```

Same controls in the browser CTRL panel. Changes take effect immediately — no restart.

## Provider Registry

```bash
ww model add-provider ollama ollama http://localhost:11434
ww model add-provider openai openai
ww model set-default llama3.2
ww model list
ww model check             # Test connectivity to all providers
```

Providers stored in `config/models.yaml`. Fallback chain: tries each provider in order, uses first that responds.

## Local LLM (ollama)

Recommended for `local-only` mode. Keeps all data on your machine.

```bash
# Install ollama
brew install ollama    # macOS

# Pull a model
ollama pull llama3.2

# Add to workwarrior
ww model add-provider ollama ollama http://localhost:11434
ww model set-default llama3.2
ww ctrl ai-mode local-only
```

## Per-Profile Override

Work profile might use `mode: off` (deterministic commands, professional data, no external API calls). Personal profile might use `mode: local+remote` (relaxed, convenience matters more).

```yaml
# profiles/work/ai.yaml
mode: off

# profiles/personal/ai.yaml
mode: local+remote
preferred_provider: openai
```
