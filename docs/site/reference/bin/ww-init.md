# bin/ww-init.sh — Shell Bootstrap

**Type:** Sourced bash script (not executed)
**Sourced by:** `~/.bashrc` and/or `~/.zshrc` at shell start
**Guard:** `[[ -n "${WW_INITIALIZED:-}" ]] && return 0`

---

## Role

Single bootstrap file that initialises the ww environment in a new shell session. Sets `WW_BASE`, adds `bin/` to `PATH`, sources core libraries, restores the last active profile, and makes all shell functions available. Everything a user needs to interact with ww is set up here.

---

## Startup Sequence

```
source ~/.bashrc
  → source $WW_BASE/bin/ww-init.sh
    1. Guard check — return if already loaded
    2. Set WW_BASE (default: $HOME/ww)
    3. Add $WW_BASE/bin to PATH
    4. Source lib/core-utils.sh
    5. Source lib/shell-integration.sh  ← injects all shell functions
    6. Restore last active profile (get_last_profile → use_task_profile)
    7. Export WW_INITIALIZED=1
```

---

## Re-source Safety

The `WW_INITIALIZED` guard at the top ensures `source ~/.bashrc` (a normal user action) does not re-run the init sequence, re-inject functions, or cause "readonly variable" errors. The guard variable is never `readonly`.

---

## Last Profile Restoration

On shell start, `ww-init.sh` reads `$WW_BASE/.state/last_profile` and calls `use_task_profile()` to restore the profile that was active in the previous session. This means opening a new terminal automatically activates the last-used profile — no manual `p-<name>` required.

If no last profile exists (fresh install), the shell starts with no profile active.

---

## PATH Management

`$WW_BASE/bin` is prepended to `PATH` only if not already present (idempotent check). This makes `ww`, `profile`, `export`, `custom`, and `x` available as bare commands.

## Changelog

- 2026-04-10 — Initial version
