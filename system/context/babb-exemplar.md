# babb — Exemplar Profile

The `babb` profile is the canonical demonstration of ww's full feature set.
It is the reference for how a well-configured ww profile looks and behaves.

---

## Profile Structure

```
profiles/babb/
  .taskrc                          # TaskWarrior config — UDAs, hooks, data path
  .task/                           # Task database (taskchampion.sqlite3)
  .task/hooks/on-modify.timewarrior  # Auto-start/stop TimeWarrior on task state change
  .timewarrior/                    # TimeWarrior database
  .config/bugwarrior/bugwarriorrc  # One-way GitHub issue pull config
  journals/babb.txt                # JRNL journal
  jrnl.yaml                        # JRNL config
  ledgers/babb.journal             # Hledger ledger
  ledgers.yaml                     # Ledger config
  seed-exemplar-tasks.sh           # Creates representative tasks (run once)
```

---

## Activation

```bash
p-babb          # activate profile (sets WORKWARRIOR_BASE, TASKRC, TASKDATA, etc.)
task            # list tasks
```

---

## GitHub Integration

### One-way pull (bugwarrior)

Pulls all open issues from `babbworks` org into TaskWarrior:

```bash
i pull          # pull GitHub issues → TaskWarrior
i status        # show bugwarrior sync state
```

Token: `@oracle:eval:gh auth token` — delegates to gh CLI keychain session.
No token ever written to disk.

### Two-way sync (ww github-sync)

Links a specific task to a specific GitHub issue for bidirectional sync:

```bash
github-sync enable <task-id> <issue-number> babbworks/workwarrior
github-sync push   # push local changes to GitHub
github-sync pull   # pull GitHub changes to local
github-sync status # show sync state for all linked tasks
```

Demo: `babbworks/workwarrior#1` is linked to the "Establish Master TASKDATA File" task.

---

## Time Tracking

TimeWarrior starts/stops automatically via the `on-modify.timewarrior` hook:

```bash
task <id> start   # starts timew automatically
task <id> stop    # stops timew automatically
timew summary     # view time log
timew day         # today's time breakdown
```

---

## Journalling

```bash
j                     # open babb journal in $EDITOR
j "quick note"        # append inline entry
ww journal list       # list all journals in profile
```

---

## Ledger

```bash
l                     # open babb.journal in $EDITOR
ww ledger balance     # account balances
ww ledger register    # transaction register
```

---

## Seeding Exemplar Tasks

Run once after activating the profile:

```bash
p-babb
bash profiles/babb/seed-exemplar-tasks.sh
```

Creates three tasks demonstrating: plain task with tags/priority, project task
with metadata UDAs, and a GitHub-linked task.

---

## UDA Notes

The `.taskrc` contains two families of GitHub UDAs:

| Family | Source | Fields |
|---|---|---|
| Bugwarrior | `i pull` | `githubnumber`, `githubuser`, `githubtitle`, `githubbody`, `githubstate`, etc. |
| ww github-sync | `github-sync` | `githubissue`, `githubauthor`, `githubsync`, `githubrepo`, `githuburl` |

`githubrepo` and `githuburl` are shared by both. The two engines are complementary:
bugwarrior pulls issues in bulk; github-sync provides two-way per-task sync.

---

## Known Token Sustainability

| Context | Approach | Status |
|---|---|---|
| Local machine (personal) | `@oracle:eval:gh auth token` | ✓ Sustainable — keychain + auto-refresh |
| Headless server / CI | Classic PAT or GitHub App token via `$GITHUB_TOKEN` | Requires manual setup |
