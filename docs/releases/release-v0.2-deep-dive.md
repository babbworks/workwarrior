# Workwarrior Release v0.2 Deep Dive

## 1. Release Scope

v0.2 is the first total release milestone for the new install/runtime paradigm. It adds optional multi-instance orchestration while preserving a low-overhead default path.

Core objective: keep `ww` as a stable control plane and allow users to choose operational mode by install preset.

Formal cause framing for this release: **Composable Local Service Architecture**.

## 2. Product and Runtime Model

### 2.1 Dual-mode execution

- `plain` mode (default):
  - direct launcher (`~/.local/bin/<command_name>`),
  - no bootstrap dispatcher required,
  - minimal command-path overhead.

- `multi`/`hardened` mode:
  - bootstrap-enabled routing,
  - registry-backed instance selection,
  - optional alias sync,
  - last-instance policy controls.

### 2.2 Control-plane identity

`ww` is both:
- an instance entrypoint (through direct launcher and `WW_BASE`), and
- a system control surface (`instance`, `use`, `config`, `security`).

## 3. Repository Organization and Design

Top-level organization:

- `bin/`: CLI entry points (`ww` and helpers)
- `lib/`: shared shell libraries and runtime helpers
- `services/`: category-oriented service modules
- `scripts/`: utility and lifecycle scripts
- `config/`: global configuration templates and defaults
- `profiles/`: per-profile runtime state/data
- `docs/`: user and technical documentation

Design style:
- modular shell service boundaries,
- centralized command dispatch in `bin/ww`,
- environment-driven isolation (`TASKRC`, `TASKDATA`, `TIMEWARRIORDB`, etc.).

### 3.1 Service architecture clarification

Workwarrior uses a composable local service module layout (`services/<category>/...`): local CLI service modules, not distributed network microservices.

## 4. Instance Architecture

### 4.1 Registry and state paths

- `~/.config/ww/registry/*.json` (registered instances)
- `~/.config/ww/last-instance`
- `~/.config/ww/runtime.conf`

### 4.2 Instance states

- `visible-registered`
- `hidden-registered`
- `unregistered-isolated`

### 4.3 Key commands

```bash
ww instance list [--all]
ww instance register <id> [install_path] [visible|hidden] [preset]
ww instance hide <id>
ww instance unhide <id>
ww instance detach <id>
ww instance where <id>
ww use <instance> [command...]
```

## 5. Security Architecture

### 5.1 Lock policy

Per-instance manifest includes `lock_required`.

- `true` for hardened profile installations
- `false` otherwise

Behavior:
- non-hardened instances bypass unlock requirement,
- hardened instances enforce unlock.

### 5.2 Backend strategy

- macOS: Keychain
- Linux preferred order: libsecret -> pass
- Linux session token cache: keyctl

Commands:

```bash
ww security status
ww security set-backend auto|keychain|libsecret|pass
ww security set-secret <instance>
ww unlock <instance>
ww security lock <instance>
```

## 6. Runtime Policy Controls

Configured via:

```bash
ww config set resume-last on|off
ww config set allow-hidden-last on|off
ww config show
```

Policy file: `~/.config/ww/runtime.conf`

These controls affect bootstrap resolution behavior in multi/hardened mode.

## 7. Alias Management

Optional alias generation from visible registry entries:

```bash
ww instance aliases sync
ww instance aliases clear
```

Generated forms:
- `<alias> -> ww <instance-id>`
- `<alias>_unlock -> ww unlock <instance-id>`

## 8. Migration and Rollback

Installer migration updates now:
- back up affected shell rc files (`*.ww-migrate.<timestamp>`),
- remove legacy managed blocks,
- apply mode-appropriate wiring.

Rollback approach:
1. restore backup rc file,
2. remove new bootstrap or launcher lines if needed,
3. re-run install with desired preset.

## 9. Compatibility and Limits

Supported in v0.2:
- bash and zsh
- macOS and Linux

Current limits:
- fish shell workflows are not first-class in this release,
- Windows-native path is not a v0.2 target,
- hardened policy model is present and usable but still shell-centric at orchestration layer.

## 10. Suggested Operational Playbooks

### 10.1 Fast single-instance setup

```bash
./install.sh --preset plain --cmd ww
ww deps install
ww profile create work
```

### 10.2 Hidden hardened instance

```bash
./install.sh --preset hardened --cmd ww_secret --security-backend auto
ww instance register secret /path/to/install hidden hardened
ww security set-secret secret
ww unlock secret
```

### 10.3 Alias refresh after registry changes

```bash
ww instance aliases sync
```

## 11. Verification Set

```bash
ww version
ww config show
ww instance list --all
ww security status
ww instance aliases sync
ww deps check
```
