# task-warlock integration

Upstream: https://github.com/jonestristand/task-warlock  
Author:   jonestristand  
License:  MIT  
Stack:    Next.js 15, React, TypeScript, Tailwind CSS, shadcn/ui, TanStack Query v5  
Version:  v0.3.0  

---

## What it is

task-warlock is a full-featured graphical TaskWarrior web UI. ww adopts it as a sibling
to `ww browser` under the command `ww browser warlock` (also reachable as `ww web`).

`ww browser` (Python/Flask, port 7777) remains the primary lightweight control panel.
`ww browser warlock` (Next.js, port 5001) is an opt-in graphical task interface.

---

## Profile isolation

task-warlock's API layer (`src/lib/taskwarrior-cli.ts`) calls the TaskWarrior CLI as a
subprocess via `execa()`. `execa` inherits the parent process environment. ww sets
`TASKRC` and `TASKDATA` before launching the server — no source modification required.

    npm method:
      TASKRC="$TASKRC" TASKDATA="$TASKDATA" npm run dev -- --port 5001

    docker method:
      docker run -p 5001:3000 \
        -v "$TASKDATA":/home/nextjs/.task \
        -v "$WW_BASE/tools/warlock/settings":/home/nextjs/.taskwarlock \
        taskwarlock:v0.3.0

If a future upstream change removes env-var inheritance, add to each `execa()` call in
`src/lib/taskwarrior-cli.ts`:

    { env: { ...process.env, TASKRC: process.env.TASKRC, TASKDATA: process.env.TASKDATA } }

---

## Known: settings path differs by install method

With npm method, task-warlock writes UI settings (theme, etc.) to `~/.config/taskwarlock/settings.json` — the upstream default. The `$WW_BASE/tools/warlock/settings/` dir is only used as a docker volume mount target. This is cosmetic; task data isolation (TASKRC/TASKDATA) works correctly in both methods.

---

## Install location

    $WW_BASE/tools/warlock/source/      git clone (gitignored)
    $WW_BASE/tools/warlock/.ww-config   method, tag, port, install date
    $WW_BASE/tools/warlock/settings/    theme/UI prefs (gitignored)
    $WW_BASE/tools/warlock/server.pid   running: "<pid> <profile> <port>"
    $WW_BASE/tools/warlock/WW-PATCHES.md  isolation documentation (version-controlled)

---

## Usage

    ww browser warlock install    Clone v0.3.0 and install deps (npm or docker)
    ww browser warlock            Launch (profile confirm → start server → open browser)
    ww browser warlock start      Same as bare warlock
    ww browser warlock stop       Stop running instance
    ww browser warlock status     Show: running/stopped, profile, port, method, version
    ww browser warlock reinstall  Re-run install (update tag or switch method)
    ww browser warlock help       Usage + attribution
    ww web [subcommand]           Synonym (config/shortcuts.yaml 'web' entry)

---

## Capabilities

    CAN:
      List tasks (pending, completed, all)
      Add / edit tasks (description, project, priority, due date, tags)
      Complete and restore tasks
      Filter by project / tag / status
      Switch TaskWarrior contexts
      14 UI themes (persisted to settings/)
      TaskChampion sync

    CANNOT (known upstream gaps — out of scope for TASK-EXT-WARLOCK-001):
      Annotations
      UDA fields (ww uses these heavily — editing UDAs requires ww browser or CLI)
      Dependencies
      Delete (only complete/restore)
      TimeWarrior start/stop
      Recurring tasks (recurrence=off in Docker)

---

## Upgrade path

1. Check https://github.com/jonestristand/task-warlock for new tags.
2. Update `WARLOCK_GIT_TAG` in `services/warlock/warlock.sh`.
3. Run `ww browser warlock reinstall`.
4. Verify env-var inheritance still works; update `WW-PATCHES.md` if patching required.

---

## Attribution

This integration adopts task-warlock without modification. Profile isolation is achieved
entirely through environment variables at launch time. The generated file at
`$WW_BASE/tools/warlock/WW-PATCHES.md` documents the exact wiring for each install.

task-warlock · jonestristand · MIT License  
https://github.com/jonestristand/task-warlock
