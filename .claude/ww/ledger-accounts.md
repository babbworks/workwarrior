# Ledger Accounts — v2-newent

> Canonical account hierarchy for `wwdev.journal`.
> Add accounts here before adding them to the journal.
> Run `hledger -f .../wwdev.journal check` after every addition.

## Commodities

| Symbol | Meaning |
|---|---|
| `TEST` | Individual test (passing = asset, failing = liability) |
| `FILE` | Source file (by category) |
| `SESSION` | Completed coding session (throughput unit) |

Additional commodities added as project grows — document here first.

## Account Tree

```
Assets
  Tests
    Passing          TEST   working test capital
  Code
    Services         FILE   newent/services/*.py
    Tests            FILE   tests/test_*.py
    Schema           FILE   schema/*.sql
    CLI              FILE   newent/cli.py + models.py
  Docs
    Canonical        FILE   ARCHITECTURE, CLI-DESIGN, DATA-MODEL, SERVICES
    Guidance         FILE   .claude/ww/*.md

Liabilities
  Tests
    Failing          TEST   owed fixes (extinguished when tests pass)

Income
  Sessions           SESSION  completed coding sessions

Equity
  Codebase
    Origin           TEST / FILE / SESSION  baseline / source of created assets
```

## Double-Entry Rules

- Every transaction sums to zero across all postings.
- Fixing a failing test: debit `Assets:Tests:Passing`, credit `Liabilities:Tests:Failing`.
- Adding a file: debit `Assets:Code:<category>`, credit `Equity:Codebase:Origin`.
- Completed session: debit `Income:Sessions`, credit `Equity:Codebase:Origin`.

## Opening Balance (2026-04-20)

```hledger
2026-04-20 * v2-newent opening balance
    Assets:Tests:Passing        492 TEST
    Liabilities:Tests:Failing    33 TEST
    Equity:Codebase:Origin     -525 TEST
```
