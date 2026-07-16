# Dev Instance — ww-dev

## The Three Directories

| Path | Role | Git? |
|------|------|------|
| `~/Documents/Vaults/babb/repos/ww/` | **Repo** — where all development happens | yes |
| `~/ww/` | **Dev instance** — live testing against ww-development profile | no |
| `~/ww/` | **Production instance** — v0.2 multi install, anchor cmd `ww`, 23 profiles | no |

`~/ww/` is a deployed copy of the program files. It has its own profile data under `~/ww/profiles/ww-development/` and its own installed extensions under `~/ww/tools/`. It is **not** a git repo — it receives program files from the repo via the sync script.

`~/ww/` is the live production install (migrated from legacy `~/ww`). Registry: `~/.config/ww/registry/main.json`. GitHub package snapshot: `~/ww/` (git-initialized, 245 files).

Config for the dev instance:
```
WW_PROFILE=ww-development
WW_BASE=~/ww
```
Set in `.claude/ww/config`.

---

## Required: Sync After Every Session

**Changes made to the repo do not automatically appear in `~/ww/`.** After completing any implementation work, sync program files before live testing:

```bash
# Dry-run — show what would change
bash dev/scripts/dev-sync.sh

# Apply to default target (~/ww)
bash dev/scripts/dev-sync.sh --apply

# Sync to ww-dev explicitly
bash dev/scripts/dev-sync.sh --apply --target ~/ww
```

The script (`dev/scripts/dev-sync.sh`) syncs only program files:

| Synced | Not Synced |
|--------|-----------|
| `bin/` | `profiles/` — user task/time/journal/ledger data |
| `lib/` | `tools/` — installed extensions (warlock clone, etc.) |
| `services/` | `functions/` — personal data |
| `resources/` | `dev/tests/` — dev-only test suite |
| `weapons/` | `dev/` — dev control plane |
| `config/shortcuts.yaml` | `config/groups.yaml`, `ai.yaml`, `ctrl.yaml`, `models.yaml`, `projects.yaml` — user-configured |
| `config/extensions.*.yaml` | `config/cmd-heuristics*.yaml` — generated |
| `config/profile-meta-template.yaml` | `docs/`, `stories/`, `pending/` |

---

## Dev Routine (per session)

```
1. Session init                  eval "$(ww agent init --instance ~/ww --profile ww-development)"
2. Check sync state              bash dev/scripts/dev-sync.sh
3. Run tests in repo             bats dev/tests/test-smoke.bats && bats dev/tests/
4. Sync to install                 bash dev/scripts/dev-sync.sh --apply
5. Live test                     WORKWARRIOR_BASE=~/ww ww <command>
   or activate profile:          p-ww-development (if alias is set)
6. Sync to ww-dev if needed      bash dev/scripts/dev-sync.sh --apply --target ~/ww
```

---

## Why ww-dev Exists

The production instance (`~/ww/`) runs against real profiles (work, personal, etc.). The dev instance (`~/ww/`) runs against a dedicated test profile (`ww-development`) so that development work can be live-tested without touching real task/time/journal data.

`ww browser warlock` is installed in `~/ww/tools/warlock/` (not in the repo). This is intentional — the warlock source clone (~15MB) and node_modules (~200MB) are runtime artifacts, not source. The `sync.sh` script never touches `tools/`.

---

## Checking Sync State

```bash
# See what's out of date
bash dev/scripts/dev-sync.sh

# Quick diff of a specific file
diff ~/Documents/Vaults/babb/repos/ww/bin/ww ~/ww/bin/ww
diff ~/Documents/Vaults/babb/repos/ww/services/browser/server.py ~/ww/services/browser/server.py
```

---

## Profile Add / Delete → Update zshrc

`~/.zshrc` aliases are managed by `create_profile_aliases()` when `profile create` runs. For profiles copied manually (e.g. during migration), add the alias block by hand or re-run `profile create <name>` from within the active install.

### zshrc pattern reference (v0.2 unified — single WW_BASE=~/ww)

```zsh
alias p-<name>='use_task_profile <name>'
alias <name>='use_task_profile <name>'
alias j-<name>='jrnl --config-file ~/ww/profiles/<name>/jrnl.yaml'
alias l-<name>='hledger -f ~/ww/profiles/<name>/ledgers/<name>.journal'
```

The old `_p_wwd` helper and separate ww-dev alias sections are no longer needed — all profiles now live under `~/ww/`.

---

## Agent Instructions

At session start:
1. Run `eval "$(ww agent init --instance ~/ww --profile ww-development)"` — confirms instance, exports all env vars
2. Run `bash dev/scripts/dev-sync.sh` — dry-run to check sync state before live testing

If recent changes in the repo haven't been applied to the target instance, any live test will be running against stale code. The fix is always the sync script — not manually copying individual files.
