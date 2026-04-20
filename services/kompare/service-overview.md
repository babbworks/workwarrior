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
