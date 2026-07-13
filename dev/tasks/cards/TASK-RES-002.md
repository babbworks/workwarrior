## TASK-RES-002: UDA inventory — aggregate unique UDAs and purpose snippets from all profiles

Goal:                 Build `resources/inventory/uda-registry.yaml` that aggregates all TaskWarrior UDAs defined across every profile's `.taskrc`, with label, type, and purpose snippet. Enables cross-profile UDA awareness, helps new profiles bootstrap, and feeds browser UDA schema awareness.

Background:           Each profile defines its own UDAs in `.taskrc`. There is no cross-profile view. The browser loads UDA schema per-profile via `/data/task-meta`. A canonical registry would allow the CMD AI and the profile creation wizard to suggest appropriate UDAs and help users discover what others have defined.

Depends on:           TASK-RES-001

Acceptance criteria:  - [ ] Script `scripts/build-uda-inventory.sh` parses all profile `.taskrc` files for `uda.*` entries and writes `resources/inventory/uda-registry.yaml`
                      - [ ] Format per entry: `{ name, label, type, values, description, profile_origins: [str] }`
                      - [ ] `ww profile uda inventory` CLI subcommand triggers scan and prints summary table
                      - [ ] Browser CMD section: UDA inventory accessible as context for AI suggestions
                      - [ ] Duplicate UDAs across profiles merged; `profile_origins` lists all sources

Write scope:          - `scripts/build-uda-inventory.sh` (new)
                      - `resources/inventory/uda-registry.yaml` (generated artifact, gitignored)
                      - `bin/ww` — route `ww profile uda inventory`

Rollback:             Delete inventory file. No production code changed except bin/ww routing.

Fragility:            See Risk notes.

Risk notes:           Read-only. No profile data mutation.

Notes:                priority: M · area: resources · created: 2026-04-27

Status:               complete — 2026-04-27. scripts/build-uda-inventory.sh parses all profile .taskrc files for uda.* entries; writes resources/inventory/uda-registry.yaml with name/label/type/values/description/profile_origins. ww profile uda inventory intercepts before profile-uda.sh dispatch.

Taskwarrior:          wwdev task (fcd5d320) status:completed
