# Verifier Sign-Off Template

Copy this template for every verification pass. All sections are required. Do not mark PASSED with open HIGH findings.

---

```
## Verifier Sign-Off: TASK-XXX [Title]

Verifier: [agent session identifier or "Claude Verifier"]
Date: [YYYY-MM-DD]
Task card reviewed: [confirm you read the full task card including write scope and acceptance criteria]

---

### 1. Test Results

Required tests from task card:
[ ] [test command 1] — PASS / FAIL
    Output: [paste relevant output or "clean"]
[ ] [test command 2] — PASS / FAIL
    Output:

Full BATS suite (bats tests/):
[ ] PASS / FAIL
    Failures (if any): [list file:test_name]

Integration tests (if applicable):
[ ] Not applicable to this task
[ ] ./tests/run-integration-tests.sh — PASS / FAIL
    Tests 24.1–24.5 results: [list]

---

### 2. Acceptance Criteria

[Copy each criterion from the task card and mark pass/fail with evidence]

[ ] Criterion 1: [text] — PASS / FAIL
    Evidence: [what you observed]

[ ] Criterion 2: [text] — PASS / FAIL
    Evidence:

---

### 3. Write Scope Audit

Files declared in task card write scope:
- [file 1]
- [file 2]

Files actually modified (from git diff):
- [file 1]
- [file 2]

[ ] Write scope is clean — no files modified outside declared scope
[ ] SCOPE VIOLATION — files modified outside scope: [list]

---

### 4. Simplify Pass

[ ] /simplify run on all files in write scope
Findings:
- [file]: [finding or "clean"]
- [file]: [finding or "clean"]

[ ] All findings addressed OR classified as acceptable (LOW severity, informational)
[ ] ESCALATED to standalone Simplifier agent (large diff / multiple lib files)
    Simplifier output: [attached / link]

---

### 5. Gate C — Docs and Help Alignment

[ ] All modified services respond to --help/-h
[ ] Help strings match actual behavior
[ ] services/README.md updated if needed
[ ] CLAUDE.md files updated if needed
[ ] docs/usage-examples.md updated if needed
[ ] Docs agent has been notified / has confirmed updates

---

### 6. Gate E — TODO/FIXME Scan

Scan command run: git diff HEAD | grep -E '^\+.*\b(TODO|FIXME|HACK|XXX|PLACEHOLDER)\b'

[ ] No new TODOs/FIXMEs in production paths
[ ] New TODOs found — each has a TASKS.md card:
    - [TODO text] → TASK-XXX created

---

### 7. HIGH FRAGILITY Sign-Off (if applicable)

[ ] Not applicable — no HIGH FRAGILITY files in write scope
[ ] HIGH FRAGILITY files touched: [list]
    [ ] Orchestrator approval confirmed on task card
    [ ] Extended risk brief present in task card risk notes
    [ ] Integration tests run on test profile: PASS / FAIL
    [ ] Sync behavior explicitly verified: [describe what was tested]

---

### Overall Verdict

[ ] PASSED — all gate conditions satisfied, all HIGH findings resolved
[ ] FAILED — blocking findings below

Blocking findings (HIGH severity):
1. [finding]: [specific description, file:line if applicable]
2.

Non-blocking findings (MEDIUM/LOW — must have follow-up task card):
1. [finding]: TASK-XXX created
2.

---

Verifier signature: _______________
```
