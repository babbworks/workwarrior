## TASK-COMM-009: Warrior service — promote from stub, community management, cross-profile read

Goal:                 Implement the Warrior service (currently a README stub in
                      services/warrior/). Warrior is the global meta-profile control
                      plane. Phase 1 scope: community management commands + ability
                      to read task and journal data from any profile without shell
                      profile-switching.

Acceptance criteria:  (pending Gate A sign-off before dispatch)
                      1. services/warrior/warrior.sh implemented (Tier 3 service)
                      2. ww warrior community list — lists communities with entry counts
                      3. ww warrior community export <name> [--format html|json|md] —
                         exports community to shareable format
                      4. ww warrior profiles — lists all known profiles with their
                         TASKDATA and jrnl config paths (reads from profile registry)
                      5. ww warrior read task <profile> <uuid> — returns task data
                         from named profile without activating that profile
                      6. ww warrior read journal <profile> <date-slug> — returns
                         journal entry from named profile
                      7. lib/warrior-profile-registry.sh: maps profile names to
                         TASKDATA/jrnl paths for cross-profile reads
                      8. Browser sidebar: Warrior promoted from footer widget to
                         proper nav item; Warrior section shows community list and
                         export controls
                      9. "warrior" added to ALLOWED_SUBCOMMANDS in server.py

Write scope:          (pending Gate A)
                      services/warrior/warrior.sh (new)
                      lib/warrior-profile-registry.sh (new)
                      services/browser/server.py (warrior endpoint + ALLOWED_SUBCOMMANDS)
                      services/browser/static/index.html (Warrior nav item)
                      services/browser/static/app.js (Warrior section)

Tests required:       (pending Gate A)
                      bats tests/test-warrior.bats (new)
                      Manual: ww warrior profiles lists all profiles
                      Manual: ww warrior read task <profile> returns data without switching

Rollback:             git rm services/warrior/warrior.sh lib/warrior-profile-registry.sh
                      git checkout services/browser/

Fragility:            Medium — new lib; reads foreign profile data (read-only, low risk)
                      Do not write to foreign profile data in this task

Depends on:           TASK-COMM-001

Status:               pending
Taskwarrior:          wwdev task 10 (c1cc443f-069f-418d-8cbb-e5744d00f787) status:pending
