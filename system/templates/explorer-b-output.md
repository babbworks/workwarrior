# Explorer B Output Template — Code/Test Reality Report

Save output to: `system/outputs/explorer-b-report.md`

---

```
# Explorer B Report: Code/Test Reality Audit

Explorer: [agent session]
Date: [YYYY-MM-DD]
Files read: [list all files read]

---

## Summary

Lib files with full coverage: [N]
Lib files with critical gaps: [N]
Lib files with important gaps: [N]
Services with help/behavior parity violations: [N]
TODOs in HIGH FRAGILITY files: [N]
Highest regression-risk hotspot: [file:line]

---

## Test Coverage Map

For each lib file, classify coverage status and list specific gaps.

| Lib file | Coverage status | Covered by | Critical gaps |
|---|---|---|---|
| lib/core-utils.sh | covered / gap-critical / gap-important / gap-deferred | [test files] | [specific untested behaviors] |
| lib/profile-manager.sh | | | |
| lib/shell-integration.sh | | | |
| lib/logging.sh | | | |
| lib/config-loader.sh | | | |
| lib/github-api.sh | | | |
| lib/github-sync-state.sh | | | |
| lib/sync-pull.sh | | | |
| lib/sync-push.sh | | | |
| lib/sync-bidirectional.sh | | | |
| lib/field-mapper.sh | | | |
| lib/sync-detector.sh | | | |
| lib/conflict-resolver.sh | | | |
| lib/annotation-sync.sh | | | |
| lib/bugwarrior-integration.sh | | | |
| lib/profile-stats.sh | | | |
| lib/export-utils.sh | | | |
| lib/delete-utils.sh | | | |
| lib/dependency-installer.sh | | | |
| lib/shortcode-registry.sh | | | |

Coverage gap classification:
- **gap-critical**: must have test before any change to this file
- **gap-important**: should have test added in current sprint
- **gap-deferred**: acceptable gap for now, track in TASKS.md

---

## TODO/FIXME Register — HIGH FRAGILITY Files

All TODO, FIXME, HACK, XXX occurrences in github-*.sh and sync-*.sh files.

| File | Line | Text | Type | Severity | Assessment |
|---|---|---|---|---|---|
| lib/sync-push.sh | 47 | TODO: implement dry-run | TODO | HIGH | Documented feature claim, not implemented |
| [file] | [line] | [text] | TODO/FIXME/HACK | HIGH/MEDIUM/LOW | [what it means] |

---

## Code-vs-Doc Gap List

Where documentation claims behavior the code doesn't implement.

### GAP-001: [Short title]
- **Documented in:** [file]
- **Claim:** [what docs say]
- **Code reality:** [what code does]
- **File:line:** [location]
- **Severity:** HIGH / MEDIUM / LOW

### GAP-002:
[repeat]

---

## Docs/Help Parity Violations

Services where `--help` output doesn't match actual behavior.

| Service | Help says | Code does | Severity |
|---|---|---|---|
| [service file] | [what help claims] | [what code does] | |

---

## Required Baseline Test Suite Per Change Type

[Fill in based on what you found — these go into root CLAUDE.md testing section]

| Change type | Minimum required tests |
|---|---|
| Any `lib/` change | `bats tests/` [add specific suites if found] |
| Any `services/` change | `bats tests/test-service-discovery.sh` + `bats tests/` |
| `bin/ww` change | `bats tests/` + manual smoke: `ww help` |
| Profile behavior change | `bats tests/test-foundation.sh` + `bats tests/` |
| GitHub sync change | `./tests/run-integration-tests.sh` (all 5 tests) + `bats tests/` |

---

## Top Regression-Risk Hotspots

The 5–10 specific locations with highest regression risk if changed without tests.

| # | File:line | Risk description | Current test coverage |
|---|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |

---

## Recommendations for Orchestrator

[Bullet points for: which coverage gaps are critical for Phase 2, which TODOs need immediate task cards, which hotspots should be noted in lib/CLAUDE.md fragility markers. No implementation recommendations.]
```
