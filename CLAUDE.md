# Workwarrior

All project context, agent roles, gates, task board, and working conventions live in `dev/`.

**Read `dev/ONBOARDING.md` first. It is the single entry point for any agent session.**

Key files (in read order):
1. `dev/ONBOARDING.md` — session init, orientation, current phase, hard rules
2. `dev/CLAUDE.md` — directory map, agent model, scripting standards, fragility markers, hard gates
3. `dev/TASKS.md` — canonical task board (Orchestrator-only writes)
4. `dev/tasks/INDEX.md` — scannable manifest of all task cards
5. `.claude/ww/ww-agent-guidance.md` — session-init protocol, task lifecycle & UUID rule, annotations, UDAs, parallel sub-agent tracking
6. `dev/logs/decisions.md` — every non-obvious architectural decision

**Never skip the Orchestrator → Builder → Verifier → Docs handoff sequence.**
**Never self-approve. Never write production code as Orchestrator. Never implement as Verifier.**
**Never create files at the project root or in `profiles/*/` without an explicit task card.**
