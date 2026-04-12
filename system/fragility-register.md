# Fragility Register — Workwarrior

This register defines access policies for high-risk files. All agents must consult this before including any listed file in a write scope. Orchestrator enforces these policies at contract time.

---

## Policy Levels

### HIGH FRAGILITY
Require all four of:
1. Explicit Orchestrator approval before Builder starts
2. Extended risk brief (3+ paragraphs: behavior affected, test coverage, rollback path, sync side effects)
3. Integration tests run against test profile (not just unit tests)
4. Dedicated Verifier sign-off line for the specific fragility concern

### SERIALIZED OWNERSHIP
- One writer at a time
- Never included in a parallel worktree alongside any other change
- Orchestrator must confirm no other active task touches this file before dispatching

### SENSITIVE — READ-ONLY FOR AGENTS
- Contains user data or credentials
- No agent may read or write these without explicit user confirmation

---

## Register

### GitHub Sync — HIGH FRAGILITY

These files implement two-way sync between TaskWarrior and GitHub Issues. Errors here can create or delete remote GitHub issues, corrupt local task data, or cause silent data loss.

| File | Risk |
|---|---|
| `lib/github-api.sh` | Direct GitHub REST API calls. Network side effects. Rate limiting. |
| `lib/github-sync-state.sh` | Sync state persistence. Corruption breaks incremental sync. |
| `lib/sync-pull.sh` | Pulls GitHub issues into TaskWarrior. Can overwrite local task data. |
| `lib/sync-push.sh` | Pushes local tasks to GitHub. Can create/modify/close remote issues. |
| `lib/sync-bidirectional.sh` | Orchestrates pull+push. Conflict window is highest here. |
| `lib/field-mapper.sh` | Maps fields between TaskWarrior and GitHub formats. Silent mapping errors cause data corruption. |
| `lib/sync-detector.sh` | Detects which side changed. False negatives skip sync; false positives cause spurious writes. |
| `lib/conflict-resolver.sh` | Last-write-wins logic. Wrong resolution direction causes permanent data loss. |
| `lib/annotation-sync.sh` | Syncs annotations/comments. Duplicate comment risk on repeated runs. |
| `services/custom/github-sync.sh` | User-facing sync CLI. All sync operations flow through here. |

**Required before any change to these files:**
- [ ] Orchestrator has approved the task card
- [ ] Builder has produced an extended risk brief
- [ ] Integration test profile exists and is configured with GitHub auth
- [ ] `./tests/run-integration-tests.sh` passes clean before the change
- [ ] Verifier sign-off includes: "GitHub sync integration tests pass on test profile"

---

### Core Dispatcher — SERIALIZED OWNERSHIP

| File | Risk |
|---|---|
| `bin/ww` | All service routing passes through this file. Conflicts produce broken CLI commands across all categories. |

**Policy:** No parallel tasks may include `bin/ww` in their write scope. The Orchestrator must confirm the file is not in any active task's write scope before assigning a new task that touches it.

---

### Shell Integration — SERIALIZED OWNERSHIP

| File | Risk |
|---|---|
| `lib/shell-integration.sh` | Injects aliases and shell functions for profile activation. Broken shell integration breaks the entire `p-<profile>` activation system. |

**Policy:** Same as `bin/ww`. One writer at a time.

---

### Profile Data — SENSITIVE, READ-ONLY FOR AGENTS

| Path Pattern | Risk |
|---|---|
| `profiles/*/. task/taskchampion.sqlite3` | Live task database. Direct writes corrupt task data. |
| `profiles/*/.task/hooks/` | TaskWarrior hook scripts. Wrong hooks run on every task operation. |
| `profiles/*/.taskrc` | Profile-specific TaskWarrior config. Agent writes may break profile isolation. |
| `profiles/*/.timewarrior/` | TimeWarrior tracking data. |
| `profiles/*/journals/` | User journal entries. |
| `profiles/*/ledgers/` | User ledger data. |

**Policy:** Agents must never write directly to profile data directories. All profile modifications go through `lib/profile-manager.sh` functions.

---

### Generated Artifacts — NEVER COMMIT

These files are in `.gitignore` and must never appear in commits.

```
**/.DS_Store
profiles/*/
.state/
.task/
__pycache__/
*.sqlite3
*.sqlite3-shm
*.sqlite3-wal
config/cmd-heuristics.yaml
config/cmd-heuristics-corpus.yaml
devsystem/
services/bookbuilder/
```

---

## Change Log

| Date | File | Change | Approved by |
|---|---|---|---|
| 2026-04-04 | Initial register | Created from planning document synthesis | Orchestrator |
