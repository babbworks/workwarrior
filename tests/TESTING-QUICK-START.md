# Testing Quick Start

## Unit Tests (BATS)

```bash
bats tests/                                                     # full suite (~370 tests, ~33 baseline failures expected)
bats tests/test-github-sync.bats tests/test-sync-state.bats    # strict CI gate — must be 0 failures
bash system/scripts/select-tests.sh <type> --run               # run tests for a specific change type
```

Change types: `lib` | `service` | `profile` | `shell_integration` | `bin_ww` | `github_sync`

See `tests/CLAUDE.md` for baseline failure list and per-file counts.

---

# Integration Testing - Quick Start

## Prerequisites

1. **Install GitHub CLI**
   ```bash
   brew install gh  # macOS
   # or visit https://cli.github.com/
   ```

2. **Authenticate**
   ```bash
   gh auth login
   ```

3. **Create Test Repository**
   - Go to GitHub and create a new repository (e.g., `username/taskwarrior-sync-test`)
   - Can be public or private
   - No need to initialize with README

4. **Activate Test Profile**
   ```bash
   source bin/ww
   p-test-profile  # Or create new: ww profile create test-profile
   ```

## Run Automated Tests

```bash
# Set test repository
export GITHUB_TEST_REPO="username/taskwarrior-sync-test"

# Run all tests
./tests/run-integration-tests.sh
```

## Manual Testing

For detailed manual testing, see `tests/integration-test-guide.md`.

Quick manual test:

```bash
# 1. Create a task
task add "Test sync" priority:H +testing

# 2. Create an issue
ISSUE=$(gh issue create --repo username/taskwarrior-sync-test \
  --title "Test Issue" --body "Testing" | grep -oP '#\K\d+')

# 3. Enable sync
github-sync enable 1 $ISSUE username/taskwarrior-sync-test

# 4. Modify and push
task 1 modify "Test sync - UPDATED"
github-sync push 1

# 5. Verify on GitHub
gh issue view $ISSUE --repo username/taskwarrior-sync-test
```

## Expected Results

✅ All automated tests should pass
✅ Manual tests should show correct sync behavior
✅ No errors in logs

## Troubleshooting

**Tests fail with "gh: command not found"**
- Install GitHub CLI: `brew install gh`

**Tests fail with "authentication required"**
- Run: `gh auth login`

**Tests fail with "repository not found"**
- Check: `gh repo view username/repo`
- Verify you have write access

**Sync fails with permission errors**
- Refresh token: `gh auth refresh -s repo`

## Next Steps

After tests pass:
1. Review logs: `cat $WORKWARRIOR_BASE/.task/github-sync/sync.log`
2. Check for any warnings or errors
3. Proceed to documentation (Task 25)

---

## CI

Two jobs run on every push and PR to `master`:

| Job | Files | Platforms | Blocks merge? |
|---|---|---|---|
| `sync-engine` | `test-github-sync.bats`, `test-sync-state.bats` | macOS + Linux | Yes |
| `full-suite` | `tests/*.bats` | Linux | No (informational) |

The full-suite job uploads a TAP report artifact. As baseline failures are fixed,
promote the relevant test files into the strict gate in `.github/workflows/workwarrior-tests.yml`.
