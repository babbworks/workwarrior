## Verifier Sign-Off: TASK-STRUCT-1B — Rename system/ -> dev/, tests/ -> dev/tests/, stop shipping dev/

Verifier: Claude Verifier (inline; large-diff independent pass per Agent Execution Model)
Date: 2026-07-10
Task card reviewed: yes (full card, incl. solo + independent-verify requirement)
Implementation commit: 160e725

---

### 1. Test Results

[x] Full suite `bats dev/tests/` — PASS vs baseline
    Branch: 605 passed / 60 failed. Master: 605 passed / 60 failed.
    Failing-test NAME set byte-identical to master (diff clean). ZERO new failures.
[x] Regression FOUND then FIXED during this pass (see finding below): initial run was
    13/652 due to test-file relative root-derivation depth. After depth fix, full recovery.
[~] Integration suite (run-integration-tests.sh) — NOT run (environmental; needs active
    profile/gh auth). Same N1 condition as 1A; applies to the whole restructure branch.
[x] .sh test-service-discovery.sh "PROFILE_SERVICE_DIR readonly" failure — PRE-EXISTING
    (identical on master, line 17). Not introduced by 1B.

---

### 2. Acceptance Criteria

[x] AC1: git mv system dev + tests dev/tests (285 renames, history preserved) — PASS
[x] AC2: bin/ww-init.sh PATH -> dev/bin WITH added `[[ -d ]]` existence guard — PASS
[x] AC3: install.sh no longer copies system/dev; summary note updated — PASS
[x] AC4/AC5: system/ path refs rewritten to dev/ across dev tree + tooling files — PASS
    (docs/ deferred to Part 4 by Orchestrator scope decision — see finding N2*)
[x] AC6: `git grep '(^|[^a-z/])system/'` outside docs/ + root config/ = only the
    'system/internal' prose. — PASS
[x] AC7: dev/scripts/select-tests.sh + .claude/settings.local.json reference dev/tests — PASS
[x] AC8: scratch non-interactive install runs WITHOUT dev/: config/ (+5 runtime YAMLs)
    shipped, dev/ absent, field-mapper resolves maps in install layout — PASS
[x] AC9: `dev/bin/wwctl status` runs from repo (relative ROOT derivation) — PASS
[x] AC10: full suite at/above baseline — PASS (identical)

---

### 3. Write Scope Audit
Declared: system/->dev/ move, tests/->dev/tests/ move, install.sh, ww-init.sh, + reference
files. Actual (git diff -M): 285 renames + 14 modified (CLAUDE.md, .gitignore, install.sh,
ww-init.sh, lib/CLAUDE.md, .claude/*, service-overview stubs, readme.md, services/README.md,
dev/ internal). Within declared scope. [x] clean (docs/ intentionally untouched -> Part 4).

### 4. Simplify / 7. Gate E
[x] Diff > 200 lines -> standalone-simplifier threshold. Changes are mechanical moves +
    path-string rewrites + depth adjustments; no logic altered. Gate E: no new TODO/FIXME.

### 5. Gate C
[x] Agent-facing docs (root CLAUDE.md, dev/CLAUDE.md, ww-agent-guidance) repointed to dev/.
[!] docs/ prose (overviews + site mirror) still say system/ -> Part 4 (N2).

---

### Overall Verdict

[x] PASSED — all runnable gates satisfied; full suite identical to master; scratch install
    proves runtime independence from dev/; write scope clean. The one regression (depth) was
    caught by the master-vs-branch failing-set diff and fixed within this pass.

Non-blocking / tracked:
1. N1 — integration suite must run in an installed env before Part 1 merges to master
   (shared restructure-branch pre-merge condition).
2. N2 — docs/ system-path references (incl. docs/site mirror) reconciled by Part 4.
3. LEARNING — relative-root depth gotcha logged in dev/logs/decisions.md (2026-07-10);
   relevant to Part 3 / Part 4 relocations.

Verifier signature: Claude Verifier — 2026-07-10
