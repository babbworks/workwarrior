# Explorer A Audit — Docs/Status Drift
Date: 2026-04-04

---

## Executive Summary

1. **CSSOT groups/models domains use plural as primary syntax** — contradicts its own policy (singular = primary) and the actual dispatcher. HIGH.
2. **CSSOT models domain is incomplete** — missing 5 subcommands (`env`, `check`, `add-provider`, `add-model`, `remove-model`). HIGH.
3. **Gate E violation in lib/sync-pull.sh:100** — `# TODO: Implement proper tag sync` has no TASKS.md card. HIGH.
4. **CSSOT documents `i` as a ww domain** — does not explain it is a shell function injected via shell-integration.sh, not a bin/ww route. MEDIUM.
5. README-issues.md, services-CLAUDE.md, and bin/ww help strings are accurate and up to date. No drift found.

---

## 1. CSSOT vs Implementation

### Finding A-1 — Groups/Models plural/singular inversion (HIGH)
- **File:** `system/config/command-syntax.yaml` lines 212–240
- **Claimed:** Domains documented as `ww groups list`, `ww models list` (plural as primary syntax)
- **Reality:** `bin/ww` dispatcher and help strings treat `group`/`model` (singular) as preferred; plural forms are nudge-deprecated aliases
- **Policy:** `command-syntax.yaml` line 14–15 states singular is the "primary action namespace"
- **Impact:** CSSOT contradicts its own policy and current implementation simultaneously

### Finding A-2 — Models subcommands incomplete (HIGH)
- **File:** `system/config/command-syntax.yaml` lines 228–233
- **Claimed syntax:**
  ```
  ww models list
  ww models providers
  ww models show <name>
  ww models set-default <name>
  ```
- **Reality (`bin/ww` show_help_model):** Also includes `env`, `check`, `add-provider`, `add-model`, `remove-model`
- **Missing from CSSOT:** 5 subcommands undocumented

### Finding A-3 — `i` command classified as ww domain (MEDIUM)
- **File:** `system/config/command-syntax.yaml` lines 172–187
- **Issue:** `i` is documented alongside `ww profile`, `ww journal` etc. as if it is a bin/ww domain
- **Reality:** `i` is a bash shell function defined in `lib/shell-integration.sh` and injected into `.bashrc` at profile setup. It is not routed through `bin/ww` at all (except the new `ww issues` alias)
- **Recommendation:** Add clarifying note: `i` = shell function; `ww issues` = bin/ww synonym

---

## 2. Gate E Violations (untracked TODOs)

### Finding A-4 — Untracked TODO in HIGH FRAGILITY file (HIGH)
- **File:** `lib/sync-pull.sh` line 100
- **Content:** `# TODO: Implement proper tag sync`
- **TASKS.md check:** No corresponding card found
- **Gate E rule:** Every deferred TODO in production code must have a TASKS.md card
- **Action required:** Create task card or remove TODO if out of scope

---

## 3. Accurate / No Drift Found

| Area | Status |
|---|---|
| `services/custom/README-issues.md` | Accurate — routing matrix, `i`/`ww issues` synonymy, install steps all correct |
| `system/services-CLAUDE.md` | Accurate — service template tiers, exit codes, help format, naming conventions |
| `bin/ww` help strings | Comprehensive — all primary commands documented with examples; global flags present |
| TASKS.md completed status | Evidence-backed for SVC-001..006, CLI-001..004, SYS-001..003 |

---

## 4. TASKS.md Status Check

| Task | Marked | Evidence |
|---|---|---|
| TASK-SVC-001..006 | complete | All service commands functional and tested |
| TASK-CLI-001..004 | complete | Routing, flags, help, deprecation layer all implemented |
| TASK-SYS-001..003 | complete | control plane, phase1 checks, CSSOT all exist |
| TASK-TEST-001 | complete | select-tests.sh exists, verify-phase1 checks it |
| TASK-1.3a | pending → done | This audit |

---

## Recommendations

### Immediate (CSSOT corrections — can be done in same session)
1. Fix groups/models domain entries in CSSOT: change to singular primary form with plural as alias
2. Add missing model subcommands to CSSOT: `env`, `check`, `add-provider`, `add-model`, `remove-model`
3. Add note to CSSOT issues domain clarifying `i` is a shell function

### New task card required
4. Create TASK card for `lib/sync-pull.sh:100` TODO (tag sync) — or explicitly remove it as out-of-scope

### Future
5. TASK-QUAL-002 (automate docs/help parity) would prevent CSSOT drift from recurring
