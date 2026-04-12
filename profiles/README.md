# Profiles

This directory contains user profiles created at runtime via `ww profile create <name>`.

Each profile is an isolated workspace with its own:
- TaskWarrior config and database (`.taskrc`, `.task/`)
- TimeWarrior database (`.timewarrior/`)
- Journals (`journals/`, `jrnl.yaml`)
- Ledgers (`ledgers/`, `ledgers.yaml`)
- Service configuration (`.config/`)

Profile data is gitignored — only this README is tracked.

## Quick Start

```bash
ww profile create work     # Create a profile
p-work                     # Activate it
ww profile list            # List all profiles
ww profile info work       # Show profile details
ww profile backup work     # Archive a profile
ww remove work             # Remove with archive/delete options
```

## Profile Structure

```
profiles/<name>/
  .taskrc                  TaskWarrior config (UDAs, hooks, data path)
  .task/                   Task database + hooks
  .timewarrior/            TimeWarrior database
  .config/                 Service configs (bugwarrior, taskcheck, etc.)
  journals/                JRNL journal files
  ledgers/                 Hledger ledger files
  jrnl.yaml                Journal name → file mapping
  ledgers.yaml             Ledger name → file mapping
```
