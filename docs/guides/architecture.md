# Architecture

## Formal Cause

**Composable Local Service Architecture**

## Mode Split

Workwarrior now has two operating patterns:

1. `plain` (default): direct launcher (`~/.local/bin/<cmd> -> <install>/bin/ww`), no dispatcher.
2. `multi`/`hardened`: bootstrap dispatcher + registry manifests + optional unlock policy.

## Control and State Paths

- Config home: `~/.config/ww/`
- Registry: `~/.config/ww/registry/*.json`
- Last instance pointer: `~/.config/ww/last-instance`
- Runtime policy: `~/.config/ww/runtime.conf`

## Instance States

- `visible-registered`: listed by default.
- `hidden-registered`: hidden from default list; visible with explicit inclusion.
- `unregistered-isolated`: install exists without registry entry.

## Bootstrap Resolution (multi/hardened)

Resolution precedence:
1. `WW_ACTIVE_INSTANCE` (if mapped in registry)
2. explicit `WW_BASE` if executable
3. `last-instance` if `resume_last=on`
4. default install fallback

Hidden last-instance restore requires `allow_hidden_last=on`.

## Security Layer

Per-instance manifest includes `lock_required`:
- `true` for hardened installs
- `false` otherwise

Backends:
- macOS: Keychain
- Linux: libsecret preferred, pass fallback
- Linux session cache: keyctl token

Non-hardened instances bypass unlock; hardened instances require unlock success.

## Aliases

Optional instance aliases are generated from visible registry entries:
- `<alias> -> ww <instance-id>`
- `<alias>_unlock -> ww unlock <instance-id>`

Managed via:

```bash
ww instance aliases sync
ww instance aliases clear
```
