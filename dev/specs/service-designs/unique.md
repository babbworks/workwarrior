# Service Design: unique

*(Relocated from services/unique/ — TASK-STRUCT-3)*

# Service overview: `unique`

**Source:** TASK-DESIGN-001 (design-only.)

## Purpose

Enforce or audit uniqueness constraints across ww-managed artifacts—UDA value uniqueness, journal entry IDs, shortcut keys, or ledger account naming—without pushing all rules into individual services.

## Target user

Profile maintainers; Builder when adding new UDAs or registry entries.

## Command surface (sketch)

- `ww unique check --domain <tasks|shortcuts|...>` — report duplicates with remediation hints.
- `ww unique enforce --domain …` — optional hook registration (future) for pre-commit style checks.

## Data / integrations

- Reads: active profile configs (`TASKRC`, shortcuts YAML, etc.).
- Writes: none in audit mode; guarded writes only in explicit enforce mode (future).

## Open questions

- Overlap with TaskWarrior native uniqueness vs ww-level policy.
- JSON output schema for CI consumption.
- Performance on large task databases (streaming vs batch).

---

## Original README

# Service: unique

This directory contains services for the "unique" category.

## Purpose

Place scripts and supporting files here to provide unique-related functionality. Scripts should be executable and follow the Workwarrior service conventions.

## Notes

- Profile-specific overrides can be placed at: <profile-base>/services/unique/
- See services/README.md for registry behavior and best practices.
