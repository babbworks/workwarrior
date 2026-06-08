# Workflow: Release Gate

Applies only when the Orchestrator is preparing a versioned release tag. This is Gate D.

---

## Pre-Conditions

- All TASKS.md items in the release scope are marked `complete`
- No tasks `in-progress` or `blocked` in the release scope
- Gates C and E satisfied for all tasks in scope
- All HIGH FRAGILITY changes have integration test sign-off

---

## Steps

```
[ ] Complete system/gates/release-checklist.md — every criterion checked, evidence recorded
[ ] Save signed checklist to system/reports/releases/vX.Y.Z-checklist.md
[ ] Confirm the saved file exists before running git tag
[ ] Tag the release: git tag -a vX.Y.Z -m "Release vX.Y.Z"
```

**No tag may be applied without the signed checklist saved to `system/reports/releases/`.**

Criteria source: `system/reports/production-readiness-rubric.md`
Gate reference: Gate D in `system/gates/all-gates.md`
