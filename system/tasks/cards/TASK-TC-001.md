## TASK-TC-001: TaskChampion multi-device profile sync — ww integration layer

Goal:                 Design and implement ww's approach to reliable multi-device
                      TaskWarrior profile sync using TaskChampion as the storage and
                      sync backend. Critical for commercial reliability — teams need
                      task data consistent across machines without manual file copying.

Background:           TaskChampion is the SQLite-based storage backend for TW 2.6+.
                      It supports sync via a TaskChampion sync server. Key constraints:
                        - Only task DATA syncs (uuid, fields, UDA values, annotations)
                        - .taskrc does NOT sync — UDA definitions, color rules, urgency
                          coefficients, reports are all local config only
                        - Each ww profile is a separate TASKDATA directory with its own
                          taskchampion.sqlite3 — each needs its own sync server "bucket"
                        - Without .taskrc sync, a profile restored on a new machine has
                          the task data but cannot display or validate UDA fields until
                          .taskrc is also present

                      Problems this task must solve:
                        1. .taskrc portability: ensure UDA definitions travel with profiles
                           (partially solved by ww profile backup/restore — but sync is
                           ongoing, not one-time)
                        2. Per-profile sync configuration: each profile needs its own
                           sync server URL and credentials without polluting other profiles
                        3. Credential management: sync tokens must not be committed to git
                        4. Team sharing: multiple users syncing to a shared profile's task
                           data (e.g. a work group where all members see the same tasks)
                        5. Conflict resolution: TW's last-write-wins via TaskChampion —
                           ww should surface conflicts rather than silently losing data

Acceptance criteria:  1. ww profile sync configure
                         - Wizard: enter sync server URL, auth token
                         - Writes sync config to profiles/<name>/.taskrc:
                             sync.server.url=https://...
                             sync.server.credential=<token>
                         - Stores credential via ww oracle pattern (not plaintext if possible)
                         - Validates connectivity before saving

                      2. ww profile sync push / pull / status
                         - Thin wrappers around `task sync` with correct TASKRC/TASKDATA env
                         - Captures and surfaces TW sync errors in ww format
                         - status shows last sync time, server URL, pending changes

                      3. .taskrc companion sync:
                         - Design a mechanism to keep .taskrc in sync alongside task data
                         - Options: git-tracked .taskrc (already possible), ww sync server
                           extension, or profile export bundle on each sync
                         - Decision deferred to implementation phase — options must be
                           evaluated against security and complexity constraints

                      4. Per-profile sync isolation:
                         - Each profile's sync config is scoped to that profile's .taskrc
                         - No cross-profile sync credential leakage
                         - ww group sync can orchestrate sync across all group member
                           profiles sequentially

                      5. Commercial team scenario:
                         - Document how a team of 3 sharing a "work" group would configure
                           sync so all three see the same tasks
                         - Include credential distribution guidance
                         - Include conflict resolution guidance

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/services/profile/sync.sh  (new service)
                      /Users/mp/ww/docs/sync-setup.md  (new)
                      /Users/mp/ww/system/config/command-syntax.yaml

Tests required:       Integration tests only — requires a live TaskChampion sync server
                      Unit tests for config write/read logic
                      Manual: full round-trip on two machines

Fragility:            HIGH — writes sync credentials to .taskrc; sync errors can cause
                      data loss if conflict resolution is wrong. Requires a test
                      environment separate from any production profile.

Risk notes:           TaskChampion sync server options: self-hosted (taskchampion-sync-server
                      on GitHub), or Focalboard, or custom. Hosting requirements must be
                      documented. Credential storage must never use plaintext in a
                      git-tracked file. The oracle pattern (@oracle:eval:...) from
                      bugwarrior integration may extend here.
                      This is a stepping stone to ww being reliable in commercial settings
                      where data consistency across machines is a hard requirement.

Status:               parked — requires design review before implementation
                      Unblock when: ww profile backup/restore is proven stable and
                      at least one commercial use case is actively requesting sync
