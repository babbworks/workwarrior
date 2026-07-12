# Design: Product-vs-Meta Repository Restructure (Parts 1–3)

**Date:** 2026-07-09
**Status:** Design approved — pending spec review, then task-card breakdown
**Driver:** Human cognitive load + public/open-source polish
**Author:** Brainstorming session (agent-assisted)

---

## 1. Problem

The repo is 1,096 tracked files with unevenly distributed sprawl and several
overlapping entry points. Two concrete pains:

- **A newcomer / the maintainer cannot tell what is "the product" vs. "how it's
  built."** The dev control plane (`dev/`), the test suite (`dev/tests/`), and
  vendored documentation sit at the top level next to the actual runtime code.
- **Four overlapping orientation docs** (`readme.md`, `CLAUDE.md`,
  `dev/README.md`, `dev/CLAUDE.md`) with no obvious "read this first."

An earlier audit in this session also found live documentation drift (dangling
`dev/context/` references, a misconfigured `.gitbook.yaml`), symptomatic of
structure that has outgrown its original layout.

## 2. Guiding Principles (locked)

1. **Product forward, meta grouped** ("Option B" — chosen over tidy-in-place and
   a full `src/` regroup).
2. **Keep it all for pushing.** Nothing is deleted or extracted to another repo.
   Every change is a *move, group, or merge* in place. All content remains in the
   repo for the public push.
3. **Runtime directory *names* are unchanged.** `bin/ lib/ services/ config/
   resources/ functions/ tools/ scripts/` keep their names and top-level position.
4. **Respect governance.** HIGH-FRAGILITY edits (`lib/field-mapper.sh`) go through
   the Orchestrator approval + integration-test gate. Execution flows through the
   task-card system, not straight edits.

## 3. Scope & Decomposition

This restructure is **four independent efforts**. This spec covers **Parts 1–3**
(all low-to-moderate risk, mutually reinforcing the product/meta split).
**Part 4 (docs/ dedup) is deferred to its own spec** — it is a separate
investigation (two overlapping doc trees + a broken GitBook publish config) with
its own medium risk.

| Part | Scope | Risk |
|---|---|---|
| 1 | `dev/` boundary + runtime-config decouple | Moderate (touches HIGH-FRAG) |
| 2 | Entry-doc consolidation | Low |
| 3 | Service-stub relocation | Low |
| 4 | docs/ dedup + GitBook fix — **separate spec** | Medium |

---

## 4. Part 1 — The `dev/` boundary

### 4a. Send runtime config to its real home (the linchpin)

`dev/config/` holds a clean 5/5 split of runtime data vs. dev config. Only the
runtime files move; the dev config rides along in the rename (4b).

**Move (runtime → `config/`, via `git mv`):**

| File | Runtime reader |
|---|---|
| `label-uda-map.yaml` | `lib/field-mapper.sh:10` ⚠️ **HIGH FRAGILITY** |
| `body-uda-map.yaml` | `lib/field-mapper.sh:11` ⚠️ **HIGH FRAGILITY** |
| `service-uda-registry.yaml` | `services/profile/subservices/profile-uda.sh:26` |
| `uda-indicator-map.yaml` | `services/profile/subservices/profile-uda.sh:27` |
| `uda-color-map.yaml` | `services/profile/subservices/profile-uda.sh:28` |

**Stay (dev config — moves with `dev/` in 4b):**
`command-syntax.yaml` (CSSOT), `gates.yaml`, `roles.yaml`,
`serialization-paths.txt`, `test-baseline.yaml`.

**Reader edits:**
- `lib/field-mapper.sh:10-11` → point at `config/`. **HIGH-FRAGILITY gate:** must pass
  `dev/tests/test-github-sync.bats` + `bash dev/tests/run-integration-tests.sh` + full
  `bats dev/tests/`. Requires Orchestrator approval + extended risk brief per
  `fragility-register.md`.
- `services/profile/subservices/profile-uda.sh:26-28` → point at `config/`.

**Why first:** these 5 files are the *only* runtime coupling to the dev control
plane. Once relocated, `dev/ → dev/` is a pure move/text operation with no
behavioral change. The gate verifies field-mapper reads the same YAML from a new
path — small, verifiable blast radius.

### 4b. Rename `dev/ → dev/`

- `git mv system dev` (history preserved).
- `git mv tests dev/tests` — tests are dev-only (zero installer/sync references).
  Update: `dev/scripts/select-tests.sh`, `.claude/settings.local.json`,
  `dev/tests/CLAUDE.md`, `dev/tests/TESTING-QUICK-START.md`, and the
  `test-baseline.yaml` path map.
- `bin/ww-init.sh:20-22` — PATH inject `dev/bin → dev/bin`; keep the
  `[[ -d ]]` guard so absence in product installs is harmless.
- `install.sh:340` — **remove the `cp -r dev/*` step.** With runtime config
  decoupled (4a), `dev/` no longer needs to ship. Product installs get lighter and
  stop receiving dev scaffolding. (Update the install summary text at
  `install.sh:750` accordingly.)
- **External reference rewrite (29 files outside `dev/`)** `dev/ → dev/`:
  root `CLAUDE.md`, `.gitignore`, `.claude/ww/ww-agent-guidance.md`,
  `lib/CLAUDE.md`, `weapons/gun/README.md`, the 4 service-overview stubs
  (`base`, `diagnostic`, `help`, `verify`), and doc references. (docs/ references
  that live under `docs/site/` mirror files are handled in Part 4.)
- **Internal self-references (~64 files inside `dev/`)** that mention the literal
  string `dev/…` → `dev/…` (mechanical `sed`, reviewed).

### 4c. Verification (Part 1)

- Full `bats dev/tests/` (now `dev/tests/`) green vs. known ~29-failure baseline.
- HIGH-FRAG suite green (4a).
- Fresh `install.sh` to a scratch dir: confirm runtime works without `dev/` present
  (`ww help`, `ww profile list`, a UDA-color render exercising `profile-uda.sh`, a
  sync dry-run exercising `field-mapper.sh`).
- `wwctl status` runs from the repo (`dev/bin/wwctl`).

---

## 5. Part 2 — Entry-doc consolidation

Reduce four overlapping orientation docs to three with distinct jobs:

| Doc | Role after |
|---|---|
| `README.md` (renamed from `readme.md`) | **Public front door.** Convention-cased. |
| `CLAUDE.md` (root) | **Thin agent pointer** → points at `dev/ONBOARDING.md`. |
| `dev/README.md` (was `dev/README.md`) | Dev control-plane map. |
| `dev/CLAUDE.md` (was `dev/CLAUDE.md`) | Canonical project + agent rules. |

- After the Part 1 rename these are already mostly coherent; Part 2 is the rename
  of `readme.md → README.md` and re-aiming the root `CLAUDE.md` pointer at `dev/`.
- Fold in the drift already found earlier this session if not yet merged
  (dangling `dev/context/` refs — done) and confirm no new dangling refs.
- **GitBook config fix is deferred to Part 4** (it concerns `docs/site/`).

---

## 6. Part 3 — Service-stub relocation

Nine service categories are pure design stubs (only `README.md` +
`service-overview.md`, zero executables, no runtime references). Their design
intent is preserved by relocation, not deleted.

**Relocate set (9):** `base, diagnostic, help, kompare, open, unique, verify, you,
z-default`.

- Move each `service-overview.md` → `dev/specs/service-designs/<name>.md`
  (content kept; consolidated design home).
- Remove the now-empty `services/<name>/` dirs so service discovery and the
  newcomer view are clean. (No executables → no behavioral change to
  `ww service list` beyond dropping empty categories.)

**Held out (inspect-first, NOT in this set):**
- `services/scripts/` — contains `journals/` and `tasks/` subdirs (real content).
- `services/cmd/` — README-only, but `ww cmd` is a core feature (the NL layer);
  confirm its logic home (`bin/ww` / heuristics) before any change.

---

## 7. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| `field-mapper.sh` (HIGH-FRAG) regression | Full sync + integration test gate; Orchestrator approval; isolated worktree. |
| Missed `dev/` reference breaks a path | Grep-verify **zero** `dev/` refs remain outside intentional history/archive text after rewrite. |
| `install.sh` no longer ships needed file | Part 1 4a proves the only runtime deps were the 5 YAML; scratch-install verification in 4c. |
| Relocating a stub that has hidden semantics | `scripts/` and `cmd/` explicitly held out and inspected first. |
| Spec doc itself moves in Part 1 | Expected — it lives under `dev/specs/` → `dev/specs/`; noted. |

## 8. Execution Sequencing & Governance

Recommended order: **1a → 1b → 2 → 3** (1a unblocks 1b; 2 and 3 are independent
and safe). Each part becomes one or more task cards under the
Orchestrator → Builder → Verifier → Docs flow. Part 1 carries the HIGH-FRAGILITY
designation and its extended risk brief. Part 4 (docs/) is authored separately.

## 9. Out of Scope

- Any deletion or extraction of content (principle #2).
- Renaming/moving runtime dirs (`bin/ lib/ services/ …`).
- docs/ dedup, vendored `docs/taskwarrior-extensions/repos/`, and GitBook
  reconfiguration — **Part 4, separate spec.**
