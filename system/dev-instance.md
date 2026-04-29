# Dev Instance — ww-dev

## The Three Directories

| Path | Role | Git? |
|------|------|------|
| `/Users/mp/Documents/Vaults/babb/repos/ww/` | **Repo** — where all development happens | yes |
| `~/ww-dev/` | **Dev instance** — live testing against ww-development profile | no |
| `~/ww/` | **Production instance** — the real install | yes |

`~/ww-dev/` is a deployed copy of the program files. It has its own profile data under `~/ww-dev/profiles/ww-development/` and its own installed extensions under `~/ww-dev/tools/`. It is **not** a git repo — it receives program files from the repo via the sync script.

Config for the dev instance:
```
WW_PROFILE=ww-development
WW_BASE=~/ww-dev
```
Set in `.claude/ww/config`.

---

## Required: Sync After Every Session

**Changes made to the repo do not automatically appear in `~/ww-dev/`.** After completing any implementation work, sync program files before live testing:

```bash
# Dry-run — show what would change
bash system/scripts/dev-sync.sh

# Apply
bash system/scripts/dev-sync.sh --apply

# Sync to production (use with care — only after testing in ww-dev)
bash system/scripts/dev-sync.sh --apply --target ~/ww
```

The script (`system/scripts/dev-sync.sh`) syncs only program files:

| Synced | Not Synced |
|--------|-----------|
| `bin/` | `profiles/` — user task/time/journal/ledger data |
| `lib/` | `tools/` — installed extensions (warlock clone, etc.) |
| `services/` | `functions/` — personal data |
| `resources/` | `tests/` — dev-only test suite |
| `weapons/` | `system/` — dev control plane |
| `config/shortcuts.yaml` | `config/groups.yaml`, `ai.yaml`, `ctrl.yaml`, `models.yaml`, `projects.yaml` — user-configured |
| `config/extensions.*.yaml` | `config/cmd-heuristics*.yaml` — generated |
| `config/profile-meta-template.yaml` | `docs/`, `stories/`, `pending/` |

---

## Dev Routine (per session)

```
1. Run tests in repo             bats tests/test-smoke.bats && bats tests/
2. Sync to ww-dev                bash system/scripts/dev-sync.sh --apply
3. Live test via ww-dev          WW_BASE=~/ww-dev ww <command>
   or activate profile:          p-ww-development (if alias is set)
4. When satisfied, sync to prod  bash system/scripts/dev-sync.sh --apply --target ~/ww
```

---

## Why ww-dev Exists

The production instance (`~/ww/`) runs against real profiles (work, personal, etc.). The dev instance (`~/ww-dev/`) runs against a dedicated test profile (`ww-development`) so that development work can be live-tested without touching real task/time/journal data.

`ww browser warlock` is installed in `~/ww-dev/tools/warlock/` (not in the repo). This is intentional — the warlock source clone (~15MB) and node_modules (~200MB) are runtime artifacts, not source. The `sync.sh` script never touches `tools/`.

---

## Checking Sync State

```bash
# See what's out of date
bash system/scripts/dev-sync.sh

# Quick diff of a specific file
diff /Users/mp/Documents/Vaults/babb/repos/ww/bin/ww ~/ww-dev/bin/ww
diff /Users/mp/Documents/Vaults/babb/repos/ww/services/browser/server.py ~/ww-dev/services/browser/server.py
```

---

## Profile Rename / Add / Delete → Must Update zshrc

`~/.zshrc` is NOT auto-generated from profile directories. When any of the following happen, the zshrc ww block must be updated manually:

| Event | Required zshrc change |
|-------|----------------------|
| New profile created in `~/ww-dev/` | Add `p-<name>`, `<name>`, `j-<name>`, `l-<name>` aliases in ww-dev sections |
| New profile created in `~/ww/` | Add `p-<name>`, `<name>`, `j-<name>`, `l-<name>` aliases in production sections |
| Profile renamed in `~/ww-dev/` | Update or replace the old aliases; update `_p_wwd` calls; update `wwd()` if it was the default profile |
| Profile renamed in `~/ww/` | Update or replace the old aliases |
| Profile deleted | Remove its alias lines |

**The `wwdev` → `ww-development` rename was the missed trigger** that left dead aliases and a broken `wwd()` function.

### zshrc pattern reference

```zsh
# Production profile (~/ww):
alias p-<name>='use_task_profile <name>'
alias <name>='use_task_profile <name>'
alias j-<name>='jrnl --config-file /Users/mp/ww/profiles/<name>/jrnl.yaml'
alias l-<name>='hledger -f /Users/mp/ww/profiles/<name>/ledgers/<name>.journal'

# Dev-instance profile (~/ww-dev):
alias p-<name>='_p_wwd <name>'
alias <name>='_p_wwd <name>'
alias j-<name>='jrnl --config-file /Users/mp/ww-dev/profiles/<name>/jrnl.yaml'
alias l-<name>='hledger -f /Users/mp/ww-dev/profiles/<name>/ledgers/<name>.journal'
```

The `_p_wwd` helper (defined in zshrc) overrides `PROFILES_DIR` so `use_task_profile` resolves against `~/ww-dev/profiles` instead of `~/ww/profiles` (WW_BASE is readonly after init).

If `wwd()` has a default profile hardcoded (`--profile <name>`), update it too when the dev primary profile changes.

---

## Agent Instructions

At session start, always ask: **has the dev instance been synced?** If recent changes in the repo haven't been applied to `~/ww-dev/`, any live test will be running against stale code.

If a command like `ww browser warlock` fails because `services/warlock/warlock.sh` is missing from `~/ww-dev/`, the fix is always the sync script — not manually copying individual files.
