# lib/shortcode-registry.sh

**Type:** Sourced bash library
**Used by:** `bin/ww cmd_shortcut()`

---

## Role

Reads, displays, and manages the shortcut/alias registry. Shortcuts are defined in `config/shortcuts.yaml` (global) and can be overridden per-user in `$WW_BASE/config/shortcuts.user.yaml`. Powers `ww shortcut list/info/add/remove`.

---

## Data Source

`config/shortcuts.yaml` — global shortcut definitions. Structure:
```yaml
shortcuts:
  j:
    name: "Journal"
    category: function
    description: "Write to active profile journal"
    command: "j [journal-name] <entry>"
    requires_profile: true
  p-<name>:
    name: "Profile activation"
    category: profile
    ...
```

User overrides in `config/shortcuts.user.yaml` are merged at load time, with user entries taking precedence.

---

## Functions

**`parse_shortcuts_yaml(yaml_path)`** — Parses a shortcuts YAML file into an associative array. Uses POSIX awk (no `yq` dependency).

**`load_shortcuts()`** — Loads global shortcuts, then merges user overrides. Populates internal arrays used by display functions.

**`get_shortcuts_by_category(category)`** — Returns shortcuts filtered by category: `profile`, `function`, `service`, `global`.

**`display_shortcuts([category])`** — Formatted table output of shortcuts. `all` shows all categories; specific category name filters.

**`display_shortcuts_compact()`** — Single-line-per-shortcut compact format for quick reference.

**`display_shortcut_info(key)`** — Full detail for a single shortcut: name, category, description, command, requires_profile flag.

**`add_user_shortcut(key, name, category, description, command, requires_profile)`** — Writes a new entry to `config/shortcuts.user.yaml`. Idempotent — updates if key already exists.

**`remove_user_shortcut(key)`** — Removes an entry from `config/shortcuts.user.yaml`. Cannot remove global shortcuts (only user overrides).

---

## Categories

| Category | Examples |
|---|---|
| `profile` | `p-work`, `p-personal` — profile activation aliases |
| `function` | `j`, `l`, `task`, `timew`, `i`, `q` — shell functions |
| `service` | `ww profile`, `ww journal`, `ww gun` — ww commands |
| `global` | `search`, `list` — standalone commands |
