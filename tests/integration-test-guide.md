# GitHub Two-Way Sync - Integration Testing Guide

## Overview

This guide walks you through comprehensive integration testing of the GitHub two-way sync feature with a real GitHub repository. These tests validate the complete end-to-end functionality.

## Prerequisites

### Required Setup
1. **GitHub CLI (`gh`) installed and authenticated**
   ```bash
   gh auth status
   # If not authenticated:
   gh auth login
   ```

2. **Test GitHub Repository**
   - Create a test repository on GitHub (e.g., `username/taskwarrior-sync-test`)
   - Ensure you have write access
   - Repository can be public or private

3. **Active Workwarrior Profile**
   ```bash
   source bin/ww
   ww profile use test-profile  # Or create a new test profile
   ```

4. **Clean Test Environment**
   ```bash
   # Clear any existing test tasks
   task rc.confirmation=off status:pending delete
   task rc.confirmation=off status:completed delete
   ```

## Test Suite

### Test 24.1: Full Push Cycle

**Objective**: Verify tasks can be pushed to GitHub and issues are created/updated correctly.

**Steps**:

1. **Create test tasks in TaskWarrior**
   ```bash
   # Task 1: Basic task
   task add "Test task 1 - Basic sync" priority:H +testing
   TASK1_ID=$(task +testing limit:1 _ids)
   
   # Task 2: Task with multiple tags
   task add "Test task 2 - Multiple tags" priority:M +testing +bug +feature
   TASK2_ID=$(task +testing limit:1 _ids | tail -1)
   
   # Task 3: Task with annotation
   task add "Test task 3 - With annotation" priority:L +testing
   TASK3_ID=$(task +testing limit:1 _ids | tail -1)
   task $TASK3_ID annotate "This is a test annotation"
   ```

2. **Create test issues on GitHub**
   ```bash
   # Create issues for linking
   ISSUE1=$(gh issue create --repo username/taskwarrior-sync-test \
     --title "Test Issue 1" --body "For testing push sync" | grep -oP '#\K\d+')
   
   ISSUE2=$(gh issue create --repo username/taskwarrior-sync-test \
     --title "Test Issue 2" --body "For testing push sync" | grep -oP '#\K\d+')
   
   ISSUE3=$(gh issue create --repo username/taskwarrior-sync-test \
     --title "Test Issue 3" --body "For testing push sync" | grep -oP '#\K\d+')
   ```

3. **Enable sync for tasks**
   ```bash
   github-sync enable $TASK1_ID $ISSUE1 username/taskwarrior-sync-test
   github-sync enable $TASK2_ID $ISSUE2 username/taskwarrior-sync-test
   github-sync enable $TASK3_ID $ISSUE3 username/taskwarrior-sync-test
   ```

4. **Modify tasks and push**
   ```bash
   # Modify task 1
   task $TASK1_ID modify "Test task 1 - Updated title"
   task $TASK1_ID modify priority:M
   
   # Modify task 2
   task $TASK2_ID modify +urgent
   
   # Add annotation to task 3
   task $TASK3_ID annotate "Second annotation"
   
   # Push changes
   github-sync push
   ```

5. **Verify on GitHub**
   ```bash
   # Check issue 1
   gh issue view $ISSUE1 --repo username/taskwarrior-sync-test
   # Expected: Title updated, priority:medium label, state OPEN
   
   # Check issue 2
   gh issue view $ISSUE2 --repo username/taskwarrior-sync-test
   # Expected: urgent label added
   
   # Check issue 3
   gh issue view $ISSUE3 --repo username/taskwarrior-sync-test --comments
   # Expected: Two comments with [TaskWarrior] prefix
   ```

6. **Test status changes**
   ```bash
   # Complete task 1
   task $TASK1_ID done
   github-sync push $TASK1_ID
   
   # Verify issue is closed
   gh issue view $ISSUE1 --repo username/taskwarrior-sync-test
   # Expected: State CLOSED
   ```

**Expected Results**:
- ✅ Task titles sync to issue titles
- ✅ Task status maps to issue state (pending→OPEN, completed→CLOSED)
- ✅ Task priority maps to priority labels (H→priority:high, M→priority:medium, L→priority:low)
- ✅ Task tags sync to issue labels
- ✅ Task annotations sync to issue comments with [TaskWarrior] prefix
- ✅ System tags (ACTIVE, READY, etc.) are excluded

---

### Test 24.2: Full Pull Cycle

**Objective**: Verify issues can be pulled from GitHub and tasks are created/updated correctly.

**Steps**:

1. **Create test issues on GitHub**
   ```bash
   ISSUE4=$(gh issue create --repo username/taskwarrior-sync-test \
     --title "Test Issue 4 - Pull sync" \
     --body "Testing pull from GitHub" \
     --label "priority:high,bug" | grep -oP '#\K\d+')
   
   ISSUE5=$(gh issue create --repo username/taskwarrior-sync-test \
     --title "Test Issue 5 - Pull sync" \
     --body "Testing pull from GitHub" \
     --label "priority:medium,feature,enhancement" | grep -oP '#\K\d+')
   ```

2. **Create tasks and enable sync**
   ```bash
   task add "Placeholder for issue 4" +testing
   TASK4_ID=$(task +testing limit:1 _ids | tail -1)
   
   task add "Placeholder for issue 5" +testing
   TASK5_ID=$(task +testing limit:1 _ids | tail -1)
   
   github-sync enable $TASK4_ID $ISSUE4 username/taskwarrior-sync-test
   github-sync enable $TASK5_ID $ISSUE5 username/taskwarrior-sync-test
   ```

3. **Modify issues on GitHub**
   ```bash
   # Update issue 4
   gh issue edit $ISSUE4 --repo username/taskwarrior-sync-test \
     --title "Test Issue 4 - Updated on GitHub" \
     --add-label "urgent"
   
   # Add comment to issue 4
   gh issue comment $ISSUE4 --repo username/taskwarrior-sync-test \
     --body "This is a test comment from GitHub"
   
   # Close issue 5
   gh issue close $ISSUE5 --repo username/taskwarrior-sync-test
   ```

4. **Pull changes**
   ```bash
   github-sync pull
   ```

5. **Verify in TaskWarrior**
   ```bash
   # Check task 4
   task $TASK4_ID info
   # Expected: Title updated, priority H, tags include bug and urgent
   
   # Check annotations
   task $TASK4_ID export | jq '.[0].annotations'
   # Expected: Annotation with [GitHub @username] prefix
   
   # Check task 5
   task $TASK5_ID info
   # Expected: Status completed, priority M, tags include feature and enhancement
   ```

6. **Test metadata population**
   ```bash
   task $TASK4_ID export | jq '.[0] | {githubissue, githuburl, githubrepo, githubauthor}'
   # Expected: All metadata fields populated
   ```

**Expected Results**:
- ✅ Issue titles sync to task descriptions
- ✅ Issue state maps to task status (OPEN→pending, CLOSED→completed)
- ✅ Priority labels map to task priority (priority:high→H, priority:medium→M, priority:low→L)
- ✅ Issue labels sync to task tags
- ✅ Issue comments sync to task annotations with [GitHub @username] prefix
- ✅ Metadata UDAs populated (githubissue, githuburl, githubrepo, githubauthor)
- ✅ Comments with [TaskWarrior] prefix are skipped (no duplicates)

---

### Test 24.3: Bidirectional Sync with Conflicts

**Objective**: Verify conflict resolution works correctly using last-write-wins strategy.

**Steps**:

1. **Create and link a test task/issue**
   ```bash
   ISSUE6=$(gh issue create --repo username/taskwarrior-sync-test \
     --title "Test Issue 6 - Conflict test" \
     --body "For testing conflicts" | grep -oP '#\K\d+')
   
   task add "Test task 6 - Conflict test" +testing
   TASK6_ID=$(task +testing limit:1 _ids | tail -1)
   
   github-sync enable $TASK6_ID $ISSUE6 username/taskwarrior-sync-test
   ```

2. **Create a conflict scenario**
   ```bash
   # Modify task locally
   task $TASK6_ID modify "Task modified locally" priority:H
   
   # Modify issue on GitHub (without syncing)
   gh issue edit $ISSUE6 --repo username/taskwarrior-sync-test \
     --title "Issue modified on GitHub" \
     --add-label "priority:low"
   
   # Wait a few seconds to ensure different timestamps
   sleep 3
   
   # Modify task again (to make it newer)
   task $TASK6_ID modify +urgent
   ```

3. **Run bidirectional sync**
   ```bash
   github-sync sync $TASK6_ID
   ```

4. **Verify conflict resolution**
   ```bash
   # Check which side won (should be task since it was modified last)
   task $TASK6_ID info
   gh issue view $ISSUE6 --repo username/taskwarrior-sync-test
   
   # Check conflict log
   cat $WORKWARRIOR_BASE/.task/github-sync/errors.log | jq 'select(.type=="conflict_resolution")'
   ```

5. **Test opposite scenario (GitHub wins)**
   ```bash
   # Modify task
   task $TASK6_ID modify "Task modified first"
   
   # Wait and modify issue (to make it newer)
   sleep 3
   gh issue edit $ISSUE6 --repo username/taskwarrior-sync-test \
     --title "Issue modified second - should win"
   
   # Sync
   github-sync sync $TASK6_ID
   
   # Verify GitHub won
   task $TASK6_ID info
   # Expected: Description matches GitHub title
   ```

**Expected Results**:
- ✅ Conflicts are detected when both sides change
- ✅ Last-write-wins resolution works correctly
- ✅ Timestamp comparison is accurate
- ✅ GitHub wins on equal timestamps (tiebreaker)
- ✅ Conflicts are logged to errors.log
- ✅ User is notified of conflict resolution

---

### Test 24.4: Error Correction Flow

**Objective**: Verify error handling and interactive correction works.

**Steps**:

1. **Test title validation error**
   ```bash
   # Create task with very long title (>256 chars)
   LONG_TITLE=$(python3 -c "print('A' * 300)")
   task add "$LONG_TITLE" +testing
   TASK7_ID=$(task +testing limit:1 _ids | tail -1)
   
   ISSUE7=$(gh issue create --repo username/taskwarrior-sync-test \
     --title "Test Issue 7" --body "For error testing" | grep -oP '#\K\d+')
   
   github-sync enable $TASK7_ID $ISSUE7 username/taskwarrior-sync-test
   
   # Try to push (should trigger truncation)
   github-sync push $TASK7_ID
   
   # Verify title was truncated
   gh issue view $ISSUE7 --repo username/taskwarrior-sync-test
   # Expected: Title truncated to 256 chars with "..."
   ```

2. **Test invalid label error**
   ```bash
   # Create task with invalid tag characters
   task add "Test task 8" +testing +"invalid label!" +"spaces in tag"
   TASK8_ID=$(task +testing limit:1 _ids | tail -1)
   
   ISSUE8=$(gh issue create --repo username/taskwarrior-sync-test \
     --title "Test Issue 8" --body "For error testing" | grep -oP '#\K\d+')
   
   github-sync enable $TASK8_ID $ISSUE8 username/taskwarrior-sync-test
   
   # Push (should sanitize labels)
   github-sync push $TASK8_ID
   
   # Verify labels were sanitized
   gh issue view $ISSUE8 --repo username/taskwarrior-sync-test
   # Expected: Labels sanitized (spaces→hyphens, special chars removed)
   ```

3. **Test permission error handling**
   ```bash
   # This test requires a repo without write access
   # Create task and try to sync to a read-only repo
   # Expected: Clear error message about permissions
   ```

**Expected Results**:
- ✅ Title truncation works automatically
- ✅ Label sanitization works automatically
- ✅ Permission errors display helpful messages
- ✅ Error messages include suggestions for fixes
- ✅ Errors are logged to errors.log

---

### Test 24.5: Batch Operations

**Objective**: Verify batch sync operations work correctly with multiple tasks.

**Steps**:

1. **Create 10+ test tasks and issues**
   ```bash
   # Create 12 tasks and issues
   for i in {1..12}; do
     ISSUE=$(gh issue create --repo username/taskwarrior-sync-test \
       --title "Batch test issue $i" \
       --body "For batch testing" \
       --label "batch-test" | grep -oP '#\K\d+')
     
     task add "Batch test task $i" +batch-test priority:M
     TASK_ID=$(task +batch-test limit:1 _ids | tail -1)
     
     github-sync enable $TASK_ID $ISSUE username/taskwarrior-sync-test
   done
   ```

2. **Modify multiple tasks**
   ```bash
   # Modify all batch test tasks
   task +batch-test modify priority:H
   task +batch-test modify +urgent
   ```

3. **Batch push**
   ```bash
   # Push all tasks
   time github-sync push
   
   # Verify summary shows correct counts
   # Expected: Total: 12, Success: 12, Failed: 0
   ```

4. **Modify multiple issues on GitHub**
   ```bash
   # Get all batch test issues
   gh issue list --repo username/taskwarrior-sync-test \
     --label "batch-test" --json number --jq '.[].number' | \
   while read issue_num; do
     gh issue edit $issue_num --repo username/taskwarrior-sync-test \
       --add-label "updated-on-github"
   done
   ```

5. **Batch pull**
   ```bash
   # Pull all tasks
   time github-sync pull
   
   # Verify all tasks have new label
   task +batch-test export | jq '.[].tags' | grep "updated-on-github"
   ```

6. **Batch bidirectional sync**
   ```bash
   # Modify some tasks and some issues
   task +batch-test limit:6 modify +local-change
   
   gh issue list --repo username/taskwarrior-sync-test \
     --label "batch-test" --json number --jq '.[].number' | \
   head -6 | while read issue_num; do
     gh issue edit $issue_num --repo username/taskwarrior-sync-test \
       --add-label "github-change"
   done
   
   # Sync all
   time github-sync sync
   
   # Verify summary
   # Expected: Shows push, pull, and conflict counts
   ```

7. **Test error resilience**
   ```bash
   # Disable one task's sync
   TASK_TO_BREAK=$(task +batch-test limit:1 _ids)
   github-sync disable $TASK_TO_BREAK
   
   # Try batch sync (should continue despite one failure)
   github-sync sync
   
   # Verify other tasks still synced
   # Expected: Summary shows 1 failed, 11 success
   ```

**Expected Results**:
- ✅ Batch operations process all tasks sequentially
- ✅ Summary displays correct counts (total, success, failed)
- ✅ Operations continue on errors (error resilience)
- ✅ Performance is acceptable (not too slow)
- ✅ No race conditions or data corruption
- ✅ Logs show all operations

---

## Verification Checklist

After completing all tests, verify:

### Functionality
- [ ] All 5 bidirectional fields sync correctly (description, status, priority, tags, annotations)
- [ ] All 7 pull-only metadata fields populate correctly
- [ ] System tags are excluded from sync
- [ ] Conflict resolution works (last-write-wins)
- [ ] Error handling works (validation, permission, rate limit)
- [ ] Batch operations work correctly
- [ ] Annotation/comment sync is bidirectional and idempotent

### Data Integrity
- [ ] No data loss during sync
- [ ] No duplicate annotations/comments
- [ ] State database is consistent
- [ ] Logs are accurate and complete
- [ ] Profile isolation works (no cross-profile contamination)

### User Experience
- [ ] Error messages are helpful
- [ ] Success messages are clear
- [ ] Progress is visible for batch operations
- [ ] Help text is accurate
- [ ] Commands work as documented

### Performance
- [ ] Single task sync completes in <5 seconds
- [ ] Batch sync (10 tasks) completes in <60 seconds
- [ ] No excessive API calls
- [ ] Logs don't grow too large

## Cleanup

After testing, clean up test data:

```bash
# Delete test tasks
task +testing rc.confirmation=off delete
task +batch-test rc.confirmation=off delete

# Close and delete test issues
gh issue list --repo username/taskwarrior-sync-test \
  --label "batch-test" --json number --jq '.[].number' | \
while read issue_num; do
  gh issue close $issue_num --repo username/taskwarrior-sync-test
  gh issue delete $issue_num --repo username/taskwarrior-sync-test --yes
done

# Clear sync state
rm -f $WORKWARRIOR_BASE/.task/github-sync/state.json
rm -f $WORKWARRIOR_BASE/.task/github-sync/*.log
```

## Troubleshooting

### Common Issues

1. **"gh: command not found"**
   - Install GitHub CLI: `brew install gh` (macOS) or see https://cli.github.com/

2. **"gh: authentication required"**
   - Run: `gh auth login`

3. **"Task not found"**
   - Verify task ID: `task list`
   - Check profile is active: `echo $WORKWARRIOR_BASE`

4. **"Permission denied"**
   - Verify repo access: `gh repo view username/repo`
   - Check token scopes: `gh auth status`

5. **Sync state corruption**
   - Reset state: `rm $WORKWARRIOR_BASE/.task/github-sync/state.json`
   - Re-enable sync for affected tasks

## Next Steps

After completing integration testing:
1. Document any bugs found
2. Fix critical issues
3. Update documentation based on test findings
4. Proceed to Task 25 (Documentation)
