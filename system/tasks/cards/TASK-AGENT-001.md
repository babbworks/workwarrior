---
id: TASK-AGENT-001
title: Canonical ww-agent-guidance — resources/agent-templates/ structure
status: pending
priority: M
area: system
created: 2026-04-27
tw_uuid: d196baab
depends: TASK-RES-001, TASK-RES-002
---

## Goal

Establish `resources/agent-templates/` as the canonical home for agent session guidance, role templates, and session initialization scripts. Migrate the current `.claude/ww/ww-agent-guidance.md` into a versioned, installable template and document the dependency chain so future sessions can cold-start without per-repo config.

## Context

Agent guidance currently lives in `.claude/ww/ww-agent-guidance.md` — per-repo, non-installable, and not versioned as a first-class resource. When new profiles or new instances of the dev environment are created, agents must reconstruct context from scratch. Centralizing in `resources/agent-templates/` makes guidance installable (via `install.sh`), versionable, and derivable from system state (tasks, profiles, inventories).

## Acceptance Criteria

- [ ] `resources/agent-templates/ww-agent-guidance.md` — canonical version, referenced by `.claude/ww/ww-agent-guidance.md`
- [ ] `resources/agent-templates/roles/` — Orchestrator, Builder, Verifier, Docs role cards (brief, linkable)
- [ ] `resources/agent-templates/session-init.sh` — shell script that prints current WW_PROFILE context, pending task count, and active branch at session start
- [ ] `install.sh` copies `resources/agent-templates/` to `$WW_BASE/resources/agent-templates/`
- [ ] `.claude/ww/ww-agent-guidance.md` updated to reference canonical file (not duplicate it)
- [ ] ONBOARDING.md updated with pointer to resources/agent-templates/

## Write Scope

- `resources/agent-templates/` (new directory + files)
- `.claude/ww/ww-agent-guidance.md` — trim to pointer + local overrides
- `install.sh` — copy step
- `system/ONBOARDING.md` — reference update

## Risk

Low. Additive only; existing guidance not deleted until verified.

## Rollback

Delete resources/agent-templates/. Restore .claude/ww/ww-agent-guidance.md from git.
