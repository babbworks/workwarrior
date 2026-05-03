# lib/config-utils.sh

**Type:** Sourced bash library
**Used by:** `lib/profile-manager.sh`, `services/profile/`, install scripts

---

## Role

YAML config file utilities for profile-level config files (`jrnl.yaml`, `ledgers.yaml`, `.taskrc`). Handles template loading, path updates after profile moves/copies, and config validation.

---

## Functions

**`load_template(template_path)`**
Reads a YAML template file and returns its content. Used during profile creation to load default config templates from `resources/config-files/`.

**`save_template(content, dest_path)`**
Writes content to a config file. Creates parent directories if needed.

**`update_paths_in_config(config_file, old_base, new_base)`**
Replaces all occurrences of `old_base` with `new_base` in a config file. Used after profile import/restore to update absolute paths that were correct in the source profile but wrong in the destination. Critical for `.taskrc` `data.location` and journal/ledger file paths.

**`validate_taskrc(taskrc_path)`**
Checks that a `.taskrc` file has the minimum required fields: `data.location` pointing to an existing directory. Returns 1 with error message if invalid.

**`validate_jrnl_config(jrnl_yaml_path)`**
Checks that `jrnl.yaml` has at least one journal entry under the `journals:` key. Uses awk section-scoped reader to avoid matching other YAML keys named `journals`.

**`validate_ledger_config(ledgers_yaml_path)`**
Same pattern for `ledgers.yaml`.

---

## YAML Parsing Approach

No `yq` dependency — all YAML parsing uses POSIX `awk` with section-scoped readers. The awk pattern:
```awk
/^journals:/ { in_section=1; next }
in_section && /^[^ ]/ { in_section=0 }
in_section && /^  [a-zA-Z0-9_-]+:/ { ... }
```
This avoids false matches on keys that appear in other sections. The `validate_jrnl_config` fix (TASK-INSTALL-002) corrected a bug where `grep journals:` matched all YAML keys containing the word "journals", not just the section header.

## Changelog

- 2026-04-10 — Initial version
