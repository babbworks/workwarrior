# Builder Risk Brief Template

Complete this before touching any file in the write scope. Paste it into the task card's `Risk notes` field. This is not optional.

---

```
## Builder Risk Brief: TASK-XXX [Title]

Builder: [agent session]
Date: [YYYY-MM-DD]
Write scope reviewed: [confirm you read the full task card write scope]

---

### 1. Existing Behavior Affected

What does the code in the write scope currently do?
[Describe current behavior of each file you will modify. Be specific — cite line numbers
where the key logic lives. If the behavior is unclear, say so and describe how you determined
what it does.]

Files reviewed before writing:
- [file]: [what it does, key functions, line references]
- [file]: [what it does]

---

### 2. What Could Break

What existing behavior could be broken or changed by this implementation?
[Think about: callers of functions you're modifying, shell sourcing chains, profile isolation
assumptions, environment variable dependencies, hook execution order.]

Risk 1: [description] — likelihood: HIGH / MEDIUM / LOW
Risk 2: [description] — likelihood:

---

### 3. Test Coverage of Write Scope

Which tests currently exercise the files I will modify?
[Run: grep -r "source\|bats\|load" tests/ | grep <filename>
List what you found.]

Currently covered by:
- [test file]: covers [specific behavior]
- [test file]: covers [specific behavior]

Coverage gaps relevant to this change:
- [behavior being changed that has no test — will add test]

---

### 4. Fragility Confirmation

[ ] No HIGH FRAGILITY files in write scope — proceeding
[ ] HIGH FRAGILITY files present — Orchestrator approval confirmed in task card risk notes field
    Approved by: [confirm it's in the task card]

[ ] No SERIALIZED files in write scope
[ ] SERIALIZED files present — confirmed no other active task has these in write scope
    Confirmed with: [Orchestrator confirmation]

---

### 5. Rollback Verification

Can the rollback path in the task card be executed cleanly?
[Verify the rollback command before starting. If it requires something that doesn't yet exist,
note it here and create a backup if needed.]

Rollback path: [paste from task card]
Verified: YES / NO
Notes: [any caveats]

---

Brief complete. Proceeding with implementation.
```
