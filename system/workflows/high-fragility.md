# Workflow: High-Fragility Changes

Use this workflow for any task whose write scope includes HIGH FRAGILITY files. This supplements the standard feature-delivery workflow — all standard steps still apply. This workflow adds additional gates and requirements on top.

HIGH FRAGILITY files are defined in `fragility-register.md`. Currently:
- `lib/github-api.sh`
- `lib/github-sync-state.sh`
- `lib/sync-pull.sh`
- `lib/sync-push.sh`
- `lib/sync-bidirectional.sh`
- `lib/field-mapper.sh`
- `lib/sync-detector.sh`
- `lib/conflict-resolver.sh`
- `lib/annotation-sync.sh`
- `services/custom/github-sync.sh`

---

## Additional Pre-Conditions (Orchestrator)

Before a task card for a HIGH FRAGILITY file can be dispatched:

```
[ ] Orchestrator has explicitly authorized this change in the task card
    (add to Risk notes: "Orchestrator approval: [date] — [reason change is needed]")
[ ] The specific high-fragility concern is named in the task card Fragility field
[ ] Integration test profile is configured with GitHub auth
[ ] ./tests/run-integration-tests.sh passes clean BEFORE the change
    (run this first; if it fails, fix that before opening this task)
[ ] A rollback path is confirmed that can be verified without running integration tests
```

If `./tests/run-integration-tests.sh` fails before the change: do not proceed. Create a task card to fix the pre-existing failure first.

---

## Extended Risk Brief Requirements (Builder)

For HIGH FRAGILITY files, the risk brief must include:

1. **Current sync behavior:** Describe exactly what the file does during a push/pull/bidirectional sync cycle. Cite specific functions and line numbers.
2. **Side effect map:** List all GitHub API calls the changed code makes or could make. Identify any new calls or calls that could be skipped.
3. **Data loss scenarios:** Identify any code path where a bug could cause task data to be overwritten or GitHub issues to be incorrectly created/closed.
4. **Idempotency check:** Is the operation idempotent? If run twice, does it produce the same result or cause duplication?
5. **Error handling coverage:** For each new code path, what happens on network failure? API rate limit? Malformed response?
6. **Test profile isolation:** Confirm the test profile is completely isolated from production task data.

---

## Test Profile Setup (if not already configured)

The integration tests run against a test profile, not the `work` profile.

```bash
# Activate test profile
p-test   # or whatever the test profile alias is

# Verify GitHub sync config exists
ww issues configure

# Run baseline integration tests
./tests/run-integration-tests.sh

# Verify all 5 tests pass:
# 24.1: Full Push Cycle
# 24.2: Full Pull Cycle
# 24.3: Conflict Resolution
# 24.4: Error Handling
# 24.5: Batch Operations
```

---

## Implementation Constraints (Builder)

In addition to standard constraints:

- **No changes to sync logic without a corresponding test in `run-integration-tests.sh`.**
- **Never change field mapping without updating `lib/field-mapper.sh` tests.**
- **Never change conflict resolution logic without a Conflict Resolution test (24.3 equivalent).**
- **Any new API call must be gated behind a dry-run check if a dry-run flag exists.**
- **No silent failure modes.** Every error path must either: surface to the user, log to the sync error log, or both.

---

## Verifier Additional Steps (after standard verification)

After completing the standard verifier checklist, add:

### Step 9: Sync Integration Sign-Off

```
[ ] ./tests/run-integration-tests.sh passes on test profile (after the change)
    Test 24.1 (Push): PASS / FAIL
    Test 24.2 (Pull): PASS / FAIL
    Test 24.3 (Conflict): PASS / FAIL
    Test 24.4 (Error handling): PASS / FAIL
    Test 24.5 (Batch): PASS / FAIL

[ ] No new GitHub issues created on test profile during verification run
[ ] No existing test profile tasks corrupted during verification run
[ ] Sync state file is clean post-verification: cat profiles/test/.task/github-sync/sync.log

Sync behavior sign-off statement:
"I have verified that [describe specific sync behavior changed] works correctly.
 The integration test suite passes. No data was corrupted or unintentionally created
 during verification."

Sync sign-off: _______________
```

---

## Rollback Procedure for Sync Changes

If a sync change causes data issues after merge:

1. Immediately deactivate the affected profile's sync:
   ```bash
   # Comment out sync hooks in profiles/<name>/.task/hooks/
   ```

2. Revert the code change:
   ```bash
   git revert <commit>
   ```

3. Verify task data integrity:
   ```bash
   task list   # check no tasks are missing or corrupted
   ```

4. Create a task card for the root cause analysis before re-attempting the change.

---

## Memory After High-Fragility Changes

After a HIGH FRAGILITY task completes successfully, save to project memory:
- What the change did
- What risks were identified and how they were mitigated
- Any new fragility patterns discovered
- Integration test results before and after

These are especially important because they accumulate knowledge about the sync system that would otherwise require re-reading the entire sync codebase.
