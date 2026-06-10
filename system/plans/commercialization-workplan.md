# Workwarrior Commercialization Work Plan

**Purpose:** Address every finding from the 2026-06-10 full-codebase audit and build the auth + telemetry foundation for a commercially supported edition. Personal use stays first-class; AI agents and factory machines become first-class.

**Format:** Parts → chunks → task cards + journal entries, matching the Workwarrior method. Cards use the canonical `tasks/cards/` schema. Journal entries use jrnl format with `@project` / `@tags` / `@priority` metadata markers.

---

## Part 0 — Ingestion Instructions (for the local agent reading this)

You are populating the local Workwarrior instance from this document. Follow the standing work routine:

1. `eval "$(ww agent init --instance <instance> --profile ww-development)"` and confirm `wwctl status` before any write.
2. For each task card below: create the card file at `system/tasks/cards/<ID>.md` verbatim, then register it on the board. **Do not dispatch.** All cards land as `status: pending` in the Dispatch Queue. Gate A still applies — the Orchestrator ratifies acceptance criteria before any Builder touches a card. Treat the criteria below as drafted, not approved.
3. Create one TaskWarrior task per card (`task add <title> project:<area> +commercialization`), record the returned UUID into the card's `tw_uuid:` field. Resolve UUIDs immediately per the UUID rule — never reference tasks by volatile ID.
4. Append each journal entry below to the `ww-development` journal via `jrnl`, preserving the metadata markers.
5. Update `system/tasks/INDEX.md` and the Dispatch Queue table in `system/TASKS.md` (Orchestrator-only write — if you are not in the Orchestrator role, stop and hand off).
6. Numbering: areas `LIC`, `PORT`, `LOCK`, `SEC`, `AUTH`, `TEL`, `REL`, `BIZ` are new — start at 001. Area `AGENT` already has TASK-AGENT-001 — this plan starts at AGENT-002. TASK-CI-001 and TASK-TEST-003 already exist — this plan references them, do not recreate.
7. HIGH FRAGILITY rules apply unchanged: nothing in this plan authorizes touching `lib/github-*.sh`, `lib/sync-*.sh`, or `bin/ww` outside a card's explicit Write Scope.

Sequencing intent: Part 1 unblocks everything. Part 2 (auth) and Part 3 (attribution) can run in parallel after Part 1 chunk 1.3. Part 4 (telemetry) depends on Parts 2–3. Part 5 runs alongside and gates the commercial claim.

---

## Part 1 — Foundation: Legal, Portability, Concurrency

Nothing commercial can be claimed, shipped, or even safely demoed until these close. Smallest chunk, highest leverage.

### Chunk 1.1 — Legal standing

---
id: TASK-LIC-001
title: Add root LICENSE file and ratify the open-source license
status: pending
priority: H
area: lic
created: 2026-06-10
tw_uuid:
depends: —
---

## Goal

The repository has no LICENSE file, no COPYING, no SPDX headers. Legally the code is "all rights reserved," which blocks both community adoption and our own dual-licensing. Choose and commit the license that the commercial strategy rests on.

## Context

Vendored components are already MIT-attributed (tools/list — Steve Losh; task-warlock — jonestristand; task-gun — hamzamohdzubair; density code — 00sapo). package.json pulls @google/generative-ai (Apache 2.0). The project license must be compatible with all of these.

## Acceptance Criteria

- [ ] Operator decision recorded in `system/logs/decisions.md`: license choice with rationale (recommendation: Apache 2.0 — patent grant matters once factory-floor deployments exist; MIT acceptable; copyleft would complicate the commercial edition)
- [ ] `LICENSE` file at repo root
- [ ] `readme.md` licensing section added
- [ ] Confirmed compatibility with every vendored license

## Write Scope

`LICENSE` (new), `readme.md`, `system/logs/decisions.md`

## Risk

None technical. Strategic: license choice is effectively irreversible once outside contributions arrive. Decide before publicizing, not after.

## Rollback

Revert commit. Only safe before external contributions exist — which is exactly why this is first.

---
id: TASK-LIC-002
title: ATTRIBUTION.md + SPDX headers across shipped source
status: pending
priority: H
area: lic
created: 2026-06-10
tw_uuid:
depends: TASK-LIC-001
---

## Goal

Every shipped source file carries `# SPDX-License-Identifier: <license>`; a root `ATTRIBUTION.md` lists all vendored code with original licenses preserved.

## Acceptance Criteria

- [ ] SPDX header in every file under `bin/`, `lib/`, `services/`, `functions/`, `weapons/`, `install.sh`, `uninstall.sh`
- [ ] `ATTRIBUTION.md` covers tools/list, warlock, gun, density, @google/generative-ai
- [ ] BATS check: new test asserts SPDX presence on shipped scripts (becomes a Gate B item for new files)

## Write Scope

All shipped scripts (header-only mechanical change), `ATTRIBUTION.md` (new), `tests/test-license-headers.bats` (new)

## Risk

Low. Mechanical, but touches SERIALIZED files (`bin/ww`, `lib/shell-integration.sh`) — schedule as a single serialized pass, no parallel writers.

## Rollback

Revert commit.

### Chunk 1.2 — Portability and CI truth

---
id: TASK-PORT-001
title: Fix BSD-only date parsing in conflict-resolver — Linux support for sync
status: pending
priority: H
area: port
created: 2026-06-10
tw_uuid:
depends: —
---

## Goal

`lib/conflict-resolver.sh:22-31` uses macOS-only `date -j` in every branch with no GNU fallback. On Linux all timestamp parses fail and GitHub conflict resolution returns "Failed to parse timestamps" on every conflict. Add a portable epoch-parse helper and use it.

## Context

HIGH FRAGILITY file — Orchestrator approval + extended risk brief + integration tests required before Builder dispatch. The helper belongs in `lib/core-utils.sh` (`ww_parse_iso_epoch()`): try GNU `date -d`, fall back to BSD `date -j`, fall back to `python3 -c` as last resort. While in there: audit the repo for the sibling bug (`sed -i ''` BSD form — confirmed in `services/warlock/warlock.sh:56`).

## Acceptance Criteria

- [ ] `ww_parse_iso_epoch()` in core-utils.sh handles TaskWarrior (`20240115T103000Z`) and ISO 8601 (`2024-01-15T10:30:00Z`) formats on both GNU and BSD date
- [ ] conflict-resolver.sh uses the helper exclusively; no `date -j` literals remain outside the helper
- [ ] Repo-wide grep for `date -j` and `sed -i ''` clean or each instance ported
- [ ] New BATS suite `tests/test-date-portability.bats` passes on Linux; equal-timestamp tie behavior explicitly asserted and documented (current silent GitHub bias becomes an explicit, logged choice)
- [ ] `bats tests/test-github-sync.bats` + full suite green

## Write Scope

`lib/core-utils.sh`, `lib/conflict-resolver.sh` (HIGH FRAGILITY), `services/warlock/warlock.sh`, `tests/test-date-portability.bats` (new)

## Risk

Medium-high: conflict resolution is the sync correctness layer; a wrong epoch silently picks the wrong side and loses edits. Mitigate with table-driven tests covering both formats × both platforms × tie cases.

## Rollback

Revert; macOS behavior is unchanged by the helper's BSD branch, so rollback restores status quo exactly.

---
id: TASK-PORT-002
title: Genericize docs and examples — remove author-machine coupling
status: pending
priority: M
area: port
created: 2026-06-10
tw_uuid:
depends: —
---

## Goal

Docs reference `/Users/mp/Documents/Vaults/babb/repos/ww/`, `~/wwv02`, `~/ww-dev`, and a 23-profile production instance. A fresh user (or customer evaluator) on Linux has zero profiles and none of these paths. Replace with `$WORKWARRIOR_BASE`-relative, single-instance-first documentation; keep the three-instance pattern as an explicitly labeled "maintainer workflow" appendix.

## Acceptance Criteria

- [ ] No `/Users/mp` paths anywhere in `docs/`, `system/`, `readme.md`, `sync.sh` examples
- [ ] `ww agent init` examples work on a fresh single-instance install
- [ ] A "first 10 minutes on Linux" guide exists in `docs/guides/`
- [ ] `.community/community.db` removed from git tracking, gitignored, regenerated-on-first-use or shipped as template (repo hygiene finding)

## Write Scope

`docs/`, `system/ONBOARDING.md`, `system/dev-instance.md`, `sync.sh` comments, `.gitignore`, `.community/`

## Risk

Low. Docs-only plus one gitignore change. The community.db removal needs a migration note for existing installs.

## Rollback

Revert.

> CI: re-enablement is already carded as **TASK-CI-001** (depends TASK-TEST-003). This plan raises its priority to HIGH and adds one criterion: the CI matrix must include ubuntu-latest AND macos-latest so TASK-PORT-001 stays fixed. Orchestrator to amend the existing card; do not duplicate.

### Chunk 1.3 — Concurrency primitives (gates Parts 2–4)

---
id: TASK-LOCK-001
title: Locking + atomic-write primitives in lib — flock and rename patterns
status: pending
priority: H
area: lock
created: 2026-06-10
tw_uuid:
depends: —
---

## Goal

Zero locking exists in the codebase (`grep -r flock` is empty). Build the shared primitives every multi-writer feature will use: `ww_with_lock <lockfile> <fn>` (flock with timeout + stale detection) and `ww_atomic_write <target>` (temp file + fsync + rename in same filesystem).

## Context

This is the foundation card for the agent and telemetry tracks. It ships primitives + tests only; adoption happens in dependent cards. Lock files live under `$WORKWARRIOR_BASE/.locks/`. Must honor the lib rules: sourced file, no `set -euo pipefail`, return codes not exits, `${var:-}` guards.

## Acceptance Criteria

- [ ] `lib/lock-utils.sh` (new) with `ww_with_lock`, `ww_atomic_write`, `ww_lock_status`; degrades with a clear error where `flock` is absent (macOS without coreutils — document `brew install flock` or use mkdir-lock fallback)
- [ ] Contention test: 10 parallel writers × 100 increments via `ww_with_lock` produce exactly 1000 — run in CI
- [ ] Crash test: killed writer leaves no stale lock that blocks longer than the timeout
- [ ] `lib/CLAUDE.md` Library Map updated (Docs role)

## Write Scope

`lib/lock-utils.sh` (new), `tests/test-lock-utils.bats` (new), `lib/CLAUDE.md`

## Risk

Medium: a buggy lock is worse than no lock (false confidence). The mkdir-fallback path needs the same contention test as the flock path.

## Rollback

Delete lib file; nothing depends on it until dependent cards land.

---
id: TASK-LOCK-002
title: Adopt locking in known-racy paths — session registry, shared appends
status: pending
priority: H
area: lock
created: 2026-06-10
tw_uuid:
depends: TASK-LOCK-001
---

## Goal

Fix the three confirmed race conditions: (1) `ww agent init` read-modify-write of `~/.local/share/ww/agent-sessions.json` — two simultaneous inits corrupt it; (2) unguarded `include` appends to shared ledger/journal files (`bin/ww:1663` area); (3) browser server active-profile file write (`services/browser/server.py:648`) — port the atomic-rename pattern to the Python side.

## Acceptance Criteria

- [ ] 10 parallel `ww agent init` calls produce a valid JSON registry with 10 sessions — BATS test
- [ ] Shared-file appends route through `ww_with_lock` + `ww_atomic_write`
- [ ] server.py profile switch uses tempfile + `os.replace`
- [ ] Full suite green; smoke unaffected

## Write Scope

`bin/ww` (SERIALIZED — single Builder, no parallel work on this file), `services/browser/server.py`, `tests/test-agent-sessions-concurrent.bats` (new)

## Risk

Medium. `bin/ww` is serialized-ownership; schedule when no other bin/ww card is active.

## Rollback

Revert; behavior returns to current (racy) state, no data migration involved.

### Part 1 journal entries

[2026-06-10 09:00] Audit verdict accepted: foundation before features. @project:commercialization @tags:audit,foundation,decision @priority:H
Four-track audit (browser, core/libs, agent-telemetry fitness, packaging) confirmed first-hand: no LICENSE anywhere, no flock anywhere, browser binds 0.0.0.0 unauthenticated, conflict resolver is BSD-date-only so Linux sync conflict handling is dead on arrival. Decision: Part 1 is non-negotiable sequencing — license and locking land before any auth or telemetry code is written, because both tracks build directly on lock-utils and both are pointless to publicize while the repo is legally unlicensed.

[2026-06-10 09:20] License recommendation logged for operator ratification. @project:commercialization @tags:licensing,decision @priority:H
Recommending Apache 2.0 over MIT: the telemetry roadmap puts this software next to factory equipment, where the explicit patent grant and contribution terms matter to procurement departments. All vendored MIT components are compatible. Copyleft rejected: it would entangle the planned commercial edition. Awaiting operator sign-off in decisions.md — this is the one decision in the plan that cannot be delegated.

---

## Part 2 — Auth & Access Control

The browser server is the only network surface today, and it has none of: bind restriction, identity, sessions, CSRF defense, rate limits, TLS. Commercial deployments (shared hosts, factory networks, remote support) need all of them. Build identity once, in layers, so the personal use case stays zero-friction: **localhost with no config keeps working exactly as today.**

Design spine for the whole part: a single identity model — **principals** (human operator, named agent, named machine source) carrying **scopes** (`read`, `write`, `ingest`, `admin`) over **profiles**. Browser auth (this part), agent attribution (Part 3), and telemetry ingestion (Part 4) all authenticate as principals against the same registry. One model, three doors.

### Chunk 2.1 — Close the open door

---
id: TASK-AUTH-001
title: Browser server binds 127.0.0.1 by default; explicit --bind to widen
status: pending
priority: H
area: auth
created: 2026-06-10
tw_uuid:
depends: —
---

## Goal

`server.py:5907` binds `("", port)` — all interfaces, no auth. Default must become `127.0.0.1`. Widening requires an explicit `ww browser start --bind <addr>` and, once TASK-AUTH-003 lands, refuses non-loopback binds unless token auth is enabled.

## Acceptance Criteria

- [ ] Default bind 127.0.0.1; `--bind` flag plumbed through browser.sh → server.py
- [ ] Non-loopback bind without auth prints a refusal with remediation text (until AUTH-003, a `--insecure-bind` escape hatch with loud warning)
- [ ] `tests/test-browser.bats`: bind-address assertions added
- [ ] Docs: browser guide security section

## Write Scope

`services/browser/server.py`, `services/browser/browser.sh`, `tests/test-browser.bats`, `docs/guides/`

## Risk

Low. Anyone who deliberately exposed the port on a LAN loses access until they pass `--bind` — that is the point. Release note required.

## Rollback

Revert; old behavior restored.

---
id: TASK-AUTH-002
title: Origin validation + CSRF defense on all state-changing endpoints
status: pending
priority: H
area: auth
created: 2026-06-10
tw_uuid:
depends: TASK-AUTH-001
---

## Goal

POST `/cmd`, `/action`, `/profile`, `/cmd/ai` accept requests from any origin — a malicious web page can drive a logged-in user's local instance. Enforce: `Origin`/`Referer` must match the server's own host:port (or be absent for non-browser clients presenting a token per AUTH-003); reject otherwise with 403.

## Acceptance Criteria

- [ ] All mutating endpoints validate Origin; GET data endpoints send explicit restrictive CORS headers (no `Access-Control-Allow-Origin: *` anywhere)
- [ ] SSE endpoint unaffected for same-origin
- [ ] BATS: forged-Origin POST rejected; same-origin accepted; tokened CLI client (no Origin header) accepted
- [ ] Threat note added to `docs/` browser guide: what this defends against, what it doesn't

## Write Scope

`services/browser/server.py`, `tests/test-browser.bats`

## Risk

Low-medium: must not break the offline HTML export flow or curl-based scripting (token path covers it).

## Rollback

Revert.

### Chunk 2.2 — Identity: principals, tokens, scopes

---
id: TASK-AUTH-003
title: Principal registry + bearer-token auth layer
status: pending
priority: H
area: auth
created: 2026-06-10
tw_uuid:
depends: TASK-LOCK-001, TASK-AUTH-001
---

## Goal

Introduce the identity model everything else hangs on. `lib/principal-registry.sh` manages `$WORKWARRIOR_BASE/.auth/principals.json` (locked via lock-utils, atomic writes): principals of kind `operator|agent|machine`, each with a token hash (sha256, tokens shown once at creation), scopes, profile grants, created/last-seen timestamps, enabled flag.

CLI surface:
- `ww auth create <name> --kind machine --scopes ingest --profiles factory-line-2`
- `ww auth list | revoke <name> | rotate <name>`

Browser server: when auth is enabled (`.auth/` exists and policy is `required`), every request needs `Authorization: Bearer <token>` or a session cookie minted from a one-time token at `/login`. Localhost-with-no-principals continues working untouched — auth activates on first principal creation or first non-loopback bind.

## Context

This is the shared substrate for Part 3 (agents authenticate as `agent` principals; their principal name becomes the attribution identity) and Part 4 (machines authenticate as `machine` principals with `ingest`-only scope). Get the model right here and the later parts are adoption work, not design work.

## Acceptance Criteria

- [ ] Token hashes only at rest; raw token displayed once; rotation invalidates old token immediately
- [ ] Scope enforcement: `ingest`-scoped principal gets 403 on `/cmd` and `/action`; `read` gets 403 on all POSTs
- [ ] Profile grants enforced: principal granted `factory-line-2` cannot read or write `personal`
- [ ] Zero-config localhost behavior byte-identical to today (regression-tested)
- [ ] Brute-force guard: failed-auth rate limit per remote address with backoff
- [ ] BATS suite `tests/test-auth-principals.bats` + server tests; concurrent `ww auth create` safe (lock-utils)
- [ ] `services/CLAUDE.md` + lib/CLAUDE.md updated with the auth contract

## Write Scope

`lib/principal-registry.sh` (new), `services/browser/server.py`, `bin/ww` (SERIALIZED — `auth` subcommand routing), `services/auth/` (new service category), tests (new)

## Risk

High — this is security-bearing code. Mandatory Verifier adversarial pass: token timing comparison, hash truncation, scope-bypass attempts via path tricks on data endpoints, registry corruption under parallel writes. Simplifier review mandatory (diff will exceed 200 lines).

## Rollback

Delete `.auth/` directory → system reverts to open-localhost behavior by design. That degradation path is itself a test case.

---
id: TASK-AUTH-004
title: Rate limiting and request budgets on browser endpoints
status: pending
priority: M
area: auth
created: 2026-06-10
tw_uuid:
depends: TASK-AUTH-003
---

## Goal

`/cmd/ai` can be spammed into a local-LLM DoS, and `/cmd` spawns a subprocess per request with no ceiling. Add per-principal token-bucket limits (defaults: 10/s burst 30 for `/cmd` and `/action`; 1/s burst 5 for `/cmd/ai`), configurable in `config/auth.yaml`, returning 429 with Retry-After.

## Acceptance Criteria

- [ ] Limits enforced per principal (per remote addr for unauthenticated localhost)
- [ ] 429 carries `Retry-After`; SSE and static assets exempt
- [ ] Config documented; sensible defaults require no config for personal use
- [ ] Load test script in `tests/` demonstrating the cap

## Write Scope

`services/browser/server.py`, `config/auth.yaml` (new), tests

## Risk

Low-medium. Wrong defaults would annoy power users — defaults chosen above are >10× observed interactive rates.

## Rollback

Config switch `rate_limits: off`, or revert.

### Chunk 2.3 — Transport and remote access (commercial tier boundary)

---
id: TASK-AUTH-005
title: TLS support for non-loopback binds
status: pending
priority: M
area: auth
created: 2026-06-10
tw_uuid:
depends: TASK-AUTH-003
---

## Goal

Bearer tokens over plaintext HTTP on a factory LAN are credentials broadcast in the clear. Non-loopback binds must support TLS: `--tls-cert/--tls-key` flags (Python ssl stdlib, no new deps), plus documented reverse-proxy pattern (Caddy/nginx) as the recommended production path.

## Acceptance Criteria

- [ ] `wss`/`https` serving works with provided cert+key; SSE survives TLS
- [ ] Non-loopback + auth + no TLS prints a prominent warning (not a hard block — factory air-gapped LANs are a legitimate operator call)
- [ ] `docs/setups/` reverse-proxy guide with working Caddy example
- [ ] Self-signed quickstart documented for evaluation installs

## Write Scope

`services/browser/server.py`, `services/browser/browser.sh`, `docs/setups/`

## Risk

Low. Stdlib ssl; no certificate management ambitions in-core (that's the proxy's job).

## Rollback

Flags unused → no behavior change.

---
id: TASK-AUTH-006
title: Authenticated action audit log
status: pending
priority: M
area: auth
created: 2026-06-10
tw_uuid:
depends: TASK-AUTH-003
---

## Goal

Every authenticated mutating request (who, what endpoint, which profile, outcome, timestamp) appends to `$WORKWARRIOR_BASE/.auth/audit.log` (NDJSON, locked append, rotated by lib/logging.sh conventions). This is the operator-facing security log; Part 3's attribution chain is the work-history log — related but distinct, and the card for tamper-evidence lives there.

## Acceptance Criteria

- [ ] All POST endpoints logged with principal, scope used, exit status; failures (403/429) logged too
- [ ] `ww auth audit [--principal X] [--since ...]` reads it back human-readably
- [ ] Log rotation; no secrets (tokens never logged, even on failure)
- [ ] BATS coverage

## Write Scope

`services/browser/server.py`, `services/auth/`, `lib/logging.sh` (rotation hook), tests

## Risk

Low.

## Rollback

Config off-switch; log is append-only side data.

### Part 2 journal entries

[2026-06-10 10:00] Auth architecture settled: one principal model, three doors. @project:commercialization @tags:auth,architecture,decision @priority:H
Decision: do not build separate auth for browser, agents, and machine ingestion. One principal registry (operator/agent/machine kinds, scoped tokens, per-profile grants) under .auth/, consumed by the browser server now and by the ingest daemon later. Agents authenticate as principals, which makes Part 3 attribution an identity lookup rather than a new mechanism. Zero-config localhost personal use is a hard compatibility constraint — auth activates only when principals exist or bind widens. This is the open-core seam: single-operator auth is OSS; SSO/LDAP, central fleet policy, and org-level RBAC are the commercial layer.

[2026-06-10 10:15] Threat model boundary written down. @project:commercialization @tags:auth,security @priority:M
In scope: untrusted LAN peers, malicious web pages (CSRF), token theft via plaintext transport, runaway/abusive clients (rate limits), multi-writer registry corruption. Out of scope for core: OS-level compromise of the host, malicious operator, and certificate lifecycle management (delegated to reverse proxy). Documented so Verifier adversarial passes test against a stated boundary instead of an imagined one.

---

## Part 3 — Agent Attribution & Audit Trail

`WW_AGENT_SESSION_ID` exists but is never attached to any work — sessions are registered, then nothing references them. For "AI agents logging their work" to be a real product claim, every mutation must answer *who did this, in which session, on whose authority*, and the answer must survive after the fact.

---
id: TASK-AGENT-002
title: agent_session UDA + automatic stamping on all agent-context mutations
status: pending
priority: H
area: agent
created: 2026-06-10
tw_uuid:
depends: TASK-LOCK-002
---

## Goal

Define `agent_session` and `agent_principal` UDAs in the default profile taskrc template. When `WW_AGENT_SESSION_ID` is set, every task mutation that flows through ww (CLI dispatch and browser `/cmd`,`/action`) stamps both UDAs automatically — interceptor in the dispatch path, not opt-in per call site.

## Context

The UDA registry conventions live in profile templates (`resources/config-files/`). taskwarrior-api.sh `tw_update_task` has a field-value escaping gap (`lib/taskwarrior-api.sh:62` — `:` and quotes in values are concatenated raw); fix it here since this card makes programmatic writes routine.

## Acceptance Criteria

- [ ] New profiles get both UDAs; migration helper adds them to existing profiles (`ww profile migrate-udas`)
- [ ] With session env set: `ww task add/modify/done/annotate` all stamp; without it: zero stamping, zero overhead
- [ ] Browser-server mutations stamp from the server's own session identity (server runs as a principal once AUTH-003 lands)
- [ ] `tw_update_task` escaping fixed; injection test with `:`-laden and quoted values
- [ ] `task <filter> agent_session:<id>` reconstructs a session's full footprint — demonstrated in a BATS test
- [ ] task-conventions doc (AGENT-004) cross-references the stamping rule

## Write Scope

`bin/ww` (SERIALIZED), `lib/taskwarrior-api.sh`, `resources/config-files/`, `services/profile/`, tests

## Risk

Medium: dispatch-path interceptor touches everything; must be inert when env is unset. SERIALIZED scheduling on bin/ww.

## Rollback

UDA stamping behind `WW_ATTRIBUTION=off` env kill-switch; UDAs are additive data, safe to leave in place.

---
id: TASK-AGENT-003
title: Hash-chained session journal — tamper-evident agent work log
status: pending
priority: M
area: agent
created: 2026-06-10
tw_uuid:
depends: TASK-AGENT-002
---

## Goal

Annotations and UDAs are editable after the fact — fine for personal use, insufficient for "the agent's log is trustworthy." Add an append-only per-session log at `$WORKWARRIOR_BASE/.sessions/<session-id>.ndjson`: every stamped mutation appends `{ts, principal, session, op, uuid, fields, prev_hash, hash}` where `hash = sha256(prev_hash + canonical_json(entry))`. `ww agent log verify <session-id>` recomputes the chain.

## Acceptance Criteria

- [ ] Chain verifies green on an untouched log; any byte edit → verify names the first broken link
- [ ] Locked appends (lock-utils); 10 parallel mutations in one session keep a valid chain
- [ ] `ww agent log show <session-id>` human-readable; `--json` for machines
- [ ] Session close (`ww agent end`) seals the chain with a terminal entry; registry records final hash
- [ ] Performance: stamping+chaining adds <30ms per mutation (measured in test)

## Write Scope

`lib/session-log.sh` (new), `bin/ww` (SERIALIZED), `services/warrior/` or `services/auth/` for the verify command, tests

## Risk

Medium. Honest claim only: tamper-*evident*, not tamper-*proof* (an attacker with disk access can rewrite the whole chain; the registry-held final hash narrows that). Docs must state this precisely — overclaiming security is a commercial liability.

## Rollback

Kill-switch env; logs are side data.

---
id: TASK-AGENT-004
title: Write the missing task-conventions.md — UUID rule, parallel agents, attribution
status: pending
priority: H
area: agent
created: 2026-06-10
tw_uuid:
depends: —
---

## Goal

`CLAUDE.md` and ONBOARDING reference `system/context/task-conventions.md`; the file does not exist. Every agent session is being told to follow conventions that aren't written down. Write it: UUID-not-ID rule, annotation conventions, UDA registry, parallel sub-agent dispatch protocol (resolve UUIDs first, disjoint write sets, wall-clock tracking), and the new attribution rules from AGENT-002/003.

## Acceptance Criteria

- [ ] File exists and covers all referenced topics; no dangling references remain (repo-wide grep)
- [ ] Reviewed against `.claude/ww/ww-agent-guidance.md` for consistency — one canonical source, the other defers to it
- [ ] Linked from ONBOARDING read-order table

## Write Scope

`system/context/task-conventions.md` (new), `system/ONBOARDING.md`, `.claude/ww/ww-agent-guidance.md`

## Risk

None. Pure documentation debt with outsized confusion cost.

## Rollback

n/a

### Part 3 journal entries

[2026-06-10 11:00] Attribution is the product, not a feature flag. @project:commercialization @tags:agents,attribution,decision @priority:H
Audit found WW_AGENT_SESSION_ID registered but never attached to a single piece of work — the agent-logging story was plumbing with no payload. Decision: attribution rides the dispatch path (interceptor), never per-call opt-in, because an attribution system agents can forget to use is worthless as evidence. Identity comes from the Part 2 principal registry; the hash chain makes the log tamper-evident. This trio — identity, automatic stamping, verifiable log — is the commercial pitch to anyone running fleets of agents: you can prove what your agents did.

---

## Part 4 — Telemetry Ingestion: Factory Signals & Streams

The stated goal: receive signals and streams from well-known **and obscure** factory data feeds, and land them in a human-oriented system — telemetry a person reads as tasks, journal entries, and ledgers, not as a Grafana wall. Today there is no ingestion path at all: the stream service is a local file append, export is read-only, and `/cmd` is neither authenticated nor shaped for machines.

Architecture (one decision, then adapters forever after):

```
[adapters: mqtt|opcua|modbus|serial|file-drop|http|custom]
      → canonical NDJSON event
      → spool dir (per-source, disk-backed backpressure)
      → ww-ingestd (single writer, batched)
            → stream.log (locked append — raw, replayable truth)
            → semantic mapper (rules) → tasks / journal / ledger
```

Adapters are isolated processes speaking one canonical format to a spool directory — so an obscure protocol never touches core code, and a crashed adapter loses nothing (the spool persists). The ingest daemon is the **only** writer into profile data, which sidesteps the multi-writer problem at the architecture level rather than fighting it lock by lock.

### Chunk 4.1 — The spine

---
id: TASK-TEL-001
title: Canonical telemetry event schema + stream format v2
status: pending
priority: H
area: tel
created: 2026-06-10
tw_uuid:
depends: —
---

## Goal

Define the one event shape every adapter emits and every consumer reads. NDJSON, one event per line:

```json
{"v":1, "ts":"2026-06-10T14:03:22.118Z", "source":"line2-press04",
 "principal":"machine:line2-press04", "signal":"hydraulic.pressure",
 "value":182.4, "unit":"bar", "quality":"good",
 "seq":48211, "ctx":{"shift":"B","recipe":"AL-6061"}}
```

Required: `v, ts, source, signal, value`. `quality` ∈ good|uncertain|bad|stale (OPC UA-compatible). `seq` per-source monotonic for gap detection. `ctx` open object. Extend the existing stream Hollerith format (`<unix_ts> <OP> <action> <object> <ctx_json>`) to v2 carrying these events without breaking v1 lines.

## Acceptance Criteria

- [ ] Schema documented in `docs/` + JSON Schema file in `resources/schemas/telemetry-event.v1.json`
- [ ] Validator: `ww stream validate <file>` checks events against schema
- [ ] `services/stream/stream.sh` reads/writes v2 alongside v1; `replay` and `view` handle both
- [ ] Decision recorded: units are freeform strings v1, controlled vocabulary deferred (logged in decisions.md)
- [ ] Gap detection demonstrated: missing `seq` surfaces in `ww stream status`

## Write Scope

`services/stream/`, `resources/schemas/` (new), `docs/`, tests

## Risk

Low-medium: schema choices are forever (hence `v` field from day one).

## Rollback

v2 additive; v1 untouched.

---
id: TASK-TEL-002
title: Spool directory contract + ww-ingestd single-writer daemon
status: pending
priority: H
area: tel
created: 2026-06-10
tw_uuid:
depends: TASK-TEL-001, TASK-LOCK-001
---

## Goal

The heart of the telemetry system. Spool contract: adapters write `$WORKWARRIOR_BASE/.spool/<source>/<epoch>-<seq>.ndjson` via temp-file+rename (atomic, no partial reads); ingestd scans spools, validates against schema, appends to `stream/stream.log` in batches, moves consumed files to `.spool/<source>/done/` (retention-pruned). Daemon: `ww ingest start|stop|status|drain`, single instance enforced via lock-utils, batch window 1s or 500 events, crash-safe (consumed-marker after append, so worst case is duplicate-append which `seq` dedupes).

## Context

Single-writer-by-architecture: machines and adapters never touch task/journal data; only ingestd (and via it, the mapper in TEL-003) writes. Throughput target honest for v1: thousands of events/min sustained — far beyond human telemetry-reading capacity, well under time-series-DB territory, which we are explicitly not building. Position stream.log as the replayable buffer; heavy analytical history exports to the customer's historian.

## Acceptance Criteria

- [ ] Soak test: 3 simulated sources × 20 events/s × 10 min → zero loss, zero duplicates post-dedupe, stream.log valid
- [ ] kill -9 mid-batch → restart → drain completes with no loss (idempotent consume proven)
- [ ] Backpressure: ingestd stopped for an hour → spool accumulates → drain catches up; disk-watermark warning at configurable threshold
- [ ] `ww ingest status`: per-source rates, lag, last-seen, gap counts
- [ ] Daemon runs under systemd (unit file shipped in `resources/`) and plain nohup
- [ ] BATS + a python load-generator in `tests/telemetry/`

## Write Scope

`services/ingest/` (new category), `lib/spool-utils.sh` (new), `resources/systemd/` (new), tests

## Risk

High value, medium risk: it's new isolated code (no fragile-file contact), but it's the component a factory trusts with data. Verifier soak/crash testing is the bulk of the work — budget accordingly.

## Rollback

Stop daemon; spools persist on disk; nothing else changed.

---
id: TASK-TEL-003
title: Semantic mapper — telemetry events to tasks, journal entries, ledger lines
status: pending
priority: H
area: tel
created: 2026-06-10
tw_uuid:
depends: TASK-TEL-002, TASK-AGENT-002
---

## Goal

This is the differentiator: telemetry a human reads in their own workflow tool. Rule-driven mapping in `config/telemetry-rules.yaml`, evaluated by ingestd post-append:

```yaml
rules:
  - match: {signal: "state.fault", value: true}
    action: task
    template: "Fault on {source}: {ctx.fault_code}"
    fields: {project: "floor.{source}", priority: H, tags: [fault, telemetry]}
    dedupe: {key: "{source}:{ctx.fault_code}", window: 4h}   # no task storms
  - match: {signal: "shift.summary"}
    action: journal
    journal: floor-log
    template: "[{source}] Shift {ctx.shift}: {value} units, {ctx.scrap} scrap @tags:telemetry,shift"
  - match: {signal: "energy.kwh.total", on: delta}
    action: ledger
    template: "{ts}  energy:{source}  {delta} kWh"
  - match: {signal: "cycle.count"}
    action: none        # raw stream only; visible in browser, no artifact
```

All writes stamped with the machine principal via the Part 3 attribution path — a task created by line2-press04 says so, queryably.

## Acceptance Criteria

- [ ] Four action types work: task, journal, ledger, none; templates interpolate event fields safely (no shell eval — pure substitution)
- [ ] Dedupe windows prevent alert storms — tested with 1000 identical fault events → 1 task + 999 suppressed (counted on the task as an annotation)
- [ ] Threshold/delta matchers: `gt/lt/delta/changed` operators
- [ ] Rules hot-reload on file change; invalid rules rejected with line-numbered errors, last-good config retained
- [ ] Mapper failures never block raw stream append (append-first, map-after, errors to ingest log)
- [ ] End-to-end BATS: simulated press fault → task exists in target profile with machine attribution within 5s

## Write Scope

`services/ingest/`, `config/telemetry-rules.yaml` (template in `resources/config-files/`), `lib/taskwarrior-api.sh` (batch-add helper), tests

## Risk

Medium-high: rule templates touching task creation must be injection-proof (TASK-AGENT-002's escaping fix is a hard dependency). Dedupe correctness under load is the other sharp edge.

## Rollback

Empty rules file → raw stream only, zero artifacts.

### Chunk 4.2 — Front doors: network ingestion

---
id: TASK-TEL-004
title: Authenticated HTTP ingestion endpoint — POST /ingest, NDJSON batches
status: pending
priority: H
area: tel
created: 2026-06-10
tw_uuid:
depends: TASK-TEL-002, TASK-AUTH-003
---

## Goal

The universal adapter: anything that can speak HTTP can feed Workwarrior. `POST /ingest` on the browser server (and standalone in ingestd's own listener for headless installs): body is 1–N NDJSON events, auth via `machine`-kind bearer token with `ingest` scope, `source` forced to the principal's registered name (a machine cannot spoof another's identity), response `{accepted, rejected:[{line, reason}]}`. Writes land in the spool — the endpoint is a thin validated front door, not a second writer.

## Acceptance Criteria

- [ ] Batch of 500 events accepted in one POST; per-line validation errors reported, valid lines still accepted
- [ ] `ingest` scope can ONLY hit `/ingest` (cross-checked with AUTH-003 scope tests); source-spoofing attempt → 403
- [ ] Rate limit class for machines (higher than human endpoints, per-principal)
- [ ] Idempotency: replayed batch (same source+seq) deduped at ingestd
- [ ] curl one-liner + Python snippet in docs — the "connect your machine in 5 minutes" page
- [ ] Works over TLS (AUTH-005)

## Write Scope

`services/browser/server.py`, `services/ingest/`, `docs/guides/telemetry-quickstart.md` (new), tests

## Risk

Medium: this is the internet-adjacent surface. Verifier focus: auth bypass, oversized-body handling, malformed NDJSON, slowloris-style dribble.

## Rollback

Endpoint behind config flag `ingest_http: off`.

---
id: TASK-TEL-005
title: MQTT adapter — the factory lingua franca, incl. Sparkplug B awareness
status: pending
priority: H
area: tel
created: 2026-06-10
tw_uuid:
depends: TASK-TEL-002
---

## Goal

MQTT is the most common modern factory transport. `ww-adapter-mqtt`: subscribes to configured topics on a broker, maps topic+payload → canonical events into the spool. Config per source: broker, topics (wildcards), payload parser (`json|raw|sparkplug-b`), field mappings. Sparkplug B: decode metric names/values/timestamps from NBIRTH/NDATA (this covers a large slice of modern plant deployments in one move).

## Acceptance Criteria

- [ ] Plain JSON topics and Sparkplug B NDATA both land as valid canonical events (mosquitto-based integration test, vendored test vectors for Sparkplug)
- [ ] Broker disconnect → reconnect with backoff; events during outage are the broker's problem (QoS documented), adapter never crashes the spool
- [ ] TLS + username/password broker auth supported
- [ ] Python, stdlib + paho-mqtt as the single optional dep, installed via pipx pattern like other optional tooling
- [ ] Runs as its own systemd unit; `ww ingest adapters` lists it with health

## Write Scope

`services/ingest/adapters/mqtt/` (new), `resources/systemd/`, docs, tests

## Risk

Medium: external dep + long-running network client. Isolated process — worst case is a dead adapter, never corrupted core.

## Rollback

Stop unit; remove config.

---
id: TASK-TEL-006
title: OPC UA subscription adapter
status: pending
priority: M
area: tel
created: 2026-06-10
tw_uuid:
depends: TASK-TEL-002
---

## Goal

OPC UA is the industrial-automation standard interface to PLCs/SCADA (Siemens, Beckhoff, B&R...). `ww-adapter-opcua` (python-opcua/asyncua): connects to a server endpoint, subscribes to configured node IDs, maps data-change notifications → canonical events; OPC UA quality codes map directly onto the schema's `quality` field (the schema was designed for this).

## Acceptance Criteria

- [ ] Subscription against a test server (asyncua's example server in CI) produces correct events incl. quality mapping
- [ ] Security modes: None + Basic256Sha256 with cert; anonymous + user/pass auth
- [ ] Node browse helper: `ww ingest opcua browse <endpoint>` to discover node IDs during setup
- [ ] Reconnect/backoff; per-node deadband config to control event volume at the source

## Write Scope

`services/ingest/adapters/opcua/` (new), docs, tests

## Risk

Medium: OPC UA stacks are fussy across vendors. Scope honestly: subscriptions only, no method calls, no writes to PLCs — read-only by design, state that loudly (it is also the safety story).

## Rollback

Stop unit.

### Chunk 4.3 — The obscure feeds (where support contracts are won)

---
id: TASK-TEL-007
title: Modbus poller adapter — TCP and RTU-over-serial
status: pending
priority: M
area: tel
created: 2026-06-10
tw_uuid:
depends: TASK-TEL-002
---

## Goal

The 40-year-old workhorse: most legacy PLCs, power meters, and VFDs speak Modbus and nothing else. Polling adapter (Modbus has no push): per-device register maps in config (`address, count, type: holding|input|coil, decode: u16|s32|f32-be|..., scale, signal-name`), poll interval per device, TCP and RTU (serial RS-485 via pyserial).

## Acceptance Criteria

- [ ] Poll a simulated device (pymodbus test server) → correctly decoded, scaled events
- [ ] Register-map config validated with clear errors (wrong decode widths are the classic field failure)
- [ ] Word-order variants handled (big/little/word-swapped f32 — the obscure-feed reality)
- [ ] RTU line errors (CRC, timeout) → `quality: bad` events, not silence — a dead sensor should be *visible*
- [ ] Example maps shipped for two common meters (e.g., Eastron SDM630, generic VFD)

## Write Scope

`services/ingest/adapters/modbus/` (new), docs incl. register-map cookbook, tests

## Risk

Medium: decode/word-order bugs ship wrong *numbers*, which is worse than no numbers. Cookbook + validation are the mitigation.

## Rollback

Stop unit.

---
id: TASK-TEL-008
title: File-drop + serial line adapters — CSV shares, RS-232 scales and scanners
status: pending
priority: M
area: tel
created: 2026-06-10
tw_uuid:
depends: TASK-TEL-002
---

## Goal

The genuinely obscure feeds every plant has: a CNC that FTPs a CSV to a share at end of cycle; a scale that prints ASCII lines over RS-232; a barcode scanner in keyboard-wedge-over-serial mode; a logger that appends to a .txt on an SMB mount. Two small adapters:

**file-drop:** watch directories (poll-based — works on NFS/SMB where inotify lies), per-pattern parser config (`csv` with column→signal map, `regex` with named groups, `jsonl`), processed-file ledger so nothing is double-ingested, archival move after consume.

**serial:** pyserial line reader, per-port regex → signal extraction, framing options (newline/STX-ETX/fixed-length), the three encodings that actually occur (ascii, latin-1, utf-8).

## Acceptance Criteria

- [ ] CSV with header row, headerless CSV, and regex-parsed fixed-width all ingest correctly (fixture files)
- [ ] Partially-written file (still being copied) is not consumed early — size-stable check
- [ ] Serial: simulated port (socat pty) → events; garbage bytes → `quality: bad` + raw line preserved in ctx for diagnosis
- [ ] Cookbook doc: "your machine writes a file / talks serial — connect it in 15 minutes" with three worked real-world examples

## Write Scope

`services/ingest/adapters/filedrop/`, `services/ingest/adapters/serial/` (new), docs, tests

## Risk

Low-medium: parsers are fiddly but contained. The cookbook IS the commercial asset here — obscure-feed onboarding is what support contracts get bought for.

## Rollback

Stop units.

---
id: TASK-TEL-009
title: Adapter SDK + contract — third-party and customer-built adapters
status: pending
priority: M
area: tel
created: 2026-06-10
tw_uuid:
depends: TASK-TEL-002, TASK-TEL-005
---

## Goal

We will never ship every protocol (PROFINET, EtherNet/IP, BACnet, CANopen/J1939, IO-Link, S7-comm, MELSEC MC, Omron FINS, DNP3, MTConnect, Fanuc FOCAS, vendor CSV dialects without end...). Make the adapter boundary a documented public contract so integrators and customers build their own: an adapter is *any process* that writes canonical-schema NDJSON files into a spool directory via temp+rename. Ship `ww ingest scaffold <name> --lang python|bash` generating a working skeleton (spool writer, config loader, health file, systemd unit), plus a conformance test (`ww ingest conformance <spool-dir>`) that validates an adapter's output.

## Acceptance Criteria

- [ ] Contract doc: spool protocol, atomicity rule, schema ref, health-file convention, versioning policy
- [ ] Scaffold produces an adapter that passes conformance out of the box in both languages
- [ ] One community-style example in-tree: a tiny "random walk simulator" adapter used by the soak tests
- [ ] `services/CLAUDE.md` extended with the adapter tier

## Write Scope

`services/ingest/`, `docs/`, `resources/adapter-templates/` (new), tests

## Risk

Low. This card converts the obscure-protocol long tail from roadmap burden into ecosystem surface — strategically the most important telemetry card after the spine.

## Rollback

n/a (docs + scaffolding).

---
id: TASK-TEL-010
title: Browser telemetry panel — live stream, source health, mapped artifacts
status: pending
priority: M
area: tel
created: 2026-06-10
tw_uuid:
depends: TASK-TEL-003, TASK-TEL-004
---

## Goal

The human face of the telemetry story, in the existing browser UI: live event tail (SSE, already in the stack), per-source health cards (rate, lag, last-seen, gap count, quality ratio), and "artifacts from telemetry" view (tasks/journal entries created by the mapper, filterable by source — riding the `agent_principal` attribution from Part 3).

## Acceptance Criteria

- [ ] Panel follows existing section/drawer patterns in app.js; respects density + themes
- [ ] Live tail handles 50 events/s without freezing (virtualized list, capped buffer)
- [ ] Source health red/amber/green derived from configured expectations (a silent press is amber at 5 min, red at 30)
- [ ] All rendering escaped — telemetry strings are untrusted input (XSS test with hostile signal names)
- [ ] BATS server-side + the existing browser test pattern

## Write Scope

`services/browser/server.py` (`/data/telemetry/*` endpoints), `services/browser/static/`, tests

## Risk

Medium: app.js is already ~6,700 lines — follow TASK-SITE conventions; consider this the moment to start splitting modules (Simplifier note, not a blocker).

## Rollback

Panel behind feature flag.

### Chunk 4.4 — Compression & encoding (decision logged 2026-06-10 in decisions.md)

> Amendment to **TASK-TEL-003**: ledger-mapping rules adopt **BitLedger Universal Domain semantics** — conserved scalars (energy, mass, material) map as double-entry account pairs, with a 16-entry account-pair codebook concept in `telemetry-rules.yaml`. The accounting model is borrowed from the pioneered standard; the wire format is not. Orchestrator to amend the card's Goal and add one acceptance criterion: an energy-delta event produces a balanced two-leg hledger entry using a codebook account pair.

---
id: TASK-TEL-011
title: zstd compression with per-source trained dictionaries — wire and at-rest
status: pending
priority: M
area: tel
created: 2026-06-10
tw_uuid:
depends: TASK-TEL-002, TASK-TEL-004
---

## Goal

Telemetry streams are thousands of near-identical small NDJSON records — the worst case for generic compression and the best case for dictionary training. Adopt zstd as the standard compression at two boundaries: (1) HTTP ingest accepts `Content-Encoding: zstd` (and gzip for compatibility) on batch POSTs; (2) consumed spool archives (`.spool/<source>/done/`) and rotated stream.log segments are zstd-compressed with a per-source trained dictionary. Add `ww ingest train-dict <source>` (wraps `zstd --train` on a sample of that source's events; dictionary stored under `.spool/<source>/dict/`, versioned, embedded dict-ID in frames so old archives stay readable).

## Context

Decision record 2026-06-10: industry codecs on the hot path. NDJSON stays the canonical uncompressed format in live spools — compression applies on the wire and at rest, never to the format agents and humans read. Gorilla-style delta-of-delta numeric compression is explicitly out of scope for v1: analytical history exports to Parquet+zstd or the customer's TSDB (export card territory), we do not reinvent a time-series engine.

## Acceptance Criteria

- [ ] HTTP `/ingest` accepts zstd- and gzip-encoded batches; rejects malformed frames with 400 and a reason
- [ ] `ww ingest train-dict <source>` produces a dictionary; benchmark in tests shows ≥2× improvement over dictionary-less zstd on a corpus of ≥10k small events (fixture corpus shipped)
- [ ] Archived spool files and rotated stream segments compressed transparently; `ww stream replay` and `ww stream view` decompress without user action
- [ ] Dictionary versioning: re-training creates v(n+1); archives compressed with v(n) still decode (dict-ID embedded per zstd frame standard)
- [ ] Dependency policy decided and documented: system `zstd` binary required for telemetry feature set (checked by dependency-installer), core ww unaffected when absent
- [ ] Soak test from TEL-002 re-run with compression enabled — no loss, no corruption

## Write Scope

`services/ingest/`, `services/browser/server.py` (Content-Encoding on `/ingest`), `lib/dependency-installer.sh`, `services/stream/` (decompress-on-read), tests

## Risk

Low-medium: compression bugs can silently corrupt archives — mitigated by checksum-after-compress verification in the archive step and the dict-ID versioning rule. Live spools stay uncompressed, so the blast radius is archives only.

## Rollback

Config switch `compression: off`; existing archives remain readable (decompress-on-read is unconditional).

---
id: TASK-TEL-012
title: BitPads edge codec — optional adapter codec for byte-metered links
status: pending
priority: L
area: tel
created: 2026-06-10
tw_uuid:
depends: TASK-TEL-009
---

## Goal

Offer the pioneered BitPads/BitLedger encoding as an **optional** adapter-SDK codec for constrained uplinks where every byte is billed (satellite, LoRa, metered cellular): the edge adapter encodes canonical events into BitPads frames before the expensive hop; an ingest-side decoder shim expands them back to canonical NDJSON into the spool. The spine never sees BitPads — this is strictly a link codec behind the adapter contract.

## Context

Decision record 2026-06-10. BitPads is structurally wrong for the hot path (per-frame packing vs. inter-sample correlation; shared-codebook coupling; binary-first vs. human-legible positioning) but genuinely defensible for byte-metered links — the niche BitLedger was designed for. This card is the commercial story for "we pioneered a standard": a premium edge capability, not a default.

**External prerequisites (hard gate — do not dispatch until all three exist in babbworks/Bitpads-CLI or bitpads-standard):**
1. Decoder at parity with the encoder (round-trip proven)
2. Linux build in CI
3. Published formal test vectors (which also resolves the 22-vs-28-byte spec discrepancy noted in the standard's own docs)

## Acceptance Criteria

- [ ] Prerequisite gate verified and linked in the card before dispatch (Orchestrator checks Bitpads-CLI state)
- [ ] Adapter SDK codec interface: `codec: bitpads` in adapter config; scaffold (`ww ingest scaffold`) can generate a bitpads-codec adapter skeleton
- [ ] Round-trip property test: canonical event → BitPads frame → decoded event is field-identical for the schema's required fields; lossy mappings (e.g., freeform ctx) documented explicitly
- [ ] Wire benchmark in docs: bytes-per-event for BitPads vs zstd-dict NDJSON on the fixture corpus — published honestly, whichever way it lands, with the byte-metered-link breakeven worked out
- [ ] Decode failures land as `quality: bad` events with raw frame preserved in ctx (never silent loss)
- [ ] CRC-15 verification on every frame; failures counted in `ww ingest status`

## Write Scope

`services/ingest/adapters/` (codec layer), `resources/adapter-templates/`, docs, tests. No spine changes.

## Risk

Low to the product (isolated, optional, off by default). Schedule risk lives in the external prerequisites — that work happens in the Bitpads repos, not here, and this card must not block any other telemetry card.

## Rollback

Codec unused → no behavior change anywhere.

### Part 4 journal entries

[2026-06-10 13:00] Telemetry architecture locked: spool + single-writer daemon. @project:commercialization @tags:telemetry,architecture,decision @priority:H
Decision: adapters are isolated processes writing canonical NDJSON to disk spools; one daemon (ww-ingestd) is the sole writer into stream.log and, via the rules mapper, into tasks/journals/ledgers. This converts the no-locking problem into a no-contention design, makes every obscure protocol an out-of-tree concern, and makes crash recovery a file-move. Explicitly NOT building a time-series database — stream.log is a replayable buffer and the human-facing layer is tasks/journal/ledger artifacts; historians remain the customer's historian. Honest v1 throughput target: thousands of events/min, which covers human-readable factory telemetry by orders of magnitude.

[2026-06-10 13:20] Protocol coverage strategy: ship four doors, sell the locksmith service. @project:commercialization @tags:telemetry,commercial,decision @priority:H
In-tree adapters: HTTP (universal), MQTT+Sparkplug (modern plants), OPC UA (automation standard), Modbus + file-drop + serial (the legacy long tail that actually exists on floors). Everything else — PROFINET, EtherNet/IP, BACnet, CAN, S7, MELSEC, FINS, DNP3, MTConnect, FOCAS, bespoke CSV dialects — goes through the published adapter contract + scaffold + conformance test. The commercial offering sells exactly what open source can't: building and supporting the obscure adapter for YOUR 1987 press brake. The cookbook docs are deliberately part of the product.

[2026-06-10 15:50] Compression decided: standard codecs hot, pioneered standard edge. @project:commercialization @tags:telemetry,compression,bitpads,decision @priority:H
Studied bitpads-standard, bitpads/Bitpads-CLI, workpads-standard, bitledger-standard. Verdict logged in decisions.md: zstd with per-source trained dictionaries on the wire and at rest (TEL-011), Gorilla/TSDB territory delegated to export rather than reinvented, Sparkplug B's metric aliases adopted as the standardized form of the BitPads shared-codebook idea. BitPads itself is structurally wrong for the hot path — it packs single frames tightly while telemetry's compressibility lives between consecutive samples, it requires codebook control of both endpoints (our differentiator is senders we don't control), and its tooling is encoder-only/macOS-only with no test vectors. But it earns two scoped roles: optional edge codec for byte-metered links (TEL-012, gated on decoder parity + Linux CI + test vectors in the Bitpads repos) and BitLedger Universal Domain account-pair semantics as the model for telemetry→ledger mapping (TEL-003 amendment). Not supposing our standards were best paid off: the analysis found the boundary where they genuinely are.

[2026-06-10 13:35] Mapper is the differentiator; dedupe is its hard problem. @project:commercialization @tags:telemetry,design @priority:M
A fault signal must become ONE task, not a task per scan cycle — dedupe windows keyed on source+code, with suppression counts annotated onto the surviving task so volume information isn't lost. Mapper never blocks the raw append (append-first, map-after). Attribution rides Part 3: artifacts created by machines are queryable by machine principal, same as agent work. One attribution model across humans, agents, machines was the right call.

---

## Part 5 — Release Engineering & the Commercial Boundary

### Chunk 5.1 — Ship like a product

---
id: TASK-REL-001
title: CHANGELOG, semver policy, first executed release checklist
status: pending
priority: M
area: rel
created: 2026-06-10
tw_uuid:
depends: TASK-LIC-001
---

## Goal

Version 1.0.0 is hardcoded in two places with no changelog, no tags, and `system/reports/releases/` empty despite Gate D requiring signed checklists. Establish: CHANGELOG.md (Keep-a-Changelog format), semver policy doc, single-source version (one VERSION file read by installer and bin/ww), and execute the existing release checklist once, signed, into `system/reports/releases/` — making Gate D real instead of aspirational.

## Acceptance Criteria

- [ ] CHANGELOG.md with reconstructed entries for known history, accurate going forward
- [ ] Version sourced from one file; `ww --version` matches git tag
- [ ] First signed checklist in `system/reports/releases/`; git tag created
- [ ] Release process doc in `docs/`

## Write Scope

`CHANGELOG.md` (root — sanctioned by this card per the root-file rule), `bin/ww` (SERIALIZED, version read), `lib/installer-utils.sh`, `docs/`, `system/reports/releases/`

## Risk

Low.

## Rollback

n/a

---
id: TASK-REL-002
title: Deployment packaging — Docker image + systemd bundle for server installs
status: pending
priority: M
area: rel
created: 2026-06-10
tw_uuid:
depends: TASK-AUTH-003, TASK-TEL-002
---

## Goal

Factory and team deployments don't run install.sh on a laptop. Ship: a Dockerfile (instance + browser server + ingestd, volumes for profiles/spool, healthcheck) and a documented systemd bundle (browser, ingestd, adapter units from earlier cards) with an `ww install --server` preset. Also: bring install.sh up to project standard (`set -euo pipefail` — it currently has `set -e` only).

## Acceptance Criteria

- [ ] `docker run` with mounted volume → working authenticated browser + ingest endpoint
- [ ] systemd preset installs/starts/survives reboot on a stock Ubuntu LTS
- [ ] install.sh passes the project's own Gate B shell standards
- [ ] Smoke-tested in CI (container build at minimum)

## Write Scope

`Dockerfile` + `docker/` (root file sanctioned by this card), `resources/systemd/`, `install.sh`, docs, CI workflow

## Risk

Medium: installer changes have wide blast radius — full install/uninstall BATS suites required.

## Rollback

Packaging is additive; installer changes revertible.

---
id: TASK-SEC-001
title: Kill silent failure — structured logging in the browser server
status: pending
priority: M
area: sec
created: 2026-06-10
tw_uuid:
depends: —
---

## Goal

server.py has dozens of `except Exception: pass` — production issues surface as empty panels with no trace. Introduce a logger (stdlib logging, NDJSON file at `$WORKWARRIOR_BASE/.logs/browser.log`, rotation) and convert every silent except to a logged one with context; add `/health` detail (uptime, error counts by class) for support diagnostics.

## Acceptance Criteria

- [ ] Zero bare `except: pass` remain (grep-enforced in a test)
- [ ] Errors logged with endpoint, principal (post-AUTH-003), exception class; secrets never logged
- [ ] `ww browser logs [--tail]` reads it back
- [ ] Log rotation; bounded disk use

## Write Scope

`services/browser/server.py`, `services/browser/browser.sh`, tests

## Risk

Low. Pure observability gain; required substrate for selling support (you cannot support what you cannot see).

## Rollback

Log level OFF.

### Chunk 5.2 — Decide what's sold

---
id: TASK-BIZ-001
title: Open-core boundary decision — what is OSS forever, what is commercial
status: pending
priority: H
area: biz
created: 2026-06-10
tw_uuid:
depends: TASK-LIC-001
---

## Goal

Operator decision card (no code). Ratify the boundary this plan was designed around, or amend it:

**OSS forever:** the entire CLI, profiles, browser UI, single-operator auth (principals/tokens/scopes), agent attribution + hash-chain verify, telemetry spine, all in-tree adapters, adapter SDK.
**Commercial:** SSO/LDAP/OIDC, org-level RBAC and fleet policy, central multi-site management, signed-build + LTS support contracts, bespoke adapter development, SLA support, hosted sync.
**Principle:** nothing already shipped OSS ever moves behind the paywall; the commercial line only adds layers above.

## Acceptance Criteria

- [ ] Decision + rationale in `system/logs/decisions.md`
- [ ] Public statement drafted for readme (community trust depends on saying this out loud, early)
- [ ] Pricing/support-tier sketch in `system/reports/` (internal)

## Write Scope

`system/logs/decisions.md`, `readme.md`, `system/reports/`

## Risk

Strategic only — but getting this wrong (or silent) poisons community goodwill, which is the funnel.

## Rollback

Boundary can widen OSS-ward anytime; never the reverse (by stated principle).

### Part 5 journal entries

[2026-06-10 14:00] The support contract is observability + obscure adapters + identity. @project:commercialization @tags:commercial,strategy @priority:H
What this plan actually builds toward selling: (1) identity and audit you can show an auditor — principals, scopes, hash-chained agent logs, machine attribution; (2) the obscure-feed practice — published adapter contract makes the long tail a service line instead of a roadmap graveyard; (3) supportability — structured logs, health endpoints, packaged deployments, signed releases. The OSS core stays genuinely whole: a solo user on localhost gets everything, zero config, exactly as today. Gate D becomes real with the first signed release checklist. Sequencing: Part 1 unblocks all; Parts 2–3 parallel after LOCK-001/002; Part 4 spine after AUTH-003; adapters parallelize freely after TEL-002 (disjoint write sets, per the parallelization rules).

---

## Appendix — Dependency Spine & Dispatch Order

```
LIC-001 ─► LIC-002                 PORT-001    PORT-002    AGENT-004   SEC-001
   │                                  │
   └─► REL-001    LOCK-001 ─► LOCK-002 ─► AGENT-002 ─► AGENT-003
                     │    └────────► AUTH-003 ─► AUTH-004, AUTH-005, AUTH-006
                     │  (AUTH-001 ─► AUTH-002 feed AUTH-003)
                     └─► TEL-002 (needs TEL-001) ─► TEL-003 (needs AGENT-002)
                              ├─► TEL-004 (needs AUTH-003)
                              ├─► TEL-005, TEL-006, TEL-007, TEL-008  (parallel-safe)
                              ├─► TEL-009 (after TEL-005 proves the contract) ─► TEL-012 (ext. gate: Bitpads-CLI decoder+Linux+vectors)
                              ├─► TEL-010 (needs TEL-003, TEL-004)
                              └─► TEL-011 (needs TEL-002, TEL-004)
REL-002 (needs AUTH-003 + TEL-002)        BIZ-001 (needs LIC-001)
Existing cards amended, not duplicated: TASK-CI-001 (raise to HIGH, add Linux+macOS matrix), TASK-TEST-003 (unchanged, still gates CI), TASK-TEL-003 (BitLedger account-pair semantics for ledger mapping — see Chunk 4.4).
```

**First dispatch wave (all write-disjoint, parallel-safe):** LIC-001, PORT-001, LOCK-001, AGENT-004, SEC-001.

*End of plan. 26 new cards, 3 amendments, 9 journal entries. Compression/encoding decision record: `system/logs/decisions.md` 2026-06-10. Orchestrator ratifies Gate A criteria card-by-card before any Builder dispatch.*
