# Dev Instance — ww-dev

## The Three Directories

| Path | Role | Git? |
|------|------|------|
| `/Users/mp/Documents/Vaults/babb/repos/ww/` | **Repo** — where all development happens | yes |
| `~/ww-dev/` | **Dev instance** — live testing against ww-development profile | no |
| `~/wwv02/` | **Production instance** — v0.2 multi install, anchor cmd `ww`, 23 profiles | no |

`~/ww-dev/` is a deployed copy of the program files. It has its own profile data under `~/ww-dev/profiles/ww-development/` and its own installed extensions under `~/ww-dev/tools/`. It is **not** a git repo — it receives program files from the repo via the sync script.

`~/wwv02/` is the live production install (migrated from legacy `~/ww`). Registry: `~/.config/ww/registry/main.json`. GitHub package snapshot: `~/wwv02-package/` (git-initialized, 245 files).

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
bash system/scripts/dev-sync.sh --apply --target ~/wwv02
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
4. When satisfied, sync to prod  bash system/scripts/dev-sync.sh --apply --target ~/wwv02
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

## Profile Add / Delete → Update zshrc

`~/.zshrc` aliases are managed by `create_profile_aliases()` when `profile create` runs. For profiles copied manually (e.g. during migration), add the alias block by hand or re-run `profile create <name>` from within the active install.

### zshrc pattern reference (v0.2 unified — single WW_BASE=~/wwv02)

```zsh
alias p-<name>='use_task_profile <name>'
alias <name>='use_task_profile <name>'
alias j-<name>='jrnl --config-file /Users/mp/wwv02/profiles/<name>/jrnl.yaml'
alias l-<name>='hledger -f /Users/mp/wwv02/profiles/<name>/ledgers/<name>.journal'
```

The old `_p_wwd` helper and separate ww-dev alias sections are no longer needed — all profiles now live under `~/wwv02/`.

---

## Agent Instructions

At session start, always ask: **has the dev instance been synced?** If recent changes in the repo haven't been applied to `~/ww-dev/`, any live test will be running against stale code.

If a command like `ww browser warlock` fails because `services/warlock/warlock.sh` is missing from `~/ww-dev/`, the fix is always the sync script — not manually copying individual files.
