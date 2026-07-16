# Service Design: kompare

*(Relocated from services/kompare/ — TASK-STRUCT-3)*

# Service overview: `kompare`

**Source:** TASK-DESIGN-001 (design-only.)

## Purpose

Diff-oriented workflows across profiles or across tool backends—e.g. compare TaskWarrior UDAs, compare two export snapshots, or compare ledger headers—without shelling out to ad-hoc `diff -u` recipes.

## Target user

Power users maintaining multiple profiles; Verifier when reviewing sync deltas.

## Command surface (sketch)

- `ww kompare profiles <a> <b> --domain taskrc` — normalized diff of selected files.
- `ww kompare snapshot <file1> <file2>` — generic structured diff for ww export JSON.
- `ww kompare timew <a> <b>` — extensions + tag sets (read-only).

## Data / integrations

- Reads: two profile roots or two files under user control; may invoke `diff`, `jq`, optional `python3`.
- Writes: none; optional `/tmp` reports.

## Open questions

- Scope creep vs `ww find` and `ww export` (clear ownership).
- Redaction rules for secrets in `.taskrc` / tokens before diffing.
- Windows / macOS line-ending normalization policy.

---

## Original README

# Service: kompare

This directory contains services for the "kompare" category.

## Purpose

Place scripts and supporting files here to provide kompare-related functionality. Scripts should be executable and follow the Workwarrior service conventions.

## Notes

- Profile-specific overrides can be placed at: <profile-base>/services/kompare/
- See services/README.md for registry behavior and best practices.
