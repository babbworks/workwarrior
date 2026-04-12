# Workwarrior

All project context, agent roles, gates, task board, and working conventions live in `system/`.

**Read `system/ONBOARDING.md` first. It is the single entry point for any agent session.**

Key files (in read order):
1. `system/ONBOARDING.md` — orientation, current phase, hard rules, how work gets done
2. `system/CLAUDE.md` — directory map, agent model, scripting standards, fragility markers, hard gates
3. `system/TASKS.md` — canonical task board (Orchestrator-only writes)
4. `system/tasks/INDEX.md` — scannable manifest of all 73+ task cards
5. `system/logs/decisions.md` — every non-obvious architectural decision

**Never skip the Orchestrator → Builder → Verifier → Docs handoff sequence.**
**Never self-approve. Never write production code as Orchestrator. Never implement as Verifier.**
**Never create files at the project root or in `profiles/*/` without an explicit task card.**
