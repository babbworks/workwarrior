## TASK-EXT-WARLOCK-001: Adopt jonestristand/task-warlock as ww web UI foundation

Goal:                 Adopt task-warlock (Next.js web UI) as the foundation for ww's
                      web interface. Profile-isolate it via TASKRC/TASKDATA env vars.
                      This card covers adoption and profile wiring only — the full
                      ww web vision (simple/advanced modes, tasksched calendar layer)
                      is tracked in TASK-WEB-001.

Upstream:             https://github.com/jonestristand/task-warlock
                      Author: jonestristand · MIT License · TypeScript/Next.js · Feb 2026
                      14 themes, inline editing, filtering, urgency display, Docker support.

Profile isolation gap:
                      task-warlock currently mounts task data via Docker volume to a
                      hardcoded path (/home/nextjs/.task). For ww integration it needs
                      to read TASKRC and TASKDATA from environment, not a hardcoded path.
                      This requires a small source modification to the Next.js API layer.

Proposed wiring:
                      ww web (from TASK-WEB-001) launches task-warlock with:
                        TASKRC=$TASKRC
                        TASKDATA=$TASKDATA
                      task-warlock's API routes pass these to `task` CLI calls.

Scope of this card:
                      1. Fork task-warlock to tools/web/task-warlock/
                      2. Modify API layer to read TASKRC/TASKDATA from env
                         (single file change — the task CLI invocation in the API routes)
                      3. Confirm all 14 themes work with profile-scoped data
                      4. Add ww attribution comment to forked source
                      5. Document the modification in docs/taskwarrior-extensions/

Attribution:
                      Built on task-warlock · jonestristand · MIT License
                      https://github.com/jonestristand/task-warlock
                      Modified by ww: TASKRC/TASKDATA env var wiring for profile isolation

Acceptance criteria:  1. tools/web/task-warlock/ contains forked source with modification
                      2. API routes use process.env.TASKRC / process.env.TASKDATA
                      3. npm run dev with TASKRC/TASKDATA set serves correct profile data
                      4. Attribution comment in modified files
                      5. docs/taskwarrior-extensions/task-warlock-integration.md written

Write scope:          /Users/mp/ww/tools/web/task-warlock/  (new — fork)
                      /Users/mp/ww/docs/taskwarrior-extensions/task-warlock-integration.md

Fragility:            Low — new directory, no existing files modified

Depends on:           TASK-WEB-001 design decisions (where tools/web/ fits in architecture)

Status:               parked — paused by operator; revisit after TASK-WEB-001 design decisions
