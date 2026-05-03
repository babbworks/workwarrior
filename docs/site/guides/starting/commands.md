# Commands

## Core Command Model

`ww` is the control plane command in all modes.

- In `plain` mode, `ww` is a direct launcher for one install.
- In `multi`/`hardened`, `ww` also manages instances, policies, and unlock flow.

## Install/Runtime Management

```bash
ww version
ww help
ww enable-multi
ww disable-multi
```

## Instance Commands

```bash
ww instance list [--all]
ww instance register <id> [install_path] [visible|hidden] [preset]
ww instance hide <id>
ww instance unhide <id>
ww instance detach <id>
ww instance where <id>
ww instance aliases sync
ww instance aliases clear
```

## Instance Selection

```bash
ww use <instance>
ww use <instance> <ww-subcommand...>
```

- `ww use <instance>` prints shell exports for session activation.
- `ww use <instance> <cmd>` executes immediately in that instance context.

Fast-path unlock trigger:
- `ww <instance>` attempts instance lookup and unlock path when `<instance>` is not a normal ww subcommand.

## Security Commands

```bash
ww security status
ww security set-backend auto|keychain|libsecret|pass
ww security set-secret <instance>
ww unlock <instance>
ww security lock <instance>
```

Behavior:
- Non-hardened instances do not require unlock.
- Hardened/lock-required instances enforce unlock using configured backend.

## Runtime Policy Commands

```bash
ww config show
ww config set resume-last on|off
ww config set allow-hidden-last on|off
```

These settings are stored in `~/.config/ww/runtime.conf` and used by bootstrap resolution.

## Existing Service Commands (unchanged)

```bash
ww profile ...
ww journal ...
ww ledger ...
ww group ...
ww model ...
ww service ...
ww deps install|check
ww browser ...
ww issues ...
ww find ...
```
