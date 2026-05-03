# Workwarrior Release v0.2 Overview

## What v0.2 Delivers

Release v0.2 introduces a dual-mode install and runtime model:

- `plain` (default): direct launcher, lowest runtime overhead.
- `multi` / `hardened`: optional bootstrap + registry + instance controls.

This release keeps `ww` as the control plane command while allowing custom launcher names (for example, `ww_one`).

## Highlights

- Install presets: `plain`, `multi`, `isolated`, `hardened`.
- Command-name installs via `--cmd <name>`.
- Instance lifecycle commands (`ww instance ...`).
- Runtime policy controls (`ww config set resume-last ...`, `allow-hidden-last ...`).
- Security controls (`ww security ...`, `ww unlock ...`) with Linux backend strategy.
- Optional per-instance alias sync (`ww instance aliases sync`).
- Legacy shell block migration with backup during install updates.

## Recommended Mode Selection

- Use `plain` for fastest command path, including AI-agent-heavy workflows.
- Use `multi` when you need registry-driven instance routing and optional alias sync.
- Use `isolated` for unregistered installs that should not be globally discoverable.
- Use `hardened` as an advanced optional mode when lock-required activation is needed.

## Compatibility (v0.2)

- Supported shells: `bash`, `zsh`.
- Supported platforms: macOS, Linux.
- Not yet official in v0.2: fish shell and Windows-native workflows.

## Security Posture (v0.2)

- Hardened mode is advanced optional.
- Non-hardened instances do not require unlock.
- Hardened instances require unlock via configured backend.
- Linux strategy: `libsecret` preferred, `pass` fallback, `keyctl` for session token caching.

## Migration Summary

Installer migration behavior now:

- detects legacy managed shell install blocks,
- writes backup files (`*.ww-migrate.<timestamp>`),
- removes old managed blocks before applying new mode wiring.

## Fast Validation Checklist

```bash
ww version
ww config show
ww instance list --all
ww security status
ww instance aliases sync
ww deps check
```

## Where to Read More

- Detailed release and architecture notes: `docs/releases/release-v0.2-deep-dive.md`
- Install guide: `docs/guides/starting/install.md`
- Commands guide: `docs/guides/starting/commands.md`
- Instance/security guide: `docs/guides/starting/instances-security.md`
