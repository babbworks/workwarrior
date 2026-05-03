---
layout: doc
title: Architecture
eyebrow: Documentation
description: System architecture — data flow, directory structure, environment variables, fragility register.
permalink: /docs/architecture
doc_section: reference
doc_order: 4
---

## Architecture in One Paragraph

Workwarrior is a profile-based shell productivity system. A **profile** is an isolated directory containing its own TaskWarrior data, TimeWarrior database, journals, ledgers, and config. The `ww` CLI dispatcher (`bin/ww`) routes commands to **service scripts** (`services/<category>/`) and calls **lib functions** (`lib/*.sh`). Shell functions (`j`, `l`, `task`, `timew`, etc.) are injected into the user's shell via `lib/shell-integration.sh` at init time. Profile activation sets five environment variables that all tools read. A **browser UI** serves a locally-hosted web interface. The **heuristic engine** matches natural language input against 627 compiled rules before optionally falling back to AI. Nothing in the system hardcodes paths — everything resolves through environment variables.

## Formal Cause

**Composable Local Service Architecture**

## Data Flow

```
Shell init
  → ww-init.sh sourced
  → shell-integration.sh injects p-<name> aliases and shell functions

Profile activation (p-work)
  → exports 5 env vars
  → all tool calls now use profile data

ww <command> [args]
  → bin/ww validates profile active
  → discovers service in services/<command>/
  → profile-level service checked first
  → executes service

ww browser
  → ThreadingHTTPServer starts on :7777
  → SSE channel for real-time updates
  → CMD input → HeuristicEngine → 627 rules → AI fallback → execution
```

## Environment Variables

| Variable | Value | Used By |
|----------|-------|---------|
| `WARRIOR_PROFILE` | Profile name | All ww scripts |
| `WORKWARRIOR_BASE` | Profile base path | All ww scripts |
| `TASKRC` | TaskWarrior config path | TaskWarrior |
| `TASKDATA` | TaskWarrior data path | TaskWarrior |
| `TIMEWARRIORDB` | TimeWarrior database path | TimeWarrior |

Rule: nothing hardcodes paths. Everything resolves through these variables.

## Core Components

| Component | File(s) | Role |
|-----------|---------|------|
| CLI dispatcher | `bin/ww` | Routes all commands to services |
| Shell bootstrap | `bin/ww-init.sh` | Sourced at shell start |
| Shell integration | `lib/shell-integration.sh` | Injects functions and aliases |
| Profile manager | `lib/profile-manager.sh` | Profile lifecycle |
| Logging | `lib/logging.sh` | All user-facing output |
| GitHub sync | `lib/sync-*.sh`, `lib/github-*.sh` | 10-file sync engine |
| Browser server | `services/browser/server.py` | Python3 web UI |
| Heuristic compiler | `scripts/compile-heuristics.py` | Generates 627 rules |

## Fragility Register

| Classification | Files | Impact |
|----------------|-------|--------|
| HIGH FRAGILITY | `lib/github-*.sh`, `lib/sync-*.sh` (10 files) | Data loss in TaskWarrior and GitHub |
| SERIALIZED | `bin/ww`, `lib/shell-integration.sh` | Breaks all users if broken |
| NEVER COMMIT | `profiles/*/` data files | User data |

Changes to HIGH FRAGILITY files require: extended risk brief, explicit write scope, Verifier sign-off, integration tests.

## Service Discovery

The dispatcher scans `services/<category>/` for executables. Profile-level services at `profiles/<name>/services/<category>/` shadow global services. Adding a service requires no changes to existing files.

## Security Model

Browser POST /cmd requests are validated against `ALLOWED_SUBCOMMANDS` frozenset. First token must be a known ww subcommand. No `sh -c`. No eval. Unknown subcommands return HTTP 400.

## Shell Standards

Every script: `#!/usr/bin/env bash` + `set -euo pipefail`. Absolute paths always. Logging via `lib/logging.sh`. Exit codes 0/1/2. Functions in `snake_case` with `local` variables.
