# Groups Service

The Groups service lets you organize profiles into named collections for quick association and listing.
Groups are global (no active profile required) and stored in:

`WW_BASE/config/groups.yaml` (default: `~/ww/config/groups.yaml`)

## Data Model

```yaml
groups:
  focus:
    profiles:
      - work
      - personal
```

## Commands

```bash
ww groups list
ww groups show <group>
ww groups create <group> [profiles...]
ww groups add <group> <profiles...>
ww groups remove <group> <profiles...>
ww groups delete <group>
```

## Examples

```bash
ww groups create focus work personal
ww groups add focus client-x
ww groups show focus
ww groups list
ww groups delete focus
```

## Notes

- Group names use `A-Z`, `a-z`, `0-9`, `_`, and `-`.
- Profile names are validated. Missing profiles are still added, with a warning.
- This service only stores group membership. Future features can sync settings across profiles in a group.
