# Quality Gates A–E — Workwarrior

These are merge blockers. Not advisory. Not optional. A PASSED Verifier sign-off is invalid if any gate condition is not satisfied.

---

## Gate A — No Implementation Without Acceptance Criteria

**Enforced by:** Orchestrator before task dispatch
**Checked by:** Verifier (confirms task card has measurable criteria)

### Checklist
- [ ] Task card exists in TASKS.md with an 8-field entry
- [ ] `Acceptance criteria` field is filled in with measurable, specific conditions (not "it works" or "tests pass")
- [ ] Each criterion can be verified as pass/fail without ambiguity
- [ ] Orchestrator has authored the criteria (not the Builder)

### Failure mode
Builder starts implementation without a task card or with vague criteria. Consequence: scope creep, unverifiable completion, regression risk. If discovered mid-implementation, stop. Orchestrator authors criteria. Builder restarts only within confirmed scope.

---

## Gate B — No Merge With Failing Tests or Unresolved High-Severity Findings

**Enforced by:** Verifier
**Checked by:** Verifier sign-off checklist

### Checklist
- [ ] All tests listed on the task card pass (with output attached to sign-off)
- [ ] `bats tests/` passes cleanly with no failures or errors
- [ ] If the change touches services: `bats tests/test-service-discovery.sh` passes
- [ ] If the change touches GitHub sync: `./tests/run-integration-tests.sh` passes on test profile
- [ ] All HIGH-severity Verifier findings are resolved
- [ ] No new test failures introduced by this change (regression check)
- [ ] New or changed behavior has a corresponding BATS test

### Failure mode
Tests fail or HIGH findings exist. Do not merge. Verifier produces FAILED sign-off with specific findings. Orchestrator issues a new task card targeting the failures. Original task remains open until Gate B is cleared.

---

## Gate C — No "Complete" Without Docs and Help Aligned

**Enforced by:** Docs agent; verified by Verifier
**Checked by:** Verifier sign-off, Docs agent report

### Checklist
- [ ] Every service modified or created responds correctly to `--help` and `-h`
- [ ] Help string describes actual behavior (not intended or planned behavior)
- [ ] If usage changed: `services/README.md` updated
- [ ] If CLI behavior changed: `docs/usage-examples.md` updated (if examples exist)
- [ ] If lib behavior changed: `lib/CLAUDE.md` updated
- [ ] If fragility classification changed: `fragility-register.md` and root `CLAUDE.md` updated
- [ ] Docs agent has confirmed all updates are complete

### Failure mode
Implementation ships with stale help strings or docs. Agents in future sessions will operate on incorrect information. If discovered during Verifier review, block merge and dispatch Docs agent before re-verifying.

---

## Gate D — No Release Without Signed Release Checklist

**Enforced by:** Orchestrator
**Checked by:** Orchestrator against `system/gates/release-checklist.md`
**Criteria source:** `system/reports/production-readiness-rubric.md`

No release tag may be applied until a completed and signed checklist has been saved to `system/reports/releases/vX.Y.Z-checklist.md`. A release claim without that file is invalid regardless of other evidence.

### Checklist
- [ ] All TASKS.md items in the release scope are marked `complete`
- [ ] No tasks marked `in-progress` or `blocked` in the release scope
- [ ] Gate C satisfied for all tasks in scope (docs current)
- [ ] Gate E satisfied for all tasks in scope (no untracked TODOs)
- [ ] All HIGH FRAGILITY changes have integration test sign-off
- [ ] `git status` is clean (no artifact noise)
- [ ] All five production-readiness criteria in `system/reports/production-readiness-rubric.md` satisfied with evidence
- [ ] Release checklist (`system/gates/release-checklist.md`) is fully signed by Orchestrator
- [ ] Signed checklist saved to `system/reports/releases/vX.Y.Z-checklist.md` before tagging

### Failure mode
Premature release claim with open tasks or stale docs. Do not tag a release until checklist is complete and the signed copy is saved to `system/reports/releases/`. This gate applies even for informal "Phase X complete" announcements.

---

## Gate E — No Untracked TODO in Production Path

**Enforced by:** Verifier (scans every diff for TODO/FIXME/HACK/XXX/PLACEHOLDER)
**Checked by:** Verifier sign-off

### Checklist
- [ ] Grep the diff for: `TODO`, `FIXME`, `HACK`, `XXX`, `PLACEHOLDER`, `NOT IMPLEMENTED`
- [ ] Every match is either: (a) pre-existing and already has a TASKS.md card, or (b) new and a TASKS.md card was created in this PR
- [ ] No "temporary" code exists in any production path without explicit tracking
- [ ] Any deferred item is marked with a TASKS.md card ID in the comment (e.g., `# TODO: TASK-042 — implement dry-run`)

### Failure mode
Silent technical debt accumulates in production paths. Future agents read TODOs as implementation guidance and act on them without a contract. Every untracked TODO is a latent Gate A violation.

### Scanning command
```bash
git diff HEAD | grep -E '^\+.*\b(TODO|FIXME|HACK|XXX|PLACEHOLDER|NOT IMPLEMENTED)\b'
```
