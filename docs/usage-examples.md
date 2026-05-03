# Usage Examples

This page is the approved command examples library. Each major command family includes:
- **Basic**: common default flow
- **Scoped override**: explicit `--profile` or `--global` targeting
- **Advanced**: power-user or automation-oriented invocation

## Profile Commands

```bash
# Basic
ww profile list

# Scoped override
ww --profile babb profile list

# Advanced
ww --json profile info babb
```

## Service Discovery Commands

```bash
# Basic
ww service list

# Scoped override
ww --profile babb service info custom

# Advanced
ww --json service list
```

## Journal Commands

```bash
# Basic
ww journal list

# Scoped override
ww --profile babb journal list

# Advanced
ww --json journal list
```

## Ledger Commands

```bash
# Basic
ww ledger list

# Scoped override
ww --profile babb ledger list

# Advanced
ww --json ledger list
```

## Group Commands

```bash
# Basic
ww group list

# Scoped override (global context explicit)
ww --global group list

# Advanced
ww groups
```

## Model Commands

```bash
# Basic
ww model list

# Scoped override (global context explicit)
ww --global model list

# Advanced
ww model providers
```

## Find Commands

```bash
# Basic
ww find invoice

# Scoped override
ww find --profile babb --type task invoice

# Advanced
ww find --type task --native invoice
```

## Issues Commands

```bash
# Basic
ww issues uda list

# Scoped override
ww --profile babb issues uda list

# Advanced
ww issues uda help
```

## Questions Commands

```bash
# Basic
ww q list

# Scoped override
ww --profile babb q list

# Advanced
ww q journal
```

## Timew Extension Commands

```bash
# Basic
ww timew extensions list

# Scoped override
ww --profile babb timew extensions list

# Advanced
ww --json timew extensions list
```

## Routines Commands

```bash
# Basic
ww routines list

# Scoped override
ww --profile babb routines list

# Advanced
ww routines add "Clean room" --frequency weekly --run-now
```

## Output Modes

```bash
# Default compact output
ww profile list

# Expanded human output
ww --verbose service info custom

# Machine-readable output
ww --json profile list
```

## Compatibility Aliases

```bash
ww journals
ww ledgers
ww groups
ww models
ww profiles
ww services
```

## Standalone Help

```bash
ww help
ww help profile
ww help custom
ww help standalone
```
