# Workwarrior Agent Guidance — Canonical Template

> This is the canonical, installable version of the agent session guidance.
> It lives at `$WW_BASE/resources/agent-templates/ww-agent-guidance.md` when installed.
> Per-project `.claude/ww/ww-agent-guidance.md` should reference this file.

---

## Profile Config

Read from `.claude/ww/config` (per-project):

```
WW_PROFILE=<profile-name>
WW_BASE=~/ww
```

All env vars derive from those values:

```bash
TASKRC=$WW_BASE/profiles/$WW_PROFILE/.taskrc
TIMEWDB=$WW_BASE/profiles/$WW_PROFILE/.timewarrior
JRNL_CFG=$WW_BASE/profiles/$WW_PROFILE/jrnl.yaml
LEDGER_F=$WW_BASE/profiles/$WW_PROFILE/ledgers/$WW_PROFILE.journal
```

---

## Session Init

Run at the start of every session:

```bash
eval "$(ww agent init --instance ~/ww --profile $WW_PROFILE)"
```

Or manually:

```bash
WW_PROFILE=$(grep WW_PROFILE .claude/ww/config | cut -d= -f2)
WW_BASE=$(grep WW_BASE .claude/ww/config | cut -d= -f2)
WW_BASE="${WW_BASE/#\~/$HOME}"
TASKRC=$WW_BASE/profiles/$WW_PROFILE/.taskrc
TIMEWDB=$WW_BASE/profiles/$WW_PROFILE/.timewarrior
LEDGER_F=$WW_BASE/profiles/$WW_PROFILE/ledgers/$WW_PROFILE.journal

TASKRC=$TASKRC task list
TIMEWDB=$TIMEWDB timew get dom.active
hledger -f $LEDGER_F check
```

If `$WW_BASE/resources/` exists, also consult the inventories:
```bash
cat $WW_BASE/resources/udas/uda-inventory.md 2>/dev/null | grep -i "<candidate>"
cat $WW_BASE/resources/ledgers/ledger-inventory.md 2>/dev/null | grep -i "<candidate>"
```

Report status before any work begins.

---

## Task Lifecycle (every task, no exceptions)

**UUID rule**: Short numeric IDs shift when other tasks complete. Resolve the UUID once,
use it for every subsequent step. Never carry a numeric ID across two commands.

```bash
UUID=$(TASKRC=... task <numeric-id> _uuid)

TASKRC=... task start $UUID           # timew auto-fires via hook
TASKRC=... task $UUID annotate "..."  # during work
TASKRC=... task $UUID modify deviations:"..." changelognote:"..."
jrnl --config-file $JRNL_CFG "TASK-<id>: summary. @$WW_PROFILE @done"
TASKRC=... task stop $UUID            # timew auto-stops
TASKRC=... task done $UUID
```

---

## Parallel Sub-Agent Tracking

1. Resolve all UUIDs before spawning (IDs can shift)
2. Stop parent: `task stop $PARENT_UUID`
3. Each sub-agent: `task start $SUB_UUID` (timew tracks independently)
4. On complete: stop all, record `timetracked` UDA on parent
5. Tag sub-agent tasks `+parallel` (excluded from aggregates)

---

## Agent Roles

See `resources/agent-templates/roles/` for the four canonical roles:
- **Orchestrator** — plans, sequences, dispatches. Never writes production code.
- **Builder** — implements. Never self-approves.
- **Verifier** — validates independently. Never implements.
- **Docs** — writes user-facing documentation from verified implementations.

The handoff sequence is non-negotiable: Orchestrator → Builder → Verifier → Docs.

---

## UDA Reference

Before creating a new UDA:
1. Check `$WW_BASE/resources/udas/uda-inventory.md` — reuse if match exists
2. Check the project's `uda-registry.md`
3. Check profile `.taskrc`
4. Only then create new; add to both `.taskrc` and `uda-registry.md`

---

## Ledger Reference

Before defining a new account or commodity:
1. Check `$WW_BASE/resources/ledgers/ledger-inventory.md` — reuse if match exists
2. Check the project's `ledger-accounts.md`
3. Only then define; add to `ledger-accounts.md` and journal in same pass

---

## New Project Setup

1. `mkdir .claude/ww`
2. Copy this guidance (or point at canonical path)
3. `printf "WW_PROFILE=<name>\nWW_BASE=~/ww\n" > .claude/ww/config`
4. Reference in project's CLAUDE.md
5. Agent is oriented on next session open
