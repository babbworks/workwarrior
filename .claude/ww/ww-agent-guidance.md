# Workwarrior Agent Guidance

> CANONICAL LOCATION (pending): `~/ww/resources/agent-templates/ww-agent-guidance.md`
> Task card logged: wwdev task 4 (canonical template), task 5 (UDA inventory), task 6 (ledger inventory).
> Until those tasks are done, this file IS the reference. When canonical path exists,
> this file becomes a thin pointer to it and the resources section below activates fully.

---

## Profile Config

Read from `.claude/ww/config`:

```
WW_PROFILE=wwdev
```

All env vars derive from that one value:

```bash
TASKRC=~/ww/profiles/$WW_PROFILE/.taskrc
TIMEWDB=~/ww/profiles/$WW_PROFILE/.timewarrior
JRNL_CFG=~/ww/profiles/$WW_PROFILE/jrnl.yaml
LEDGER_F=~/ww/profiles/$WW_PROFILE/ledgers/$WW_PROFILE.journal
```

---

## Session Init (run at start of every session)

```bash
WW_PROFILE=$(cat .claude/ww/config | grep WW_PROFILE | cut -d= -f2)
TASKRC=~/ww/profiles/$WW_PROFILE/.taskrc
TIMEWDB=~/ww/profiles/$WW_PROFILE/.timewarrior
LEDGER_F=~/ww/profiles/$WW_PROFILE/ledgers/$WW_PROFILE.journal

TASKRC=$TASKRC TIMEWDB=$TIMEWDB task list
TIMEWDB=$TIMEWDB timew get dom.active
hledger -f $LEDGER_F check
```

If `~/ww/resources/` exists, also run:
```bash
# Consult cross-project UDA inventory before creating any new UDA
cat ~/ww/resources/udas/uda-inventory.md 2>/dev/null | grep -i "<candidate-name>"
# Consult cross-project ledger inventory before defining new accounts/commodities
cat ~/ww/resources/ledgers/ledger-inventory.md 2>/dev/null | grep -i "<candidate>"
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

```bash
# 1. CREATE
TASKRC=... task add "description" project:newent +tag priority:H \
  schemachange:none testcoverage:partial breakingchange:none

# 2. START  (timew auto-fires via on-modify hook)
TASKRC=... TIMEWDB=... task start <id>

# 3. ANNOTATE during work
TASKRC=... task <id> annotate "finding: ..."

# 4. UPDATE UDAs on completion
TASKRC=... task <id> modify deviations:"..." changelognote:"[YYYY-MM-DD] ..." docimpact:...

# 5. JOURNAL
jrnl --config-file ~/ww/profiles/$WW_PROFILE/jrnl.yaml "TASK-<id>: summary. @newent @done"

# 6. STOP  (timew auto-stops)
TASKRC=... TIMEWDB=... task stop <id>

# 7. LEDGER entry (see ledger-accounts.md for format)
# append to ~/ww/profiles/wwdev/ledgers/wwdev.journal

# 8. DONE
TASKRC=... task done <id>
```

---

## Parallel Sub-Agent Time Tracking

1. Record wall-clock start before spawning: `START=$(date -u +%s)`
2. `task stop <parent>` — stop parent in timew before spawning
3. Each sub-agent task gets `task start` → timew tracks independently
4. On all complete: `END=$(date -u +%s)`; compute `ELAPSED=$(( (END-START)/60 ))m`
5. `task stop <sub-a>; task stop <sub-b>`
6. `task modify <parent> timetracked:${ELAPSED}`
7. Tag all sub-agent tasks `+parallel` — excluded from aggregate totals via filter

**Rule**: `timetracked` UDA on parent = authoritative wall-clock. Sub-agent values = attribution only.

---

## UDA Reference

Before creating a new UDA:
1. Check `~/ww/resources/udas/uda-inventory.md` (cross-project inventory, pending task wwdev-5) — reuse if a match exists
2. Check this project's `uda-registry.md` — avoid duplication within project
3. Check default wwdev UDAs in `~/ww/profiles/wwdev/.taskrc`
4. Only then create a new one; add it to both `.taskrc` and `uda-registry.md` in the same pass
5. Append to `~/ww/resources/udas/uda-inventory.md` once that file exists

---

## Ledger Reference

Before defining a new account or commodity:
1. Check `~/ww/resources/ledgers/ledger-inventory.md` (cross-project inventory, pending task wwdev-6) — reuse if a match exists
2. Check this project's `ledger-accounts.md`
3. Only then define; add to `ledger-accounts.md` and journal in the same pass
4. Append to `~/ww/resources/ledgers/ledger-inventory.md` once that file exists

---

## New Project Setup (copying this template)

1. `mkdir .claude/ww`
2. Copy this folder from a project or from canonical path (once established)
3. `echo "WW_PROFILE=<profilename>" > .claude/ww/config`
4. Add `@.claude/ww/ww-agent-guidance.md` to `CLAUDE.md`
5. Add opening balance entries to the profile's ledger journal
6. Agent is fully oriented on next session open
