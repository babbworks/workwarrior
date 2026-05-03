# Release Checklist — Workwarrior

This document explains what "production-ready" means for `ww` and what must be verified before any release is tagged.

The internal gate is `system/gates/release-checklist.md`. That file must be completed and signed before a release tag is applied.

---

## What production-ready means for ww

Production-ready = **stable install + every command listed in `ww help` works**.

This is not "all intended functionality" — the help output is the contract. If a command appears in `ww help`, it must work. If it is not in `ww help`, it is not a v1 commitment.

---

## The five release criteria

### 1. `ww help` produces clean output

Running `ww help` shows no errors, no garbled text, and no "command not found" messages. Stderr is silent.

### 2. Every help-listed command responds correctly

Every command shown in the `ww help` Commands section routes to a working handler. Each one exits 0 on `--help` and does not produce an unhandled error.

### 3. `ww deps install` succeeds on a clean macOS (brew baseline)

On a macOS system with Homebrew installed, `ww deps install` installs all core tools — task, timew, hledger, jrnl, pipx, gh — without error.

### 4. Extension installs give correct guidance on Linux

On Linux (no brew), `ww tui install` and `ww mcp install` detect the platform (apt / dnf / pacman), emit the right install hint, and exit non-zero. They do not silently fail and do not produce a generic "brew not found" message.

### 5. Core profile round-trip works

The minimum viable user journey completes without error:

```
ww profile create <name>
p-<name>                     # activate the profile
task add "test task"
timew start "test task"
```

Data appears in the correct profile directory. Failure here blocks release regardless of any other criterion being satisfied.

---

## How the gate works

Before any release tag is applied:

1. The Orchestrator fills out `system/gates/release-checklist.md` — one item per criterion, with evidence and date.
2. The completed checklist is saved to `system/reports/releases/vX.Y.Z-checklist.md`.
3. Only after the saved file exists may the tag be applied.

The full criteria definitions (with evidence sources and owners) are in `system/reports/production-readiness-rubric.md`.
