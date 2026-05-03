# Workwarrior Agent Guidance

> CANONICAL LOCATION (pending): `$WW_BASE/resources/agent-templates/ww-agent-guidance.md`
> Task card logged: wwdev task 4 (canonical template), task 5 (UDA inventory), task 6 (ledger inventory).
> Until those tasks are done, this file IS the reference. When canonical path exists,
> this file becomes a thin pointer to it and the resources section below activates fully.

---

## Profile Config

Read from `.claude/ww/config`:

```
WW_PROFILE=ww-development
WW_BASE=~/ww-dev
```

All env vars derive from those values:

```bash
TASKRC=$WW_BASE/profiles/$WW_PROFILE/.taskrc
TIMEWDB=$WW_BASE/profiles/$WW_PROFILE/.timewarrior
JRNL_CFG=$WW_BASE/profiles/$WW_PROFILE/jrnl.yaml
LEDGER_F=$WW_BASE/profiles/$WW_PROFILE/ledgers/$WW_PROFILE.journal
```

---

## Session Init (run at start of every session)

```bash
WW_PROFILE=$(cat .claude/ww/config | grep WW_PROFILE | cut -d= -f2)
WW_BASE=$(cat .claude/ww/config | grep WW_BASE | cut -d= -f2)
WW_BASE="${WW_BASE/#\~/$HOME}"
TASKRC=$WW_BASE/profiles/$WW_PROFILE/.taskrc
TIMEWDB=$WW_BASE/profiles/$WW_PROFILE/.timewarrior
LEDGER_F=$WW_BASE/profiles/$WW_PROFILE/ledgers/$WW_PROFILE.journal

TASKRC=$TASKRC TIMEWDB=$TIMEWDB task list
TIMEWDB=$TIMEWDB timew get dom.active
hledger -f $LEDGER_F check
```

If `$WW_BASE/resources/` exists, also run:
```bash
# Consult cross-project UDA inventory before creating any new UDA
cat $WW_BASE/resources/udas/uda-inventory.md 2>/dev/null | grep -i "<candidate-name>"
# Consult cross-project ledger inventory before defining new accounts/commodities
cat $WW_BASE/resources/ledgers/ledger-inventory.md 2>/dev/null | grep -i "<candidate>"
```

Report status before any work begins.

---

## Engaging work: task cards and the WW record

Substantive work **starts and ends with a task card** (the unit of commitment). When a task is **engaged for work in this repo**, assume the **full Workwarrior process** (Taskwarrior, Timewarrior hooks, jrnl, ledger) is in play. Only **minor exceptions** skip tooling; the default is always-on WW.

**Mid-session discoveries** (extra tweaks, follow-ups, supplementary fixes uncovered while executing a card):

- **Journal (jrnl)** — always: capture what changed, why, and links to the active `TASK-<id>` context.
- **Ledger (hledger)** — always: post the session’s economic / bookkeeping shape per `ledger-accounts.md`.
- **Taskwarrior** — the **primary narrative** for AI work: `annotate`, `modify`, UDAs, and **new quick tasks** when a distinct thread deserves its own row. Prefer this depth over scattering one-line “chore” cards through `system/TASKS.md` or the main orchestration routines.

Orchestrator-owned **system** task cards stay for real board-level work; let WW hold the fuller trace of agent actions and small spin-offs.

---

## Task Lifecycle (every task, no exceptions)

**UUID rule**: TaskWarrior short numeric IDs shift whenever other tasks complete. They are
display-only. **Always resolve the UUID before starting any lifecycle operation**, then use
the UUID for every subsequent step. Never carry a numeric ID across two separate commands.

```bash
# 0. RESOLVE UUID — do this once, before anything else
#    Use the numeric ID only here; use $UUID for every step below.
UUID=$(TASKRC=... task <numeric-id> _uuid)
# Verify you have the right task:
TASKRC=... task $UUID

# 1. CREATE
TASKRC=... task add "description" project:ww-development +tag priority:H \
  schemachange:none testcoverage:partial breakingchange:none
# Then immediately resolve UUID as above.

# 2. START  (timew auto-fires via on-modify hook)
TASKRC=... TIMEWDB=... task start $UUID

# 3. ANNOTATE during work
TASKRC=... task $UUID annotate "finding: ..."

# 4. UPDATE UDAs on completion
TASKRC=... task $UUID modify deviations:"..." changelognote:"[YYYY-MM-DD] ..." docimpact:...

# 5. JOURNAL
jrnl --config-file $WW_BASE/profiles/$WW_PROFILE/jrnl.yaml "TASK-<card-id>: summary. @ww-development @done"

# 6. STOP  (timew auto-stops)
TASKRC=... TIMEWDB=... task stop $UUID

# 7. LEDGER entry (see ledger-accounts.md for format)
# append to $WW_BASE/profiles/$WW_PROFILE/ledgers/$WW_PROFILE.journal

# 8. DONE
TASKRC=... task done $UUID
```

**Why**: completing any task renumbers all remaining short IDs. Starting task "9" before
closing tasks 11 and 12 is safe; doing it after risks operating on a different task entirely.
UUID is the only stable reference across the full lifecycle.

---

## Parallel Sub-Agent Time Tracking

Resolve all UUIDs before spawning — IDs can shift while sub-agents run.

1. Resolve UUIDs: `PARENT_UUID=$(TASKRC=... task <id> _uuid)`
2. Record wall-clock start: `START=$(date -u +%s)`
3. `task stop $PARENT_UUID` — stop parent in timew before spawning
4. Each sub-agent task: resolve UUID, then `task start $UUID` → timew tracks independently
5. On all complete: `END=$(date -u +%s)`; compute `ELAPSED=$(( (END-START)/60 ))m`
6. `task stop $SUB_A_UUID; task stop $SUB_B_UUID`
7. `task modify $PARENT_UUID timetracked:${ELAPSED}`
8. Tag all sub-agent tasks `+parallel` — excluded from aggregate totals via filter

**Rule**: `timetracked` UDA on parent = authoritative wall-clock. Sub-agent values = attribution only.

---

## UDA Reference

Before creating a new UDA:
1. Check `$WW_BASE/resources/udas/uda-inventory.md` (cross-project inventory, pending task wwdev-5) — reuse if a match exists
2. Check this project's `uda-registry.md` — avoid duplication within project
3. Check default ww-development UDAs in `$WW_BASE/profiles/ww-development/.taskrc`
4. Only then create a new one; add it to both `.taskrc` and `uda-registry.md` in the same pass
5. Append to `$WW_BASE/resources/udas/uda-inventory.md` once that file exists

---

## Ledger Reference

Before defining a new account or commodity:
1. Check `$WW_BASE/resources/ledgers/ledger-inventory.md` (cross-project inventory, pending task wwdev-6) — reuse if a match exists
2. Check this project's `ledger-accounts.md`
3. Only then define; add to `ledger-accounts.md` and journal in the same pass
4. Append to `$WW_BASE/resources/ledgers/ledger-inventory.md` once that file exists

---

## Pushing Code Changes to ww-dev Install

After editing code in `babb/repos/ww`, push to the dev runtime without reinstalling:

```bash
cd /Users/mp/Documents/Vaults/babb/repos/ww
WW_INSTALL_DIR=~/ww-dev ./install.sh --force
```

This copies `bin/`, `lib/`, `scripts/`, `services/`, `resources/`, `config/`, `functions/`, `tools/`, `system/` — **never touches `profiles/`**. The browser picks up changes on next page reload.

---

## New Project Setup (copying this template)

1. `mkdir .claude/ww`
2. Copy this folder from a project or from canonical path (once established)
3. `printf "WW_PROFILE=<profilename>\nWW_BASE=~/ww-dev\n" > .claude/ww/config`
4. Add `@.claude/ww/ww-agent-guidance.md` to `CLAUDE.md`
5. Add opening balance entries to the profile's ledger journal
6. Agent is fully oriented on next session open
