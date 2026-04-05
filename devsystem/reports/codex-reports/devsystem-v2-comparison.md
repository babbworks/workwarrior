# Devsystem v2 Comparison (Codex vs Claude)

Compared paths:
- `/Users/mp/ww/devsystem/codex/v2`
- `/Users/mp/ww/devsystem/claude/v2`

## High-level Result

- Both are hybrid systems with governance plus automation.
- `claude/v2` is more polished as an operator-facing product.
- `codex/v2` is broader in imported artifacts but has more duplication/transition residue.

## Key Differences

| Area | `codex/v2` | `claude/v2` | Verdict |
|---|---|---|---|
| CLI | `codexctl` with `status/verify-phase1/new-task/dispatch` | `wwctl` adds `gates` and `fragility` commands | Claude stronger |
| Verification depth | Lightweight 6 checks in `scripts/verify-phase1.sh` | Full gate audit (context, task board, fragility, hygiene) | Claude much stronger |
| Task model | One generated task card + large imported `TASKS.md` | Clean phase-task card set (`TASK-1.1`..`TASK-1.5`) + index | Claude stronger |
| Governance docs | Compact `CLAUDE.md` and full `OPERATING-SPEC.md` | Single full `CLAUDE.md` | Claude cleaner; Codex more redundant |
| Templates | Duplicate sets (`templates/*` and `templates/claude/*`) | Single coherent template set | Claude cleaner |
| Workflow docs | Includes `workflows/` plus older `runbooks/phase1.md` | Coherent workflow set in `workflows/` | Claude cleaner |
| Output dirs | Supports both `audits/` and `outputs/` | Uses `audits/` only | Codex more flexible |

## Operational Check Results

- `codex/v2 status`: passes core presence checks.
- `claude/v2 status`: richer status output (deployment state, task states, phase quick check).
- `verify-phase1`: both fail pre-deployment checks (expected), but Claude output is more actionable.

## Notable Quality Signals

- `codex/v2` contains `.DS_Store` in its tree.
- `codex/v2` has architecture duplication (coverage high, clarity lower).
- `claude/v2` has tighter information architecture and better human-operable UX.

## Conclusion

- For immediate use with minimal ambiguity: prefer `claude/v2` baseline.
- For flexibility: keep `codex/v2` but prune duplicates and align command surface to `wwctl` level.

