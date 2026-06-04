# TASK-INSTALL-003 — Installer v0.2: Multi-Instance Architecture

**Status:** complete  
**Phase:** 2  
**Completed:** 2026-05-02  
**Priority:** HIGH

---

## Goal

Rebuild the installer to support a 6-preset taxonomy, multi-instance routing via `@instance` dispatch, and standalone companion activation functions. Make reliable end-to-end installation for all preset types.

---

## Acceptance Criteria (Gate A)

- [x] Six presets install without error: basic, direct, multi, hidden, isolated, hardened
- [x] `plain` deprecated with warning, falls through to basic
- [x] `configure_shell_integration` called for ALL presets (fixes bare commands missing for basic/direct)
- [x] `export WW_BASE=` present in managed rc block (fixes non-default install paths)
- [x] Reinstall without `--force` does not abort (launcher overwrite idempotent)
- [x] `ww @<instance>` activates shell context directly (no eval required) — handled by `ww()` bootstrap function
- [x] `ww @<instance> cmd...` dispatches without switching shell context
- [x] `ww pin / unpin` locks tab to instance
- [x] `instances()` bare function available after source
- [x] Default profile created as `default` (not `main`)
- [x] Multi-anchor registry isolation: each anchor owns `~/.config/<cmd>/`

---

## Scope

### Files Changed

| File | Change |
|---|---|
| `install.sh` | 6-preset menu, WW_CONFIG_HOME computed from COMMAND_NAME, Step 3 restructure, `plain` deprecation, `configure_shell_integration` for all presets, `write_instance_function` for standalone presets |
| `lib/installer-utils.sh` | `add_ww_to_shell_rc()` adds `export WW_BASE=`, `create_command_launcher()` unconditional overwrite, `write_instance_function()` new — companion activation fn for `instance-functions.sh`, `write_instance_manifest()` adds `parent_anchor`/`allowed_orchestrators` fields |
| `lib/instance-registry.sh` | `ww_instance_register()` adds optional `parent_anchor` param |
| `lib/shell-integration.sh` | `use_task_profile()` writes `last-profile-<id>` on activation; `_ww_create_instance_functions()` generates companion fns from registry at source time; `instances()` bare function added |
| `bin/ww` | `cmd_at()`, `cmd_pin()`, `cmd_unpin()`, `cmd_upgrade()`, `cmd_downgrade()` added; `@*`/`pin`/`unpin` cases in main dispatcher |
| `bin/ww-init.sh` | Sources `instance-functions.sh`; `_ww_prompt_prefix()` uses `WW_ACTIVE_INSTANCE`, adds `[pin]` marker, silent when no profile active |

### Bugs Fixed

1. **`((configured++))` with `set -e`**: `((0))` returns exit code 1, aborting install after first rc file. Fixed: `configured=$(( configured + 1 ))`.
2. **`WW_CONFIG_HOME` override not firing**: lib set default before arg parsing; `:-` operator never fired. Fixed: `WW_CONFIG_HOME_OVERRIDE` explicit env var pattern.
3. **`configure_shell_integration` not called for basic/direct**: shell functions never loaded. Fixed: called for all presets.
4. **`create_command_launcher` aborts on reinstall**: launcher exists → returns 1 → main() exits. Fixed: unconditional overwrite.
5. **`set_last_profile` undefined**: called in `use_task_profile()` but not defined. Fixed: added definition.

---

## Preset Taxonomy

| Preset | Registry | Bootstrap | Launcher | Lock |
|---|---|---|---|---|
| `basic` | ❌ | ❌ | ❌ | ❌ |
| `direct` | ❌ | ❌ | ✅ | ❌ |
| `multi` | ✅ visible | ✅ | ✅ | ❌ |
| `hidden` | ✅ hidden | ✅ | ✅ | ❌ |
| `isolated` | ❌ | ❌ | ✅ | ❌ |
| `hardened` | ✅ visible | ✅ | ✅ | ✅ |

---

## Migration

Production install migrated from `~/ww` (3 profiles) + `~/ww-dev` (19 profiles) → `~/wwv02` (23 profiles, multi preset, cmd `ww`). Shell configs cleaned and regenerated. GitHub package created at `~/wwv02-package/`.
