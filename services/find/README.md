# Find Service

The Find service searches across profiles and data types (journals, ledgers, lists).

## Simple Search

```bash
ww find invoice
ww find --profile work meeting
ww find --type journal review
```

## Advanced Search

Use `--query` or `--advanced` for boolean logic, filters, and pipe transforms.

```bash
ww find --query '(invoice OR receipt) AND NOT draft'
ww find --query 'type:journal profile:work "weekly review"'
ww find --query 're:TODO-[0-9]+' 
```

### Filters
- `type:` journal|ledger|list|task|time
- `profile:` profile name
- `path:` glob path filter
- `date:` substring match for a date
- `re:` or `regex:` regular expression term

### Pipe Transforms
- `| head 20`
- `| group profile|type|none`
- `| json`
- `| summary`

## Output Options

```bash
ww find --context 2 invoice
ww find --max 50 invoice
ww find --group type invoice
ww find --paths-only invoice
ww find --summary invoice
ww find --case-sensitive invoice
ww find --regex 'inv(oi)?ce'
ww find --exclude '*/archive/*' invoice
```

## Native Tool Search

Use `--native` to delegate to the tool's native search where available (task, time, journal, ledger).

```bash
ww find --type task --native invoice
ww find --type time --native @client-x :week
ww find --type ledger --native 'desc:invoice'
```

## Saved Queries

```bash
ww find --save invoices --query 'type:ledger invoice'
ww find --load invoices
```

Queries are stored in:
`WW_BASE/config/find-queries.yaml`
