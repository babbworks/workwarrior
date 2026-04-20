# Profiles

A profile is a directory containing everything for one work context. Complete isolation — no data shared between profiles.

## Structure

```
profiles/<name>/
  .taskrc              TaskWarrior config (UDAs, reports, urgency coefficients)
  .task/               Task database + hooks
  .timewarrior/        TimeWarrior database
  journals/            Journal files (multiple named journals supported)
  ledgers/             Ledger files (multiple named ledgers supported)
  jrnl.yaml            Journal name → file mapping
  ledgers.yaml         Ledger name → file mapping
  .config/             Service configs (bugwarrior, taskcheck)
```

## Lifecycle

```bash
ww profile create <name>       # Create
ww profile list                # List all
ww profile info <name>         # Details
ww profile delete <name>       # Delete (with safety backup)
ww profile backup <name>       # Archive to tar.gz
ww profile import <archive>    # Create from archive
ww profile restore <archive>   # Replace existing from archive
```

## Activation

```bash
p-work                         # Activate — sets all env vars
```

Behind the scenes, this exports `TASKRC`, `TASKDATA`, `TIMEWARRIORDB`, `WARRIOR_PROFILE`, and `WORKWARRIOR_BASE`. Every tool reads these automatically.

## Multiple Named Resources

A single profile can have multiple journals and ledgers:

```bash
ww journal add strategy        # Create a named journal
ww journal add engineering
ww journal list                # See all journals in the profile
j strategy "Board meeting notes"
j engineering "Refactored auth module"
```

Same for ledgers:

```bash
ww ledger add business
ww ledger add personal
l business balance
```

The browser UI shows a dropdown selector when multiple resources exist.

## UDA Management

TaskWarrior's User Defined Attributes are first-class in Workwarrior. Profiles can carry 100+ UDAs.

```bash
ww profile uda list            # All UDAs with source badges
ww profile uda add goals       # Interactive creation
ww profile uda remove <name>   # Remove with safety warnings
ww profile uda group work      # Group UDAs for batch operations
ww profile uda perm goals nosync  # Set sync permissions
```

UDAs are classified by source: `[github]` for bugwarrior-injected, `[extension]` for tool-added, `[custom]` for user-defined.

## Urgency and Density

```bash
ww profile urgency             # Tune urgency coefficients interactively
ww profile density             # Due-date density scoring (TWDensity)
```

## Profile Groups

```bash
ww group create clients work freelance
ww group show clients
ww group add clients newclient
ww group list
```

## Removal

```bash
ww remove <name>               # Prompted: archive, delete, or skip
ww remove --keep work          # Remove all EXCEPT work
ww remove --archive-all        # Archive everything
ww remove --dry-run            # Preview without changes
```

The remove service scrubs all references: groups.yaml, state files, shell aliases, question templates.

## Copying UDAs Between Profiles

When creating a profile, the installer offers to copy `.taskrc` from an existing profile. This brings over all UDA definitions, reports, urgency coefficients, and other TaskWarrior configuration.
