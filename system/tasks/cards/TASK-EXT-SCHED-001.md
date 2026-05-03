## TASK-EXT-SCHED-001: Integrate ftapajos/scheduler as ww next command

Goal:                 Surface the CFS-inspired next-task selector as `ww next` —
                      recommends which task to work on based on urgency combined with
                      time already spent (via TimeWarrior), preventing high-urgency
                      tasks from monopolising all attention.

Upstream:             https://github.com/ftapajos/scheduler
                      Author: ftapajos · MIT License · Python · Active Mar 2026
                      pip install taskwarrior-scheduler

Profile isolation:    Reads TASKRC/TASKDATA and TIMEWARRIORDB — all set by ww on
                      profile activation. Zero config conflict.

Proposed command syntax:
                      ww next                    Show recommended next task
                      ww next --explain          Show urgency + time-spent breakdown
                      ww next --top <n>          Show top N candidates ranked
                      ww next install            Install taskwarrior-scheduler via pip/pipx
                      ww next help               Usage + attribution

Attribution in help:
                      Powered by taskwarrior-scheduler · ftapajos
                      https://github.com/ftapajos/scheduler · MIT License

Acceptance criteria:  1. ww next calls scheduler's `next` command with active profile env
                      2. ww next install checks for pip/pipx, installs, confirms
                      3. ww next help shows usage and full attribution
                      4. Requires active profile — errors clearly if none active
                      5. docs/taskwarrior-extensions/scheduler-integration.md written

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/system/config/command-syntax.yaml
                      /Users/mp/ww/docs/taskwarrior-extensions/scheduler-integration.md

Fragility:            SERIALIZED: bin/ww

Status:               complete

Completion note:      Implemented in commit 9106919. cmd_next() in bin/ww,
                      next domain in CSSOT, scheduler-integration.md.
                      GPL-3.0 license noted. Zero source modification.
                      19 pre-existing failures, zero regressions.
