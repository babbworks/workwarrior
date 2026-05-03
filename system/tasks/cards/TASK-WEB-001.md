## TASK-WEB-001: ww web — locally-served interactive web UI for Workwarrior

Goal:                 Build or adopt a locally-served web interface for ww that provides
                      both a simple mode (next task, quick add, today view) and an
                      advanced mode (drag-and-drop scheduling, full task management,
                      reports). Profile-isolated: serves the active profile's data only.

Upstream candidates:  A. AnotherKamila/tasksched (Elm · 40★ · 2019)
                         https://github.com/AnotherKamila/tasksched
                         Drag-and-drop scheduling calendar, next-task page with
                         TimeWarrior start/pause, bugwarrior task_url support.
                         Calls `task` CLI directly — respects TASKRC/TASKDATA.
                         Last push 2019 — needs modernisation but architecture is sound.

                      B. jonestristand/task-warlock (Next.js · TypeScript · 4★ · Feb 2026)
                         https://github.com/jonestristand/task-warlock
                         Modern web UI: 14 themes, inline editing, real-time filtering,
                         priority/urgency display, Docker support.
                         Mounts task data via volume — needs TASKRC/TASKDATA wiring.
                         Active maintenance. Better UX baseline than tasksched.

                      C. Build ww-native (recommended synthesis)
                         Use task-warlock as the UI foundation (fork/adopt) and layer
                         tasksched's scheduling calendar on top. ww owns the server
                         lifecycle and profile handoff.

Proposed architecture:
                      ww web                     Launch web UI for active profile
                      ww web --port <n>           Custom port (default: 5000)
                      ww web --mode simple        Simple mode only (next task, quick add)
                      ww web --mode advanced      Full scheduling + management UI
                      ww web install              Install dependencies (node, npm)
                      ww web help                 Usage + attribution

Simple mode features (MVP):
                      - Next task recommendation (integrates scheduler if installed)
                      - Quick add (task description + due + priority)
                      - Today view (tasks due today or started)
                      - TimeWarrior start/stop button per task

Advanced mode features:
                      - Drag-and-drop calendar scheduling (tasksched model)
                      - Full task list with inline editing (task-warlock model)
                      - Urgency/density visualisation (TWDensity if installed)
                      - Reports dashboard
                      - Profile switcher (activates different profile's data)

Profile isolation:
                      Server launched with TASKRC/TASKDATA from active profile.
                      All task CLI calls inherit these env vars.
                      Profile switcher re-launches server with new profile env.

Attribution:
                      Built on tasksched · AnotherKamila · MIT
                      https://github.com/AnotherKamila/tasksched
                      Built on task-warlock · jonestristand · MIT
                      https://github.com/jonestristand/task-warlock

Acceptance criteria:  Deferred — requires design decisions below.

Design decisions required before implementation:
                      1. Fork task-warlock or build from scratch using it as reference?
                      2. Simple/advanced as separate routes (/simple, /advanced) or
                         a toggle within one UI?
                      3. Where does the web app source live?
                         Option A: tools/web/ (alongside tools/list/)
                         Option B: services/web/ (as a ww service)
                      4. Server lifecycle: ww web launches and stays running, or
                         ww web serves one request and exits?
                      5. Authentication: none (localhost only) or optional token?

Write scope:          TBD after design decisions.

Status:               parked — requires design decisions before implementation
Taskwarrior:          wwdev task 26 (249e3fff-11c3-4b13-ae94-1aca47d3a65f) status:pending +waiting
