# TASKS.md — Workwarrior Canonical Task Board

**Source of truth for all open work. Orchestrator is the only agent that updates status fields.**
`pending/` is archive-only. Nothing new is written there.

Last updated: 2026-04-04
Current phase: Phase 1 — Foundation

---

## Active Tasks

---

### TASK-1.1: Write Root CLAUDE.md

```
Goal:                 Deploy a cold-startable project context file to the repo root.
Acceptance criteria:  A Claude agent with no prior context can read CLAUDE.md and know
                      the architecture, what it can/cannot touch, how to run tests, and
                      where its task is — without reading any other file.
Write scope:          /CLAUDE.md (project root only)
Tests required:       Manual cold-read validation by Orchestrator
Rollback:             Delete the file
Fragility:            None
Risk notes:           Source content from devsystem/claude/CLAUDE.md
Status:               pending
```

---

### TASK-1.2: Write services/CLAUDE.md

```
Goal:                 Deploy service contract context file so Builder agents can write
                      correct discoverable services without reading existing services.
Acceptance criteria:  A Builder agent can write a correct, discoverable Tier 1/2/3 service
                      without referencing services/README.md or any existing service script.
Write scope:          /services/CLAUDE.md
Tests required:       Manual cold-read validation by Orchestrator
Rollback:             Delete the file
Fragility:            None
Risk notes:           Source content from devsystem/claude/services-CLAUDE.md
Status:               pending
```

---

### TASK-1.3a: Explorer A — Docs/Status Drift Audit

```
Goal:                 Produce a contradiction matrix categorizing every completion claim
                      in status/docs files against implementation reality.
Acceptance criteria:  Every task in pending/IMPLEMENTATION_STATUS.md is categorized as
                      one of: confirmed-complete, overclaimed, undocumented, or genuinely-
                      incomplete. Each category entry cites implementation evidence.
Write scope:          devsystem/claude/outputs/explorer-a-report.md (new file, create dir)
Tests required:       N/A (read-only audit)
Rollback:             N/A
Fragility:            None — read-only
Risk notes:           Read: pending/IMPLEMENTATION_STATUS.md, pending/OUTSTANDING.md,
                      pending/*SUMMARY*.md, docs/IMPLEMENTATION-COMPLETE.md,
                      docs/RELEASE-CHECKLIST.md, docs/github-sync-*.md.
                      Use template: devsystem/claude/templates/explorer-a-output.md
Status:               pending
```

---

### TASK-1.3b: Explorer B — Code/Test Reality Audit

```
Goal:                 Produce a code-vs-doc gap list, test coverage map by module, and
                      required test baseline per change type.
Acceptance criteria:  (1) Every lib/ file has a coverage classification (covered/gap-critical/
                      gap-important/gap-deferred). (2) Every TODO in lib/github-*.sh and
                      lib/sync-*.sh is identified and classified. (3) Required test baseline
                      per change type is defined (lib/service/profile/sync).
Write scope:          devsystem/claude/outputs/explorer-b-report.md (new file)
Tests required:       N/A (read-only audit)
Rollback:             N/A
Fragility:            None — read-only
Risk notes:           Read: all lib/github-*.sh, lib/sync-*.sh (TODOs + dry-run paths);
                      all tests/ files (what they cover); all services/ help strings
                      (docs/help parity). Focus GitHub sync dry-run behavior and
                      error handling paths.
                      Use template: devsystem/claude/templates/explorer-b-output.md
Status:               pending
```

---

### TASK-1.4: Build Canonical TASKS.md

```
Goal:                 Replace this seeded task board with a fully populated one that
                      reflects verified project truth, 8-field task cards for all open
                      work, and a fragility register.
Acceptance criteria:  (1) Every open task has an 8-field card. (2) Every completion claim
                      from Explorer A is categorized with evidence. (3) Fragility register
                      names specific files and policies. (4) No open items in pending/ lack
                      a corresponding card here.
Write scope:          /TASKS.md (project root)
Tests required:       Orchestrator review against Explorer A + B outputs
Rollback:             Restore this seeded version from devsystem/claude/TASKS.md
Fragility:            None
Risk notes:           Depends on TASK-1.3a and TASK-1.3b both complete.
                      Test baseline definition from Explorer B goes into CLAUDE.md amendment.
Status:               pending
```

---

### TASK-1.5: Artifact Cleanup

```
Goal:                 Ensure .gitignore excludes all generated artifacts so future PRs
                      carry no noise in their diffs.
Acceptance criteria:  git status on a clean working tree shows none of: .DS_Store, .sqlite3,
                      github-sync logs, generated sync config, profile list data.
Write scope:          /.gitignore only (plus git rm --cached for already-tracked artifacts)
Tests required:       git status check post-cleanup
Rollback:             git checkout .gitignore && git restore --staged <files>
Fragility:            Low — .gitignore only
Risk notes:           Items to add: **/.DS_Store, profiles/*/.task/taskchampion.sqlite3,
                      profiles/*/.task/github-sync/, profiles/*/.config/,
                      profiles/*/list/, devsystem/claude/outputs/
Status:               pending
```

---

## Completed Tasks

*None yet. Confirmed-complete tasks will be moved here with evidence citations after TASK-1.4 reconciliation.*

---

## Deferred Tasks

*Items explicitly out of current scope but tracked to satisfy Gate E.*

*Will be populated from Explorer A + B outputs during TASK-1.4.*

---

## Fragility Register

*Will be populated during TASK-1.4 from Explorer B output.*

Interim entries (known before audit):

| File(s) | Classification | Policy |
|---|---|---|
| `lib/github-api.sh` | HIGH FRAGILITY | Orchestrator approval + extended risk brief + integration tests against test profile |
| `lib/github-sync-state.sh` | HIGH FRAGILITY | Same as above |
| `lib/sync-pull.sh` | HIGH FRAGILITY | Same as above |
| `lib/sync-push.sh` | HIGH FRAGILITY | Same as above |
| `lib/sync-bidirectional.sh` | HIGH FRAGILITY | Same as above |
| `lib/field-mapper.sh` | HIGH FRAGILITY | Same as above |
| `lib/sync-detector.sh` | HIGH FRAGILITY | Same as above |
| `lib/conflict-resolver.sh` | HIGH FRAGILITY | Same as above |
| `lib/annotation-sync.sh` | HIGH FRAGILITY | Same as above |
| `services/custom/github-sync.sh` | HIGH FRAGILITY | Same as above |
| `bin/ww` | SERIALIZED | One writer at a time; never parallel with other changes |
| `lib/shell-integration.sh` | SERIALIZED | One writer at a time; profile activation depends on this |

---

## Phase Boundary Rules

**Phase 1 exit criteria (all must be true):**
- [ ] Root CLAUDE.md and services/CLAUDE.md deployed and pass cold-read test
- [ ] TASKS.md rebuilt with all open tasks as 8-field dispatchable cards
- [ ] pending/ is archive-only
- [ ] Every completion claim categorized with evidence
- [ ] GitHub sync fragility documented with named files and policy
- [ ] Required test baseline per change type defined and in root CLAUDE.md
- [ ] git status shows no artifact noise

**Phase 2 prerequisites (before any lib/ work begins):**
- [ ] lib/CLAUDE.md authored by Docs agent using Explorer B output
- [ ] tests/CLAUDE.md authored by Docs agent using Explorer B coverage map
