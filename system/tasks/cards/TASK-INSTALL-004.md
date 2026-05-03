# TASK-INSTALL-004 — Per-Anchor Bootstrap Guard

**Status:** complete
**Phase:** 2
**Completed:** 2026-05-02
**Priority:** HIGH

---

## Goal

Fix `WW_BOOTSTRAP_LOADED` being a single global, which prevents multiple multi-instance anchors from coexisting in one shell. The second anchor's bootstrap silently returns early — its routing function is never defined.

---

## Acceptance Criteria

- [x] Each anchor's bootstrap uses a guard variable keyed to its command name: `WW_BOOTSTRAP_LOADED_WW`, `WW_BOOTSTRAP_LOADED_HUB`, etc.
- [x] Two anchors sourced in the same shell both define their routing functions
- [x] Hyphens in command names are normalized to underscores in the guard variable
- [x] Live `~/.config/ww/bootstrap.sh` updated to match

---

## Dependencies

- TASK-INSTALL-003 (complete) — established the bootstrap template in `configure_multi_bootstrap()`

## Note on `WW_INITIALIZED`

`ww-init.sh` keeps its single global guard. All instances share the same codebase so the first load wins — shell-integration.sh functions are identical regardless of which anchor loads them. Not a blocking issue.

---

## Files Changed

| File | Change |
|---|---|
| `install.sh` | `configure_multi_bootstrap()`: guard var computed as `WW_BOOTSTRAP_LOADED_<CMD>` (uppercased, hyphens→underscores) |
| `~/.config/ww/bootstrap.sh` | Guard updated to `WW_BOOTSTRAP_LOADED_WW` |
