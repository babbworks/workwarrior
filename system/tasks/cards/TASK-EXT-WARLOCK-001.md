## TASK-EXT-WARLOCK-001: ww browser warlock — adopt task-warlock as sibling web UI

---

### Goal

Adopt jonestristand/task-warlock (Next.js 15 web UI for TaskWarrior) as a sibling tool
to `ww browser`, accessible as `ww browser warlock`. task-warlock provides a full-featured
graphical task management interface: inline editing, 14 themes, filtering, urgency display,
and context switching. It runs locally, serves one profile at a time, and talks directly to
the `task` CLI — the same data files as every other ww tool.

`ww web` is registered as a synonym via the shortcuts service and routes to
`ww browser warlock`. The alias can be removed later without code changes beyond two
deletions (shortcuts.yaml entry + dispatcher case).

---

### Upstream

    Source:     https://github.com/jonestristand/task-warlock
    Author:     jonestristand
    License:    MIT
    Stack:      Next.js 15, React, TypeScript, Tailwind CSS, shadcn/ui, TanStack Query v5
    Version:    v0.3.0 (latest tagged release — always install from a tag, never HEAD)
    Last push:  Feb 2026 (active maintenance)

---

### Architecture decision: sibling, not replacement

`ww browser` (Python/Flask, port 7777) remains the primary lightweight control panel.
`ww browser warlock` (Next.js, port 5001) is an opt-in graphical task UI. They serve
different purposes and coexist. Neither replaces the other.

---

### Profile isolation — no source patch required

All of task-warlock's task operations call `execa('task', [...])` (Node.js subprocess).
`execa` inherits the parent process environment. Therefore, setting TASKRC and TASKDATA
in the shell that launches the server is sufficient — no TypeScript source modification needed.

    npm method:     TASKRC="$TASKRC" TASKDATA="$TASKDATA" npm run dev -- --port 5001
    docker method:  docker run -p 5001:3000 \
                      -v "$TASKDATA":/home/nextjs/.task \
                      -v "$WW_BASE/tools/warlock/settings":/home/nextjs/.taskwarlock \
                      taskwarlock:v0.3.0

If a future task-warlock update changes the API layer in a way that breaks env var
inheritance, a source patch will be required. The patch approach is: minimal sed/patch
to `src/lib/taskwarrior-cli.ts` line(s) that invoke `execa`, prepending
`{ env: { TASKRC: process.env.TASKRC, TASKDATA: process.env.TASKDATA } }` to the options
argument. Document in WW-PATCHES.md alongside the clone.

---

### Clone and install location

    $WW_BASE/tools/warlock/source/     — git clone (on-demand, not in repo)
    $WW_BASE/tools/warlock/.ww-config  — chosen method, port, git tag, install date
    $WW_BASE/tools/warlock/settings/   — persisted theme/UI prefs (docker volume mount)
    $WW_BASE/tools/warlock/WW-PATCHES.md — generated at install time, details isolation approach

tools/warlock/ is created at install time. Add to .gitignore:
    tools/warlock/source/
    tools/warlock/settings/

WW-PATCHES.md is version-controlled (it's documentation, not generated data).

---

### Port allocation

    ww browser             7777   (existing Python UI — unchanged)
    ww browser warlock     5001   (this card)
    Next service           5002   (increment from here)

---

### Install flow — `ww browser warlock install`

Nothing executes before user confirmation. Full flow:

    1. PRE-FLIGHT DISCLOSURE
       ─────────────────────
       Warlock is a Next.js web UI for TaskWarrior.
       Upstream: https://github.com/jonestristand/task-warlock (jonestristand, MIT)

       This will:
         • Clone the repository to $WW_BASE/tools/warlock/source/  (~15MB)
         • Install dependencies                                     (~200MB npm  OR  docker build ~500MB)
         • NOT touch your profile data (read-only access at runtime)

       Choose install method:
         [1] npm    (requires Node.js 22+)
         [2] docker (requires Docker Desktop running)
         [q] quit

    2. DEPENDENCY CHECK
       npm path:    node --version ≥ 22, npm present
       docker path: docker info succeeds (daemon running)
       Fail fast with install hint if check fails.

    3. ALREADY-INSTALLED DETECTION
       If $WW_BASE/tools/warlock/.ww-config exists:
         Warlock already installed (method: <npm|docker>, version: v0.3.0, date: YYYY-MM-DD)
           [1] Reinstall / update to latest tag
           [2] Switch method (npm ↔ docker)
           [q] cancel

    4. CLONE
       git clone --branch v0.3.0 --depth 1 \
         https://github.com/jonestristand/task-warlock \
         "$WW_BASE/tools/warlock/source"

    5. GENERATE WW-PATCHES.md
       Written to $WW_BASE/tools/warlock/WW-PATCHES.md
       Content: upstream citation, MIT license acknowledgement,
       isolation approach (env-var inheritance), confirmation no source files modified.

    6. INSTALL DEPENDENCIES
       npm path:    cd source && npm install
       docker path: cd source && docker build -t taskwarlock:v0.3.0 .

    7. WRITE .ww-config
       method=npm|docker
       tag=v0.3.0
       port=5001
       installed=YYYY-MM-DD

    8. DONE MESSAGE
       "Warlock installed. Run: ww browser warlock [start]"
       "Documentation: ww browser warlock help"

---

### Profile selection at launch — `ww browser warlock [start]`

When the user runs `ww browser warlock` or `ww browser warlock start`:

    If exactly one profile is active (WARRIOR_PROFILE set):
      → confirm prompt: "Launch warlock for profile '<name>'? [Y/n]"
      → proceed on Y or Enter

    If no profile is active:
      → list available profiles
      → "Which profile should warlock serve? [profile name]: "
      → user types profile name
      → resolve $TASKRC/$TASKDATA for that profile and launch

    If a warlock instance is already running:
      → "Warlock already running (profile: <name>, port: 5001)"
      → "Restart with different profile? [y/N]"
      → on Y: stop existing, re-launch with new profile

    Profile name + port written to PID file for status display.

---

### PID management

    PID file:   $WW_BASE/tools/warlock/server.pid
    Contents:   <pid> <profile-name> <port>
    Used by:    warlock status, warlock stop, launch conflict detection

---

### Command surface

    ww browser warlock                 Launch (profile confirm → start server)
    ww browser warlock install         Clone, patch, install (npm or docker)
    ww browser warlock start           Same as bare warlock
    ww browser warlock stop            Stop running instance
    ww browser warlock status          Show: running/stopped, profile, port, method, version
    ww browser warlock reinstall       Re-run install (update tag or switch method)
    ww browser warlock help            Usage + full attribution + patch notes summary

    ww web [subcommand]                Synonym — routes to ww browser warlock via:
                                         config/shortcuts.yaml  (web entry)
                                         bin/ww dispatcher      (web) case → cmd_browser warlock)

---

### What warlock can and cannot do

    CAN:
      List tasks (pending, completed, all)          ✓
      Add tasks (description, project, priority,    ✓
                 due date, tags)
      Edit tasks inline (same fields)               ✓
      Complete and restore tasks                    ✓
      Filter by project / tag / status              ✓
      Switch TaskWarrior contexts                   ✓
      14 UI themes (persisted to settings/)         ✓
      TaskChampion sync                             ✓

    CANNOT (known gaps — out of scope for this card):
      Annotations                                   ✗  (not exposed in warlock UI)
      UDA fields                                    ✗  (ww uses these heavily)
      Dependencies                                  ✗
      Delete (only complete/restore)                ✗
      TimeWarrior start/stop                        ✗
      Recurring tasks (recurrence=off in Docker)    ✗

    Gaps are documented in docs/taskwarrior-extensions/task-warlock-integration.md.
    They are candidates for TASK-WEB-001 (full web vision), not this card.

---

### Attribution surfaces

    1. ww browser warlock help
       Footer line always present:
       "Powered by task-warlock · jonestristand · MIT · https://github.com/jonestristand/task-warlock"

    2. ww browser (existing Python UI) — sidebar panel "Warlock"
       Status badge:  Not installed | Stopped | Running on :5001 — profile: <name>
       Buttons:       Install | Start | Stop  (context-sensitive)
       Link:          "Open Warlock →"  (shown only when running)
       Credit line:   "task-warlock by jonestristand (MIT)"  (always visible, linked)

    3. WW-PATCHES.md (generated at $WW_BASE/tools/warlock/WW-PATCHES.md)
       Full upstream citation + isolation approach documentation.

    4. docs/taskwarrior-extensions/task-warlock-integration.md
       Permanent repo documentation: upstream, modification approach, usage, gaps, upgrade path.

---

### Patch documentation — WW-PATCHES.md template

Generated content at install time:

    # ww modifications to task-warlock
    # Generated by: ww browser warlock install
    # Install date: <date>
    # Tag: v0.3.0

    Upstream: https://github.com/jonestristand/task-warlock
    Author:   jonestristand
    License:  MIT

    ## Profile isolation approach

    task-warlock's API layer (src/lib/taskwarrior-cli.ts) calls the TaskWarrior
    CLI as a subprocess via execa(). The execa library inherits the Node.js
    process environment. ww launches the warlock server with TASKRC and TASKDATA
    set to the active profile's paths; all downstream task CLI calls inherit them.

    No source files were modified. This file documents the wiring, not a patch.

    npm launch:
      TASKRC="<path>" TASKDATA="<path>" npm run dev -- --port 5001

    docker launch:
      docker run -p 5001:3000 \
        -v "<TASKDATA>":/home/nextjs/.task \
        -v "<settings-dir>":/home/nextjs/.taskwarlock \
        taskwarlock:v0.3.0

    If a future upstream change breaks env var inheritance, the required patch is:
    In src/lib/taskwarrior-cli.ts, add to each execa() call:
      { env: { ...process.env, TASKRC: process.env.TASKRC, TASKDATA: process.env.TASKDATA } }

---

### Write scope

    SERIALIZED:
      bin/ww
        — add warlock) branch in cmd_browser()
        — add web) case in main dispatcher → cmd_browser warlock "$@"
        — cmd_browser_warlock_install(), cmd_browser_warlock_start(),
          cmd_browser_warlock_stop(), cmd_browser_warlock_status() functions

    LOW RISK (new file):
      services/warlock/warlock.sh
        — install/clone/patch/dep-install logic
        — start/stop/status/pid management
        — profile-selection prompt
        — WW-PATCHES.md generation

    LOW RISK (existing files, additive):
      config/shortcuts.yaml
        — add 'web' entry pointing to 'ww browser warlock'
      services/browser/static/index.html
        — warlock panel section in sidebar
      services/browser/static/app.js
        — warlock status fetch + install/start/stop controls
      services/browser/server.py
        — /data/warlock/status endpoint (reads PID file)
      services/browser/static/style.css
        — warlock panel styles (minimal, matches existing sidebar pattern)

    NEW FILES:
      docs/taskwarrior-extensions/task-warlock-integration.md
        — permanent documentation (attribution, approach, usage, gaps, upgrade)
      tools/warlock/WW-PATCHES.md
        — generated at install time, version-controlled template lives in services/warlock/

    .gitignore additions:
      tools/warlock/source/
      tools/warlock/settings/

---

### Fragility assessment

    bin/ww               SERIALIZED — one writer, no parallel agents
    services/warlock/    LOW — new file, no existing code affected
    config/shortcuts.yaml LOW — additive entry
    browser static files  LOW — additive panel, no changes to existing panels
    server.py             LOW — new endpoint only

---

### Dependencies / blockers

    Blocked by:      Nothing — design decisions resolved.
    Informs:         TASK-WEB-001 (full web vision — warlock is the UI foundation)
    Synonym removal: When 'ww web' alias is retired, delete:
                       config/shortcuts.yaml 'web' entry
                       bin/ww 'web)' dispatcher case

---

### Acceptance criteria

    1. ww browser warlock install
       — Runs pre-flight disclosure before any action
       — Prompts for npm or docker
       — Detects and handles already-installed case
       — Clones v0.3.0 (--depth 1)
       — Generates WW-PATCHES.md at tools/warlock/WW-PATCHES.md
       — Installs deps (npm install OR docker build)
       — Writes .ww-config

    2. ww browser warlock [start]
       — Profile-selection prompt (confirm active profile or choose from list)
       — Conflict detection if already running
       — Starts server on port 5001 with correct TASKRC/TASKDATA
       — Writes PID file with profile name

    3. ww browser warlock stop
       — Reads PID file, kills process, removes PID file
       — Graceful on already-stopped

    4. ww browser warlock status
       — Shows: running/stopped, profile name, port, install method, tag, install date

    5. ww web <args>
       — Routes identically to ww browser warlock <args>
       — ww shortcut list shows 'web' entry

    6. ww browser (Python UI) sidebar
       — Warlock panel present with status badge
       — Install / Start / Stop button context-sensitive
       — "Open Warlock →" link shown when running
       — Attribution credit line always visible

    7. ww browser warlock help
       — Attribution footer present
       — All subcommands listed

    8. docs/taskwarrior-extensions/task-warlock-integration.md
       — Written and complete (upstream, isolation, usage, gaps, upgrade path)

    9. All existing ww browser tests pass (no regression)
       — bats tests/ green

---

### Tests required

    bats tests/test-browser-warlock.bats   (new)
      — install detects missing node/docker and fails cleanly
      — install writes .ww-config
      — start writes PID file
      — stop removes PID file
      — status reads PID file correctly
      — ww web routes to warlock

    bats tests/test-shortcuts.bats         (existing — add web synonym case)

    Manual smoke:
      ww browser warlock install (npm path)
      ww browser warlock start   (profile prompt)
      navigate to localhost:5001  (UI loads, shows correct profile's tasks)
      ww browser warlock stop

---

### Status

Status:           complete — 2026-04-24
Taskwarrior:      ww-development (mark task 21 / uuid 0e9cbfae done)
Notes:            All acceptance criteria met. warlock.sh, server.py endpoint,
                  browser sidebar panel, docs, and 25-test bats suite all complete.
                  Manual smoke test (ww browser warlock install + live UI) pending operator.
