# Devsystem v1 Comparison (Codex vs Claude)

Compared paths:
- `/Users/mp/ww/devsystem/codex`
- `/Users/mp/ww/devsystem/claude`

## Architecture Contrast

| Dimension | Codex System | Claude System | Assessment |
|---|---|---|---|
| Primary style | Tooling-first, executable ops | Policy/workflow-first, document-driven | Different strengths, complementary |
| CLI automation | Yes: `bin/codexctl` + scripts | No executable control scripts | Codex stronger for immediate operational use |
| Governance docs | Compact: `CLAUDE.md` + YAML config | Deep: role packs, gates, workflows | Claude stronger for role clarity and audit rigor |
| Templates | Core templates only | More complete templates including role-specific risk/signoff templates | Claude more comprehensive |
| Task system | Canonical tracker + card generator | Rich seeded task model in `TASKS.md` | Claude stronger as planning artifact |
| Phase-1 verification | Automated check (`verify-phase1.sh`) | Procedural checklist in docs | Codex stronger for repeatable enforcement |
| Worktree dispatch | Automated script (`dispatch-worktree.sh`) | Process described, not scripted | Codex stronger |
| Fragility handling | Config + basic policy | Dedicated fragility doc + workflow | Claude stronger on depth |
| Completeness consistency | Internally consistent and runnable | One structural gap: references `outputs/` but no directory scaffolded | Minor fix needed in Claude system |

## Quantitative Snapshot

- File count: Codex 24 vs Claude 20
- Executables: Codex 6 vs Claude 0
- Size: Codex 96K vs Claude 132K

## Bottom Line

- Codex is better as an operator runtime (commands, dispatch, validation automation).
- Claude is better as a governance/role framework (detailed prompts, workflows, gate semantics).

