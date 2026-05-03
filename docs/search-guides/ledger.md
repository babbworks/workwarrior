# Ledger Search Guide

Hledger uses a query language across commands.

## Common patterns
```bash
# Basic keyword
hledger register invoice

# Field queries
hledger register desc:amazon
hledger register acct:Expenses

# Boolean expressions
hledger print expr:'date:2024 and (desc:amazon or desc:amzn)'
```

## Tips
- Use `-f <ledger.journal>` to target a file.
- `register` shows postings; `print` shows transactions.
