---
id: TASK-RES-001
title: Ledger account/commodity inventory — aggregate from all profiles
status: pending
priority: M
area: resources
created: 2026-04-27
tw_uuid: 74cd90b2
---

## Goal

Build a canonical `~/ww/resources/inventory/ledger-accounts.yaml` that aggregates all unique hledger account names and commodity symbols found across every profile's ledger files. This becomes the source for browser tab-completion and the `knownAccounts` array.

## Context

The browser already wires tab-completion from `/data/accounts` which calls `hledger accounts`. But this only covers the ACTIVE profile. Users working across profiles need cross-profile account visibility, and the browser's tab-complete should surface the union. The inventory also serves as reference for new profiles creating their chart of accounts.

## Acceptance Criteria

- [ ] Script `scripts/build-ledger-inventory.sh` scans all profile ledger files and writes `resources/inventory/ledger-accounts.yaml`
- [ ] Format: `{ accounts: [str], commodities: [str] }` — sorted, deduplicated
- [ ] Browser `/data/accounts` endpoint optionally merges inventory file with active-profile accounts
- [ ] `ww ledger inventory` CLI subcommand triggers the scan and prints summary
- [ ] Handles profiles with no ledger gracefully (skip, no error)

## Write Scope

- `scripts/build-ledger-inventory.sh` (new)
- `resources/inventory/` (new directory)
- `services/browser/server.py` — `/data/accounts` merge with inventory
- `bin/ww` — route `ww ledger inventory`

## Risk

Read-only scan. No profile data mutation. Low risk.

## Rollback

Delete inventory file and revert server.py accounts endpoint.

## Status

complete — 2026-04-27. scripts/build-ledger-inventory.sh scans all profiles using hledger or grep fallback; writes resources/inventory/ledger-accounts.yaml; resources/inventory/ gitignored. ww ledger inventory routes to the script. /data/accounts merges inventory if available.
