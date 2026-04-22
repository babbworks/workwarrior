# Task Card Template

Copy this template for every new task. All 9 fields are required before a Builder can be dispatched (Gate A).

Orchestrator fills in all fields before dispatch. Builder fills in `Risk notes` before touching any file. Orchestrator updates `Status` and `Taskwarrior`.

---

```
## TASK-XXX: [Title — verb phrase, specific]

Goal:                 [One sentence. What problem does this solve or what capability does it add?]

Acceptance criteria:  [Measurable conditions. Each one must be verifiable as pass/fail.
                      Use numbered list for multiple criteria:
                      1. [criterion]
                      2. [criterion]
                      Use specific commands, file checks, or behavior descriptions.]

Write scope:          [Exact files the Builder is permitted to modify. One per line.
                      No glob patterns unless genuinely required — be specific.
                      /path/to/file1
                      /path/to/file2]

Tests required:       [Specific test commands to run, not categories.
                      bats tests/test-foo.sh
                      ./tests/run-integration-tests.sh
                      Manual: ww <command> and verify output]

Rollback:             [Exact steps to undo this change if it fails.
                      git checkout <files>
                      git rm --cached <files>
                      Restore from backup at <location>]

Fragility:            [None / or list relevant fragility flags:
                      HIGH FRAGILITY: <files> — requires Orchestrator approval
                      SERIALIZED: <files> — confirm no parallel active task touches these]

Risk notes:           [ORCHESTRATOR fills in: known risks from Explorer output or prior knowledge.
                      BUILDER fills in: pre-flight risk brief before touching any file.
                      Format:
                      - Existing behavior affected: [describe]
                      - Tests currently covering write scope: [list]
                      - Rollback verification: [how you confirmed rollback works]]

Status:               pending
Taskwarrior:          wwdev task <id> (<uuid>) status:pending
```

---

## Status Values

| Value | Meaning |
|---|---|
| `pending` | Task card complete; not yet started |
| `in-progress` | Builder is actively working |
| `blocked` | Waiting on another task or external dependency |
| `in-review` | Verifier is running; awaiting sign-off |
| `complete` | Verifier signed off; Docs agent closed; Orchestrator confirmed |

`Taskwarrior` field rule:
- Must exist on every non-closed card.
- Format: `Taskwarrior:          wwdev task <id> (<uuid>) status:<pending|completed|...>`
- If card status changes, update the Taskwarrior row in the same turn (and vice versa).

---

## Sizing Guidelines

A well-sized task:
- Has a write scope of 1–5 files
- Can be completed in a single agent session
- Has acceptance criteria that can be verified in under 10 minutes
- Has a clear rollback that doesn't require reconstructing lost work

If a task has 10+ files in write scope or acceptance criteria that take >30 min to verify, split it.

---

## Example: Well-Formed Task Card

```
## TASK-021: Add --dry-run flag to github-sync push

Goal:                 Allow users to preview what tasks would be pushed to GitHub without
                      making any remote API calls.

Acceptance criteria:  1. ww github-sync push --dry-run outputs a list of tasks that would
                         be pushed with no GitHub API calls made
                      2. ww github-sync push --dry-run --help includes --dry-run in usage
                      3. bats tests/test-github-sync-push.sh passes with new dry-run test
                      4. No GitHub issues created or modified during dry-run execution

Write scope:          services/custom/github-sync.sh
                      lib/sync-push.sh
                      tests/test-github-sync-push.sh

Tests required:       bats tests/test-github-sync-push.sh
                      bats tests/
                      Manual: ww github-sync push --dry-run (verify no API calls, confirm output)

Rollback:             git checkout services/custom/github-sync.sh lib/sync-push.sh

Fragility:            HIGH FRAGILITY: lib/sync-push.sh — Orchestrator approval confirmed 2026-04-04
                      SERIALIZED: none

Risk notes:           (Orchestrator) Explorer B identified dry-run as a documented but
                      unimplemented path in lib/sync-push.sh line 47.
                      (Builder pre-flight) sync-push.sh calls github_api_create_issue()
                      directly at line 112; dry-run flag must intercept before that call.
                      Rollback confirmed: git checkout reverts both files cleanly.

Status:               pending
Taskwarrior:          wwdev task <id> (<uuid>) status:pending
```
