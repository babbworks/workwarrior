## TASK-SITE-010: Enable UDA editing from task inline detail in browser

Goal:                 When clicking a task to expand its inline detail, the user
                      should be able to add or edit UDA values. Currently UDAs
                      from the task export may not display, and there is no way
                      to add a UDA value that doesn't already exist on the task.

Acceptance criteria:  1. Expanding a task shows all existing UDA values (editable for
                         user UDAs, read-only for service UDAs)
                      2. A "add UDA" field with autocomplete from the profile's UDA
                         definitions allows adding new UDA values to the task
                      3. Saving changes sends task_modify with the UDA values
                      4. Manual test: expand a task, add a UDA value, verify with
                         `task <id> export` that the UDA is set

Write scope:          services/browser/static/app.js
                      services/browser/server.py (if new endpoint needed for UDA list)

Tests required:       Manual: expand task, add UDA, save, verify via CLI

Rollback:             git checkout services/browser/static/app.js

Fragility:            LOW

Risk notes:           (Orchestrator) The task_get action should return all fields
                      including UDAs. The renderInlineEditor function filters UDAs
                      from standard fields. Need to also provide a way to add UDAs
                      that aren't already on the task — requires fetching the UDA
                      definitions from the profile's .taskrc.

Status:               complete

Completion note:      Added GET /data/udas endpoint that reads UDA definitions from
                      profile .taskrc (excluding service UDAs). Added "add UDA" field
                      with datalist autocomplete in the inline task editor. Typing
                      surfaces matching UDAs. Enter or click adds the UDA value via
                      task_modify. Editor refreshes to show the new UDA.
