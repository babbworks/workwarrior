# Workwarrior

Workwarrior is a profile-based productivity system that integrates TaskWarrior, TimeWarrior, JRNL, and Hledger under a unified shell workflow. Each profile is isolated, with its own configuration, data stores, services, and aliases.

**Goals**
1. Fast, terminal-first workflows
2. Clean separation between work contexts
3. Extensible services for repeated tasks
4. Simple backup/restore and portability

## What’s Included

- Profile lifecycle management (create, list, info, delete, backup)
- Shell integration (aliases + global functions)
- Question templates for consistent capture
- Service registry with profile-specific overrides
- Tests for core properties and integrations

## Installation

**Prerequisites** (optional but recommended)
- TaskWarrior - task management
- TimeWarrior - time tracking
- JRNL - journaling
- Hledger - ledger accounting
- Bugwarrior - issue synchronization (optional)
- Python 3 - used by Questions Service

The installer will check for these and warn if missing, but will continue.

**Quick Install**
```bash
git clone <repo-url> ~/workwarrior
cd ~/workwarrior
./install.sh
source ~/.bashrc
```

This installs workwarrior to `~/ww` and adds the `ww` command to your shell.

**Install Options**
```bash
./install.sh                    # Interactive install
./install.sh --non-interactive  # Automated (no prompts)
./install.sh --force            # Reinstall/upgrade
```

**Uninstall**
```bash
./uninstall.sh              # Remove (keeps profiles)
./uninstall.sh --purge      # Remove everything
```

## Quick Start

1. Create a profile:
   ```bash
   ww profile create work
   ```

2. Activate the profile:
   ```bash
   p-work
   ```

3. Use global helpers:
   ```bash
   j "Daily log entry"
   l balance
   task add "My first task"
   i pull  # Sync issues (if configured)
   ```

4. Questions service:
   ```bash
   q
   q new journal
   q journal daily_reflection
   ```

## Key Commands

**Using the `ww` command:**
```bash
ww profile create <name>    # Create a new profile
ww profile list             # List all profiles
ww profile info <name>      # Show profile details
ww profile delete <name>    # Delete a profile
ww profile backup <name>    # Backup a profile
ww groups list              # List profile groups
ww groups create <name> ... # Create a group with profiles
ww groups show <name>       # Show profiles in a group
ww models list              # List configured models
ww models providers         # List model providers
ww models show <name>       # Show model details
ww find <term>              # Search across profiles
ww service list             # List available services
ww shortcut list            # List available shortcuts
ww shortcut info <key>      # Show shortcut details
ww shortcut add <key> ...   # Add or update a user shortcut
ww shortcut remove <key>    # Remove a user shortcut override
ww version                  # Show version
ww help                     # Show help
```

Notes:
- Use `ww groups ...` (plural). `ww group ...` is not supported.
- You can run `help <command>` as a shortcut for `ww help <command>` (e.g., `help groups`).

**Global shell functions:**
```bash
j [journal-name] <entry>    # Write to journal
l [args]                    # Access default ledger
i [args]                    # Bugwarrior issue sync
list [args]                 # List management
task [args]                 # TaskWarrior
timew [args]                # TimeWarrior
```

**Issues service (Bugwarrior):**
```bash
i pull                      # Sync issues from external services
i pull --dry-run            # Test configuration
i custom                    # Configure services (GitHub, Jira, etc.)
i uda                       # List bugwarrior UDAs
```

See `services/custom/README-issues.md` for complete issues service documentation.

**Direct script access:**
```bash
scripts/create-ww-profile.sh <profile-name>
scripts/manage-profiles.sh list|info|delete|backup
```

## Scope Flags (Global or Profile)

Some commands support scope flags to run without activating a profile:

```bash
list --global                 # Use global list workspace
list --profile work           # Use a specific profile without activation
j --profile work "Entry"      # Write to a profile journal directly
l --global balance            # Use global ledger
task --global add "Item"      # Use global TaskWarrior data
timew --profile work summary  # Use a specific profile's TimeWarrior data
```

Notes:
- `j custom` opens custom journal configuration for the active or targeted profile.
- `l custom` opens custom ledger configuration for the active or targeted profile.
- `i custom` opens issues service configuration for the active or targeted profile.
- `j custom`, `l custom`, and `i custom` are not available for `--global`.
- Issues service (`i`) requires a profile and does not support `--global`.

## Environment Variables

When a profile is active, these are set:
- `WARRIOR_PROFILE` – active profile name
- `WORKWARRIOR_BASE` – active profile base directory
- `TASKRC` – path to profile `.taskrc`
- `TASKDATA` – path to profile `.task`
- `TIMEWARRIORDB` – path to profile `.timewarrior`

## Directory Structure (High Level)

```
workwarrior/
├── lib/                # Core libraries
├── scripts/            # CLI entrypoints
├── services/           # Services registry (global)
├── profiles/           # User profiles (created at runtime)
├── resources/          # Templates and supporting files
├── tests/              # Property and integration tests
└── .kiro/              # Specs and requirements
```

## Services

Services live in `services/<category>/`. Profile-specific overrides can be added under `<profile>/services/<category>/` and take precedence when a profile is active.

See `services/README.md` for the registry overview and service development patterns.

## Documentation

- `docs/service-development.md` – how to build and register services
- `docs/usage-examples.md` – practical workflows and CLI usage
- `docs/search-guides/` – tool-specific search guides

## Status

Implementation status is tracked in `IMPLEMENTATION_STATUS.md`.
