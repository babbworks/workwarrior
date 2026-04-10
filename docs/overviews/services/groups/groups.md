# services/groups/groups.sh

**Type:** Executed service script
**Invoked by:** `ww group <action>`
**Subservient to:** Groups service (`services/groups/`)

---

## Role

Profile group management. Groups are named collections of profiles used to run operations across multiple profiles simultaneously (e.g. `ww group urgency set focus due 10.0` applies to all profiles in the `focus` group).

---

## Data Store

Groups are stored in `$WW_BASE/config/groups.yaml`:
```yaml
groups:
  focus:
    profiles: [work, personal]
    description: "Active work contexts"
  babb:
    profiles: [babb, john, mark]
    description: "Babb Works team profiles"
```

---

## Functions

**`ensure_groups_config()`** — Creates `config/groups.yaml` with empty `groups:` section if it doesn't exist.

**`validate_group_name(name)`** — Alphanumeric + hyphens/underscores, 1–50 chars.

**`group_exists(name)`** — Returns 0 if group is defined in `groups.yaml`.

**`list_groups()`** — Lists all groups with member count and description.

**`show_group(name)`** — Lists profiles in a group with their activation status.

**`create_group(name, [profiles...])`** — Creates a new group. Validates all profile names exist before writing.

**`add_to_group(name, profiles...)`** — Adds profiles to an existing group. Deduplicates.

**`remove_from_group(name, profiles...)`** — Removes profiles from a group. Does not delete the group if it becomes empty.

**`delete_group(name)`** — Removes the group entry from `groups.yaml`. Does not affect the profiles themselves.

---

## Group Operations

Groups enable cross-profile operations in other services:
- `ww group urgency set <group> <factor> <value>` — applies urgency coefficient to all member profiles
- Future: `ww group sync <group>` — sync all member profiles
- Future: `ww group export <group>` — export data from all member profiles

The groups service itself only manages membership — it does not execute operations on members.
