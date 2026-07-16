# Service Design: you

*(Relocated from services/you/ — TASK-STRUCT-3)*

# Service overview: `you`

**Source:** TASK-DESIGN-001 (design-only.)

## Purpose

Personalization and operator context: who is using this profile, preferred working hours, notification hints, and lightweight “operating mode” flags that other services can read (questions, schedule, browser).

## Target user

Individual operators; optional multi-user machines with separate profiles.

## Command surface (sketch)

- `ww you show` — display resolved persona + preferences (redacted).
- `ww you set <key> <value>` — write to `profiles/<n>/you.yaml` (hypothetical).
- `ww you reset` — restore defaults from `resources/`.

## Data / integrations

- Reads/writes: small YAML under profile root; never stores secrets in plain text.
- Integrates: `ww questions` templates may reference `you` metadata.

## Open questions

- Schema versioning and migration when keys rename.
- Relationship to shell RC vs ww-only config.
- Privacy: export/redaction rules when profile is zipped for support.

---

## Original README

# Service: you

This directory contains services for the "you" category.

## Purpose

Place scripts and supporting files here to provide you-related functionality. Scripts should be executable and follow the Workwarrior service conventions.

## Notes

- Profile-specific overrides can be placed at: <profile-base>/services/you/
- See services/README.md for registry behavior and best practices.
