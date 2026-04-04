# Explorer A Output Template — Docs/Status Drift Report

Save output to: `system/outputs/explorer-a-report.md`

---

```
# Explorer A Report: Docs/Status Drift Audit

Explorer: [agent session]
Date: [YYYY-MM-DD]
Files read: [list all files read]

---

## Summary

Total claims audited: [N]
- Confirmed complete: [N]
- Overclaimed: [N]
- Undocumented: [N]
- Genuinely incomplete: [N]

High-severity findings: [N]

---

## Confirmed Complete

Tasks where implementation exists, tests exist, and behavior matches the claim.

| Task | Source claim | Implementation evidence | Test evidence |
|---|---|---|---|
| [task name/number] | [file:line of claim] | [file that implements it] | [test file/name] |

---

## Overclaimed

Tasks where docs say "done" but implementation does not support the claim.
These must not be moved to TASKS.md as complete.

### OC-001: [Task name]
- **Claimed in:** [file:line]
- **Claim:** [what the doc says]
- **Reality:** [what the code actually does or doesn't do]
- **Gap:** [specific missing behavior]
- **Severity:** HIGH / MEDIUM / LOW
- **Reason:** HIGH = affects sync correctness or release safety; MEDIUM = affects user-facing behavior; LOW = cosmetic or docs-only

### OC-002: [Task name]
[repeat]

---

## Undocumented

Code that exists and works but is not claimed in any status document.

| Behavior | File | Notes |
|---|---|---|
| [description] | [file:line] | [any context] |

---

## Genuinely Incomplete

Tasks explicitly marked in-progress, listed as outstanding, or clearly unfinished in code.

### GI-001: [Task name]
- **Source:** [file:line]
- **Current state:** [what exists]
- **Missing:** [what's needed]
- **Severity:** HIGH / MEDIUM / LOW

---

## Contradiction Matrix

Full list with severity for Orchestrator synthesis:

| # | Task | Status claim | Actual status | Severity | Notes |
|---|---|---|---|---|---|
| 1 | | | | | |
| 2 | | | | | |

---

## Recommendations for Orchestrator

[2–5 bullet points on highest-priority items to address in TASKS.md build.
Do not make implementation recommendations — classify and prioritize only.]
```
