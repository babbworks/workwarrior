---
layout: doc
title: Services
eyebrow: Documentation
description: All 25+ service domains, the service contract, and how to build new services.
permalink: /docs/services
doc_section: reference
doc_order: 1
---

Everything in Workwarrior is a service. The `ww` dispatcher routes commands to executable scripts in `services/<category>/`. Adding a service requires no changes to any existing file.

## Service Registry

| Domain | Commands | Description |
|--------|----------|-------------|
| `ww profile` | create, list, info, delete, backup, import, restore, uda, urgency, density | Profile lifecycle and configuration |
| `ww journal` | add, list, remove, rename | Named journal management |
| `ww ledger` | add, list, remove, rename | Named ledger management |
| `ww group` | list, create, show, add, remove, delete | Profile groups |
| `ww model` | list, providers, add-provider, set-default, check | LLM registry |
| `ww ctrl` | status, ai-on, ai-off, ai-status, ai-mode, prompt-ww | AI mode and settings |
| `ww find` | `<term>` | Cross-profile search |
| `ww issues` | sync, push, pull, status, enable, disable, custom | GitHub sync |
| `ww custom` | journals, ledgers, tasks, times, issues | Configuration wizards |
| `ww extensions` | taskwarrior list/search/info/refresh | Extension registry |
| `ww export` | JSON, CSV, markdown | Profile data export |
| `ww questions` | list, new, delete, `<template>` | Template-based capture |
| `ww browser` | start, stop, status | Local web UI |
| `ww remove` | `<profile>` | Full profile removal |
| `ww shortcut` | list, info, add, remove | Alias management |
| `ww deps` | install, check | Dependency management |
| `ww compile-heuristics` | --verbose, --digest | Recompile NL rules |
| `ww gun` | `<args>` | Bulk task series |
| `ww sword` | `<task> -p N` | Task splitting |
| `ww next` | — | Next-task recommendation |
| `ww schedule` | — | Auto-scheduler |
| `ww mcp` | install, status | MCP server |
| `ww tui` | install | taskwarrior-tui installer |

## Shell Functions

Injected at shell init:

| Function | Description |
|----------|-------------|
| `task` | TaskWarrior with active profile TASKRC |
| `timew` | TimeWarrior with active profile DB |
| `j [name] "text"` | JRNL entry, optional journal name |
| `l [name] <cmd>` | Hledger, optional ledger name |
| `i` | Bugwarrior pull shorthand |
| `q <template>` | Questions runner |
| `p-<name>` | Activate profile |

## Building a New Service

Services are executable scripts in `services/<category>/`. The dispatcher discovers them at runtime — no registration step.

```bash
#!/usr/bin/env bash
set -euo pipefail

source "$WORKWARRIOR_BASE/lib/logging.sh"

case "${1:-}" in
  --help|-h)
    echo "ww myservice — description"
    echo "Usage: ww myservice <subcommand>"
    exit 0
    ;;
  list)
    log_info "Listing..."
    ;;
  *)
    log_error "Unknown subcommand: '${1:-}'"
    exit 1
    ;;
esac
```

Make it executable: `chmod +x services/myservice/myservice.sh`

It's immediately available as `ww myservice` and appears in `ww help`.

## Profile-Level Services

`profiles/<name>/services/<category>/` shadows global services. Per-profile customizations without modifying global state.
