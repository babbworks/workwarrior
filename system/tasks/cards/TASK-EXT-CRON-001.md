## TASK-EXT-CRON-001: Integrate allgreed/cron as ww routines — stateful recurring task generator

Goal:                 Surface allgreed/cron as `ww routines` — a stateful recurring task
                      generator that creates TaskWarrior tasks from Python class definitions.
                      Smarter than native TW recurrence: handles interval rollover, auto-tags
                      with +cron, sets until: to the recurrence window.

Upstream:             https://github.com/allgreed/cron
                      Author: allgreed · Python · Active Feb 2026
                      Requires: nix (dev), Python 3 (runtime)

Profile isolation:    Writes tasks via active TASKRC/TASKDATA. Per-profile by default.
                      Routine definitions are profile-specific Python files.

--- DESIGN EXPLORATION REQUIRED (quiz operator before implementation) ---

Key design questions that need answers before a write scope can be defined:

1. ROUTINE DEFINITION LOCATION
   Where do routine definition files live?
   Option A: profiles/<name>/routines/mycron.py  (per-profile, version-controlled)
   Option B: profiles/<name>/.config/routines/   (per-profile, gitignored)
   Option C: a global routines/ dir with profile-tagged classes
   → Preference?

2. ROUTINE AUTHORING UX
   How does a user create a new routine?
   Option A: ww routines new → opens editor with a template Python file
   Option B: ww routines add "Clean room" --frequency weekly → generates the class
   Option C: user writes Python directly, ww routines just runs them
   → How much abstraction over the Python class syntax is wanted?

3. RUN TRIGGER
   When do routines execute (generate tasks)?
   Option A: ww routines run → manual trigger
   Option B: on shell init (ww-init.sh sources a routines check)
   Option C: launchd/cron job calling ww routines run --profile <name>
   → Preference? (Option B is lowest friction but adds shell init latency)

4. PROFILE SCOPE
   Should routines be per-profile only, or can global routines generate tasks
   into a specific profile?
   → Per-profile only, or global routines with --profile targeting?

5. DEPENDENCY ON NIX
   allgreed/cron uses nix for dev but the runtime is Python 3.
   Is nix acceptable as a dependency, or should ww extract just the Python
   runtime logic and vendor it?

Proposed command syntax (draft — pending design answers):
                      ww routines list              List defined routines for active profile
                      ww routines run               Generate tasks from all due routines
                      ww routines run <name>        Run a specific routine
                      ww routines new               Create a new routine definition
                      ww routines edit <name>       Edit a routine definition
                      ww routines status            Show last-run times and next-due
                      ww routines install           Install allgreed/cron runtime
                      ww routines help              Usage + attribution

Attribution:
                      Powered by allgreed/cron · allgreed
                      https://github.com/allgreed/cron · (license TBC)

Acceptance criteria:  Deferred — pending design quiz answers above.

Write scope:          TBD after design decisions.

Status:               parked — requires operator design quiz before task card can be completed
