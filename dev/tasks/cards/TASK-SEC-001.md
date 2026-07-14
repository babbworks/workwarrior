## TASK-SEC-001: Purge machine/user identity from the shipped repo

Goal:                 The repo must contain NO reference to any individual's machine, username, or
                      home path. It currently contains 71 tracked files carrying `/Users/mp/...`
                      — a previous machine's paths — plus scattered `/home/<user>` references.

                      This became load-bearing on 2026-07-12 when we decided **dev/ SHIPS**. Every
                      one of those files now travels with the product.

Depends on:           —

Blocking?             NO for a PRIVATE remote. **YES before the repo is public or distributed.**

Scope of the leak (measured 2026-07-13):
  ✅ RUNTIME CODE IS CLEAN. `git grep` over lib/ bin/ services/ config/ install.sh finds
     ZERO hardcoded home paths. The shipped product does not leak anyone. Good.
  ⚠️  71 tracked files carry `/Users/mp/...`, concentrated in:
       - dev/config/command-syntax.yaml  (declares canonical_source: "/Users/mp/ww/dev/...")
       - dev/logs/decisions.md, dev/tasks/cards/*, dev/archive/*   (records — see below)
       - docs/*, .claude/ww/ww-agent-guidance.md, .tracking/*
  ⚠️  docs/ additionally hardcode instance names `~/wwv02` and `~/ww-dev` — NEITHER EXISTS on
     this host. Same disease, independently found by the backlog reconciliation.

Acceptance criteria:  1. `git grep -lI -e '/Users/' -e '/home/'` over TRACKED files returns nothing
                         outside of deliberately quoted historical prose (see criterion 4).
                      2. Live paths become variables: `$WW_BASE` / `$WORKWARRIOR_BASE` / `~/ww`.
                         `dev/config/command-syntax.yaml`'s `canonical_source` becomes a
                         repo-relative path, not an absolute one.
                      3. Docs stop naming a specific instance (`~/wwv02`, `~/ww-dev`). They point at
                         the REGISTRY (`~/.config/ww/registry/`) and the `instances()` function —
                         which already exists, as a shell function in lib/shell-integration.sh, and
                         is NOT a `ww` subcommand (`ww instances` errors — either add it or stop
                         implying it).
                      4. RECORDS ARE APPEND-ONLY — decisions.md, closed cards and verifier
                         sign-offs are NOT rewritten to change their meaning. Redacting a path is a
                         REDACTION, not a revision: replace the path, keep the sentence, and note at
                         the top of decisions.md that absolute paths were redacted on this date. If
                         a path is load-bearing to the record's meaning, quote it as `<instance>/...`.
                      5. `.gitignore` covers every `*.local.*` settings file. (`.claude/settings.local.json`
                         was untracked + ignored on 2026-07-13 — verify nothing else of the kind is tracked.)
                      6. A grep gate in CI (or dev/scripts/) so the leak cannot silently return.

Write scope:          dev/config/command-syntax.yaml
                      dev/logs/decisions.md, dev/tasks/cards/*, dev/archive/*   (REDACTION only)
                      docs/*, .claude/ww/ww-agent-guidance.md, .tracking/*
                      .gitignore
                      dev/scripts/check-identity-leak.sh   (new — the grep gate)

Tests required:       bash dev/scripts/check-identity-leak.sh   (must exit 0)
                      bash dev/scripts/check-regression.sh      (docs-only change; expect no delta)

Rollback:             git revert. Text-only.

Fragility:            LOW mechanically, MEDIUM in judgement. A blind find-and-replace across
                      decisions.md would corrupt the record of the rename that this repo already
                      learned the hard way (decisions.md 2026-07-13: a bulk `system/` -> `dev/`
                      rewrite hit prose DESCRIBING the rename and produced self-referential
                      nonsense — "rename `dev/` -> `dev/`"). The same trap applies here. Redact by
                      hand where the path is part of a sentence.

Risk notes:           (Orchestrator) The three rules this establishes are one rule, three times:
                        1. Never hardcode a home path — use the variable.
                        2. Never commit a `*.local.*` file — it is per-machine by definition.
                        3. Docs point at the registry, never at an instance name.
                      And they are the SAME rule that produced `wwctl index` and
                      `known-failures.txt`: **never hand-maintain a mirror of a fact that lives
                      somewhere authoritative. Derive it, or point at it.**

Status:               pending
Taskwarrior:          (assign live TW id on dispatch)
