# Session 7 Handoff — 2026-04-09 (Claude)

## What happened this session

### System fixes
- Created `/Users/mp/ww/CLAUDE.md` — minimal redirect stub so Claude Code auto-loads system/ at session start. Approved by user. Not a dev content file — just points to `system/ONBOARDING.md`.
- Deleted `TASK-ISSUES-002` — bugwarrior setup for john/mark removed from backlog per user decision.

### New task cards created
- `TASK-DESIGN-001` — service discovery interview task: quiz user on undeveloped services, produce `service-overview.md` in each service folder as design departure point.
- `TASK-REL-001` — operationalize release checklist as Gate D enforcement (depends on REL-002).
- `TASK-REL-002` — define production-ready criteria; absorb ww help bug fixes + Linux platform detection.

### TASK-REL-002: Builder completed, Verifier interrupted
Builder (subagent) implemented:
1. Fixed `ww help` stderr errors — backtick substitution in heredoc Compatibility line and nudge function
2. Fixed garbled Compatibility line (macOS system groups were printing via command substitution)
3. Added Linux platform detection to `ww tui install` and `ww mcp install`
4. Created `docs/INSTALL.md` — install policy document
5. Created `system/reports/production-readiness-rubric.md` — 5-criterion rubric with evidence/owner
6. Updated `system/gates/all-gates.md` — Gate D references rubric
7. Updated `system/config/command-syntax.yaml`

All Builder changes are committed in this session's commit.

Verifier agent was interrupted by quota mid-run. The BATS test run (bz2kjp9zq task) completed and showed **only 1 failure: Property 17 in test-timewarrior-hook-installation.bats (50-char profile name hook)** — this is a known baseline failure, NOT a regression.

### Resuming agent: complete Verifier sign-off for REL-002

Run:
```bash
cd /Users/mp/ww
ww help 2>/tmp/ww_stderr.txt && wc -c /tmp/ww_stderr.txt   # must be 0 bytes
ww help 2>/dev/null | grep -A2 "Compatibility:"             # must show single-quotes, no system groups
bash system/scripts/select-tests.sh bin_ww --run            # 1 known failure OK
```

Then check:
- `docs/INSTALL.md` — covers canonical (ww deps install) vs best-effort (extension installs)
- `system/reports/production-readiness-rubric.md` — 5 criteria with evidence + owner per criterion
- `system/gates/all-gates.md` — Gate D references rubric

Then mark TASK-REL-002 complete and proceed to TASK-SYNC-003 Verifier sign-off.

### TASK-SYNC-003 status
Implemented by Kiro (commits f72bedc + ac19057). Card is "in-review". BATS suite should run; only `run-integration-tests.sh` is pending quota. Verifier can sign off on BATS pass alone for now.

### Policy decisions logged in decisions.md
- Root CLAUDE.md stub is intentional (not a copy of system/CLAUDE.md)
- Integration tests pending quota — BATS suite is NOT postponed
- Install role split: `ww deps install` = canonical; extension installs = best-effort with platform guidance

### Kiro's uncommitted work (do not touch)
`services/browser/`, `stories/`, `tests/test-browser.bats`, `system/tasks/cards/TASK-SITE-001..006.md` — Kiro owns these. Do not commit or modify.

## Next dispatch queue
1. REL-002 Verifier sign-off (see above)
2. SYNC-003 Verifier sign-off
3. REL-001 (depends on REL-002 complete)
4. TASK-DESIGN-001 service interviews
5. TASK-ISSUES-001
