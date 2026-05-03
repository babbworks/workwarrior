## TASK-COMM-008: Task annotation copy-back — approve/deny modal + community prefix control

Goal:                 When a community comment is saved against a task entry, present
                      an approve/deny modal before executing task annotate on the
                      source task. Modal includes a toggle for community name prefix.

Acceptance criteria:  (pending Gate A sign-off before dispatch)
                      1. After submitting a comment on a task community entry, a modal
                         appears: "Copy this annotation to source task?" with
                         Approve / Deny buttons
                      2. Modal includes a toggle: "Include community name prefix"
                         (default: on). When on, annotation text prepended with
                         [community:<name>]
                      3. Approve: POST /action community_copy_annotation executes
                         task annotate on source task using correct profile's TASKRC
                      4. Deny: comment stored in community.db only, no task annotate
                      5. community_comments.copied_to_source field set on approve
                      6. If source task profile is not the current active profile,
                         Warrior service resolves the correct TASKRC path (read from
                         stored profile registry — no shell profile switch required)
                      7. Toast notification on success/failure of task annotate

Write scope:          (pending Gate A)
                      services/browser/static/app.js (modal + toast)
                      services/browser/server.py (community_copy_annotation action)
                      lib/community-db.sh (copied_to_source update)

Tests required:       (pending Gate A)
                      Manual: comment → modal → approve → verify task annotation in TW
                      Manual: comment → modal → deny → verify no TW annotation

Rollback:             git checkout services/browser/ lib/community-db.sh

Fragility:            Medium — writes to taskwarrior data; cross-profile TASKRC
                      resolution must be correct (wrong profile = wrong task DB)

Depends on:           TASK-COMM-002, TASK-COMM-009 (for cross-profile TASKRC resolution)

Status:               pending
Taskwarrior:          wwdev task 16 (65f031d7-89ee-400f-960d-754ba5f67484) status:pending
