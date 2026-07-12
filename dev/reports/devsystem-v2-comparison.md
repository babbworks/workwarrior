# Devsystem v2 Architecture Comparison: claude/v2 vs codex/v2

Date: 2026-04-04

## Structure at a Glance

| Dimension | claude/v2 | codex/v2 |
|---|---|---|
| Total files | 40 | ~48 |
| CLI binary | `bin/wwctl` | `bin/codexctl` |
| Context docs | 1 unified `CLAUDE.md` (rich) | `CLAUDE.md` (lean) + `OPERATING-SPEC.md` (rich) |
| Template directories | `templates/` only | `templates/` + `templates/claude/` (duplicated) |
| Output directories | `audits/`, `reports/`, `logs/` | `audits/`, `reports/`, `logs/`, `outputs/` |
| Phase 1 guidance | `workflows/phase1.md` only | `workflows/phase1.md` + `runbooks/phase1.md` (both) |
| Phase 1 task cards | 6 seeded (TASK-1.1–1.5) | 1 stub (TASK-001) |
| verify-phase1 checks | 15 across 5 categories | 6 checks |

---

## Defining Difference: Hybridization Strategy

This runs through every difference between the two systems.

**claude/v2 hybridized by replacing.** When a better version of something existed, the weaker version was discarded. `CLAUDE.md` is the single rich context document — the lean v1 version is gone. There is one template set, one phase1 workflow, one output directory. Clean seams throughout.

**codex/v2 hybridized by accumulating.** Both old and new versions were kept alongside each other. `CLAUDE.md` stays as the lean operating contract; the rich content was added as `OPERATING-SPEC.md` instead of replacing it. Both codex template formats and claude template formats exist simultaneously in `templates/` and `templates/claude/`. Both `runbooks/phase1.md` and `workflows/phase1.md` exist. Both `audits/` and `outputs/` exist.

Result: codex/v2 is larger and has duplication but also has backward compatibility and no information discarded. claude/v2 is cleaner but made deliberate deprecation choices.

---

## Point-by-Point Comparison

### Context Document Architecture

codex/v2 kept `CLAUDE.md` as the lean governance contract and added `OPERATING-SPEC.md` as the rich cold-startable document. Two entry points: a quick governance summary and a deep operational spec. Defensible but creates a "which one do I read first" ambiguity for cold-started agents.

claude/v2 consolidated both into one `CLAUDE.md`. Single entry point, no ambiguity.

**Edge: Tie with different tradeoffs.** Codex dual-doc is useful for quick governance reference; Claude single-doc is cleaner for cold-starting agents.

---

### verify-phase1.sh Depth

claude/v2 checks 15 conditions across 5 labelled sections:
- Context files: CLAUDE.md deployed, services/CLAUDE.md deployed, content checks (fragility markers, test baseline, TASKS.md reference, set -euo pipefail)
- Task board: TASKS.md exists, pending/ has no new files
- Explorer outputs: A and B reports exist in audits/
- Fragility documentation: register exists, named files referenced
- Repository hygiene: no tracked .DS_Store or .sqlite3, .gitignore covers patterns

codex/v2 checks 6 conditions: CLAUDE.md exists (in either location), services/CLAUDE.md exists, Explorer A exists (audits/ OR outputs/), Explorer B exists, TASKS.md exists, phase1-checklist.txt exists. Notable: accepts outputs from either `audits/` or `outputs/` — a compatibility bridge between naming conventions.

**Edge: claude/v2 on depth; codex/v2 on compatibility tolerance.**

---

### dispatch-worktree.sh Safety

claude/v2 added:
- Role name validation against known list (orchestrator, builder, verifier, explorer, docs)
- SERIALIZED file conflict detection: reads `config/serialization-paths.txt`, checks active worktrees, prompts user for confirmation before proceeding if conflict detected
- Prints the matching role's agent prompt prefix location after successful dispatch

codex/v2 is identical to v1: creates the worktree, prints branch/path/task. No validation, no serialization check, no user confirmation.

**Edge: claude/v2 clearly.** The serialization conflict check enforces what the governance model requires — preventing parallel dispatch on `bin/ww` or sync libs. codex/v2 doesn't enforce it at the script level.

---

### Template Duplication

codex/v2 has approximately 10 template files across two naming conventions:
- Root `templates/`: codex originals (`verifier-report.md`, table format) AND claude originals (`verifier-signoff.md`, 7-section checklist), both `explorer-a-report.md` and `explorer-a-output.md`
- `templates/claude/`: all 5 claude templates duplicated again

This creates an agent decision problem: `verifier-report.md` is a simple table; `verifier-signoff.md` is a 7-section adversarial checklist. Both exist. An agent will pick one and may pick the wrong one.

claude/v2 has 5 templates in one directory, one format, no duplication.

**Edge: claude/v2.**

---

### Task Card Seeding

claude/v2 seeded all 6 Phase 1 task cards with full 8-field content: specific goals, measurable acceptance criteria, exact write scopes, rollback paths, and risk notes. Ready to dispatch immediately.

codex/v2 has one stub card (`TASK-001.md`) with placeholder brackets throughout.

**Edge: claude/v2** by a wide margin for immediate operability.

---

### CLI Commands

claude/v2 `wwctl` adds two commands absent from codex/v2:
- `gates` — prints all 5 gates as a quick in-session reference
- `fragility` — prints serialized and high-fragility file lists

codex/v2 `codexctl` has the same 4 commands as v1 (status, verify-phase1, new-task, dispatch).

**Edge: claude/v2** — minor but useful for quick reference without opening docs.

---

### Phase 1 Guidance

codex/v2 has both `runbooks/phase1.md` (35-line high-level summary) and `workflows/phase1.md` (comprehensive step-by-step with commands). Mild redundancy.

claude/v2 has only `workflows/phase1.md`. The brief runbook was not carried forward.

**Edge: Tie.** claude/v2 is cleaner; codex/v2 gives a quick-reference alongside the full procedure.

---

### common.sh Utilities

claude/v2 extended with: `warn()`, `require_dir()`, shared `PASS_COUNT`/`FAIL_COUNT` variables, `print_summary()` function used by verify-phase1.sh for consistent formatted output.

codex/v2 carries forward v1's `common.sh`: `fail()`, `require_file()`, `timestamp()`.

**Edge: claude/v2** — the shared counter/summary pattern makes scripts more consistent and easier to extend.

---

## Summary Scorecard

| Category | claude/v2 | codex/v2 | Edge |
|---|---|---|---|
| Context doc architecture | Single unified CLAUDE.md | CLAUDE.md (lean) + OPERATING-SPEC.md (rich) | Tie |
| verify-phase1 depth | 15 checks, 5 sections | 6 checks, dual-path compatible | claude/v2 depth; codex/v2 tolerance |
| dispatch safety | Role validation + serialization check + confirmation | Basic worktree creation | claude/v2 |
| Template clarity | 5 files, one format | ~10 files, two formats, duplication | claude/v2 |
| Task card seeding | 6 seeded Phase 1 cards | 1 stub | claude/v2 |
| CLI commands | 6 commands incl. gates + fragility | 4 commands | claude/v2 |
| Phase 1 guidance | workflow only | workflow + runbook | Tie |
| Backward compatibility | No compatibility shim | Accepts audits/ and outputs/ | codex/v2 |
| common.sh utilities | Extended (warn, require_dir, print_summary) | Basic v1 carry-forward | claude/v2 |
| Binary naming | wwctl (project-specific) | codexctl (system-specific) | Preference |

---

## Bottom Line

Both v2 systems are genuine hybrids. The remaining differences reflect fundamentally different hybridization philosophies.

**claude/v2** made opinionated replacement decisions: one context file, one template format, one phase1 document, no backward compatibility shim. Tighter, less duplication, more opinionated. Scripts are more defensive. Immediately operational with seeded Phase 1 task cards.

**codex/v2** made additive integration decisions: kept original formats alongside new ones, maintains compatibility between naming conventions, preserves the lean CLAUDE.md alongside the rich OPERATING-SPEC.md. Larger, more flexible, more tolerant. Less immediately operational out of the box.

**For agentic use** — where cold-started agents need clarity about which file to read and which template to use — claude/v2's single-format, no-duplication approach is stronger.

**For a transition environment** — where multiple agents may have different conventions or legacy naming must be tolerated — codex/v2's compatibility tolerance has real value.
