# Service overview: `verify`

**Source:** TASK-DESIGN-001 (design-only.)

## Purpose

Verifier-facing automation: turn human checklists in `dev/roles/verifier.md` into runnable subcommands that emit signed-off artifacts (or machine-readable diffs) after Builder handoff.

## Target user

Verifier role; CI jobs mirroring release gates.

## Command surface (sketch)

- `ww verify suite <name>` — run a named checklist (BATS wrapper + static scans).
- `ww verify signoff --task TASK-…` — append structured verdict to `dev/logs/` (policy TBD).

## Data / integrations

- Reads: `dev/tests/`, `dev/gates/`, changed files from `git diff`.
- Writes: only explicit report paths under `dev/` or `/tmp` per policy.

## Open questions

- Authority: should `ww verify` ever auto-write gate files, or always stdout-only?
- Distinction from `ww diagnostic` (user health) vs `verify` (merge gate).
- Sandbox requirements when running user profiles in CI.
