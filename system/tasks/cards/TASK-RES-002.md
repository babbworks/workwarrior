---
id: TASK-RES-002
title: UDA inventory — aggregate unique UDAs and purpose snippets from all profiles
status: pending
priority: M
area: resources
created: 2026-04-27
tw_uuid: fcd5d320
depends: TASK-RES-001
---

## Goal

Build `resources/inventory/uda-registry.yaml` that aggregates all TaskWarrior UDAs defined across every profile's `.taskrc`, with label, type, and purpose snippet. Enables cross-profile UDA awareness, helps new profiles bootstrap, and feeds browser UDA schema awareness.

## Context

Each profile defines its own UDAs in `.taskrc`. There is no cross-profile view. The browser loads UDA schema per-profile via `/data/task-meta`. A canonical registry would allow the CMD AI and the profile creation wizard to suggest appropriate UDAs and help users discover what others have defined.

## Acceptance Criteria

- [ ] Script `scripts/build-uda-inventory.sh` parses all profile `.taskrc` files for `uda.*` entries and writes `resources/inventory/uda-registry.yaml`
- [ ] Format per entry: `{ name, label, type, values, description, profile_origins: [str] }`
- [ ] `ww profile uda inventory` CLI subcommand triggers scan and prints summary table
- [ ] Browser CMD section: UDA inventory accessible as context for AI suggestions
- [ ] Duplicate UDAs across profiles merged; `profile_origins` lists all sources

## Write Scope

- `scripts/build-uda-inventory.sh` (new)
- `resources/inventory/uda-registry.yaml` (generated artifact, gitignored)
- `bin/ww` — route `ww profile uda inventory`

## Risk

Read-only. No profile data mutation.

## Rollback

Delete inventory file. No production code changed except bin/ww routing.

## Status

complete — 2026-04-27. scripts/build-uda-inventory.sh parses all profile .taskrc files for uda.* entries; writes resources/inventory/uda-registry.yaml with name/label/type/values/description/profile_origins. ww profile uda inventory intercepts before profile-uda.sh dispatch.
