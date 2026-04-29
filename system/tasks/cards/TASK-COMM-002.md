## TASK-COMM-002: Community bash CLI — services/community/ category

Goal:                 Implement the ww community CLI service category. Provides
                      create/list/add/remove/show subcommands for managing communities
                      and their entries from the command line.

Acceptance criteria:  (pending Gate A sign-off before dispatch)
                      1. ww community create <name> — creates a new community record
                      2. ww community list — lists all communities with entry counts
                      3. ww community add <name> task <uuid> — adds a task entry
                      4. ww community add <name> journal <date-slug> — adds a journal entry
                      5. ww community show <name> — lists all entries in a community
                      6. ww community remove <name> <entry-id> — removes an entry
                      7. ww community export <name> — delegates to Warrior export (COMM-009)
                      8. All subcommands respond to --help with usage and example
                      9. Exit codes: 0 success, 1 user error, 2 system error

Write scope:          (pending Gate A)
                      services/community/ (new directory)
                      services/community/community.sh (new)

Tests required:       (pending Gate A)
                      bats tests/test-community-cli.bats (new)
                      bats tests/test-service-discovery.sh

Rollback:             git rm -r services/community/

Fragility:            Low — new service category, no existing files modified

Depends on:           TASK-COMM-001

Status:               complete — 2026-04-22
Taskwarrior:          wwdev task 9 (64828c09-8636-417b-b411-fdb450a95c09) status:completed
