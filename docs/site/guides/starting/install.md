# Install

Workwarrior now supports two install paradigms:

1. `plain` (default): direct launcher, lowest overhead.
2. `multi`/`hardened`: bootstrap dispatcher with instance registry and optional unlock policy.

## Quick Start (Default: Plain)

```bash
./install.sh --preset plain --cmd ww
```

What this does:
- Installs ww files to the chosen install directory (default `~/ww`).
- Creates a direct launcher at `~/.local/bin/ww`.
- Does not enable runtime dispatcher/bootstrap by default.

## Presets

```bash
./install.sh --preset plain
./install.sh --preset multi --enable-instance-aliases
./install.sh --preset isolated --cmd ww_one
./install.sh --preset hardened --security-backend auto
```

- `plain`: direct command path, no registry dependency.
- `multi`: enables bootstrap + registry-driven instance routing.
- `isolated`: installs without auto-registration (can register later).
- `hardened`: multi mode with lock-required policy on registered instances.

## Installer Flags

```bash
./install.sh --preset <plain|multi|isolated|hardened>
./install.sh --cmd <command_name>
./install.sh --security-backend <auto|keychain|libsecret|pass>
./install.sh --enable-instance-aliases
./install.sh --force
```

Notes:
- `--cmd` lets you install named launchers like `ww_one`.
- `--force` allows launcher replacement if the command path already exists.

## Dependency Toolchain

Core dependency setup is still:

```bash
ww deps install
ww deps check
```

## Migration Behavior

Installer now migrates managed shell blocks with backup when needed:
- Backs up rc files to `*.ww-migrate.<timestamp>`
- Removes old managed `Workwarrior Installation` blocks before applying new mode wiring

## Multi-Mode Bootstrap and Policies

In multi/hardened mode, bootstrap uses:
- `~/.config/ww/registry/` for instance manifests
- `~/.config/ww/last-instance`
- `~/.config/ww/runtime.conf` policy toggles

Policy toggles:

```bash
ww config set resume-last on|off
ww config set allow-hidden-last on|off
ww config show
```

## Security Backends

```bash
ww security status
ww security set-backend auto|keychain|libsecret|pass
ww security set-secret <instance>
ww unlock <instance>
ww security lock <instance>
```

Linux strategy:
- `libsecret` preferred when available
- `pass` fallback
- `keyctl` used for session token cache
