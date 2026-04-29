# Modular Journals and Ledger Include Strategy

Workwarrior supports multiple named journals and ledger files per profile.
This document describes the recommended split patterns and how to provision them.

## hledger: Include Strategy

A profile's main `.journal` file can include sub-journals using hledger's
`include` directive. This keeps large ledgers manageable:

```hledger
; profiles/work/ledgers/work.journal  — main entry point

; Include by year
include 2024.journal
include 2025.journal
include 2026.journal

; Include by topic
include projects/ww-browser.journal
include projects/consulting.journal
```

### Provisioning a new sub-ledger

```bash
ww ledger inventory          # see existing accounts cross-profile
ww resource create ledger <name>   # creates sub-file + updates include list
```

The `ww resource create ledger <name>` command:
1. Creates `profiles/<active>/ledgers/<name>.journal`
2. Adds `include <name>.journal` to the profile's main journal
3. Registers the file in `ledgers.yaml` so the browser can access it

## jrnl: Named Journal Config

jrnl supports multiple named journals via config:

```yaml
# profiles/work/.config/jrnl.yaml
journals:
  default: ~/ww/profiles/work/journals/work.txt
  agentic-dev: ~/ww/profiles/work/journals/agentic-dev.txt
  personal: ~/ww/profiles/work/journals/personal.txt
```

### Provisioning a new named journal

```bash
ww resource create journal <name>   # creates file + updates jrnl.yaml
```

The `ww resource create journal <name>` command:
1. Creates `profiles/<active>/journals/<name>.txt`
2. Adds the entry to `.config/jrnl.yaml`
3. Registers in the profile's journal resource map so the browser dropdown shows it

## Recommended Multi-File Layout

```
profiles/work/
├── .taskrc
├── .task/
├── journals/
│   ├── work.txt          ← default journal
│   ├── agentic-dev.txt   ← AI/dev session journal
│   └── notes.txt         ← quick notes
├── ledgers/
│   ├── work.journal      ← main (includes others)
│   ├── 2025.journal
│   ├── 2026.journal
│   └── projects/
│       └── ww.journal
└── .config/
    └── jrnl.yaml
```

## profile-meta-template.yaml Reference

The recommended multi-file structure is reflected in `resources/profile-meta-template.yaml`:

```yaml
journals:
  default: "journals/{profile}.txt"
  agentic-dev: "journals/agentic-dev.txt"

ledgers:
  default: "ledgers/{profile}.journal"
```

## Implementation Status

- `ww resource create ledger <name>` — **pending** (planned for TASK-LED-003 implementation)
- `ww resource create journal <name>` — **pending**
- Browser dropdown already reads `ledgers.yaml` and `jrnl.yaml` for named resources ✓
- `ww ledger list` / `ww journals list` already enumerate named resources ✓
