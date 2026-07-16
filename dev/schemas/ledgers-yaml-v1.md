# ledgers.yaml — v1

**Contract for:** `profiles/<name>/ledgers.yaml`
**Status:** normative, v1 (frozen 2026-07-11).
**Owning module:** `lib/ledger-config.sh` — the **single** reader/writer. No other code
path may parse this file.
**Reasoning:** `dev/logs/decisions.md`, 2026-07-11. This document is the *what*; that
entry is the *why*.

> **Retroactively homed.** This contract was frozen in `decisions.md` before
> `dev/schemas/` existed. It is reproduced here as the authoritative reference. The
> decisions entry remains the historical record of the debate.

---

## 1. What this file is — and is not

`ledgers.yaml` is **not an hledger format.** hledger has no config file; it takes
`-f <file>` and `include` directives.

This file was invented to mirror `jrnl.yaml`, which *is* a real format — a deliberate
house-style parallel. Its schema is therefore modelled on jrnl's: **an entry value is
either a string (the path) or a map carrying the path plus options.**

---

## 2. The shape

```yaml
# simple form — entry value is the path
default: ~/ww/profiles/work/ledgers/work.journal
consulting: ~/ww/profiles/work/ledgers/consulting.journal

# rich form — entry value is a map, path under `journal:`
energy:
  journal: ~/ww/profiles/work/ledgers/energy.journal
  commodity: kWh
  hidden: false
```

### Rules

| Rule | Detail |
|---|---|
| Entry value | **string** (absolute path) **OR** map with the path under `journal:`. |
| `default:` | **Reserved and required.** Resolved **by name, never by position.** |
| Writer behaviour | Emits **string form** unless metadata is set; **upgrades to map form on demand**. |
| Legacy `path:` | **Read** with a deprecation warning (transition shim). **Never written.** |

### Blessed map fields (v1)

| Field | Status | Meaning |
|---|---|---|
| `journal` | **required in map form** | Absolute path to the `.journal` file. |
| `commodity` | active | Default commodity for this ledger (`kWh`, `h`, `USD`…). |
| `hidden` | active | Omit from inventory/UI listings. |
| `role` | **reserved, inert** | `standalone` \| `include`. No consumer yet. |
| `description` | **reserved, inert** | No consumer yet. |

Reserved-but-inert fields MUST be preserved on rewrite and MUST NOT be acted upon.

---

## 3. Resolved micro-decisions

1. **`default` is a direct entry, not an alias** to a named ledger.
2. **v1 ships `commodity` + `hidden` only.** `role`/`description` are reserved.
3. **Duplicate paths across entries warn, they do not error** — `default` legitimately
   shares a path with the profile's primary named ledger.

---

## 4. The module contract

Single owner: `lib/ledger-config.sh`, python/`yaml.safe_load`-backed (consistent with
`lib/instance-registry.sh`). Obeys sourced-library rules: no `set -euo pipefail`, return
codes only, no `exit`.

**Readers:** `ledger_cfg_path` · `ledger_cfg_names` · `ledger_cfg_resolve` ·
`ledger_cfg_default_path` · `ledger_cfg_get_field` · `ledger_cfg_exists`
**Writers:** `ledger_cfg_add` · `ledger_cfg_remove` · `ledger_cfg_rename` ·
`ledger_cfg_set_default` · `ledger_cfg_set_field`

---

## 5. What this contract fixed

The audit that motivated v1 found `ledgers.yaml` written three incompatible ways and read
four ways, because **five independent code paths each re-implemented their own YAML parse**
(`awk`/`grep`/`sed`/`IFS=:`/python) with no owner of the file contract.

| ID | Defect | Closed by |
|---|---|---|
| F1 | `cmd_hledger_passthrough` hard-coded `ledgers/default.journal` (a path that never exists) and ignored the exported `LEDGER_F` | TASK-LED-006 |
| F2 | Schema fork — three observed shapes | this contract |
| F3 | `ww ledger inventory` scanned hard-coded paths and grepped `jrnl.yaml`, never reading `ledgers.yaml` | TASK-LED-008 |
| F4 | Two disagreeing default-resolvers (`default:` key vs `values()[0]`) | TASK-LED-005 |
| F5 | Missing verbs: `set-default`, `check`, `report`, transaction poster | TASK-LED-007 |
| F6 | `show_help_ledger` and `config/command-syntax.yaml` disagreed (Gate C drift) | TASK-LED-007 |

Implementation: TASK-LED-004 → 011, branch `agent/builder/ledger-schema`.

---

## 6. Changelog

**v1 — 2026-07-11** — initial frozen contract. jrnl-style hybrid (string-or-map) adopted
over pure-inline and pure-nested-manifest alternatives. Single owning module.
