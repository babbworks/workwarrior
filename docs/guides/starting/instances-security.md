# Instances and Security

## Registering and Classifying Instances

```bash
ww instance register <id> [install_path] [visible|hidden] [preset]
```

Examples:

```bash
ww instance register main ~/ww visible multi
ww instance register secret /opt/ww-secret hidden hardened
```

## Hidden vs Unregistered

- Hidden registered instances are in registry but excluded from default list.
- Unregistered isolated installs are not in registry until explicitly registered.

## Unlock Model

```bash
ww security set-backend auto|keychain|libsecret|pass
ww security set-secret <instance>
ww unlock <instance>
ww security lock <instance>
```

- Hardened (`lock_required=true`) instances require unlock.
- Non-hardened instances do not require unlock.

## Session and Last-Instance Policy

```bash
ww config set resume-last on|off
ww config set allow-hidden-last on|off
ww config show
```

## Alias Management

```bash
ww instance aliases sync
ww instance aliases clear
```

Alias shape:
- `alias test='ww test'`
- `alias test_unlock='ww unlock test'`
