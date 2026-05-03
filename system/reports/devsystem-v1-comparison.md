# Devsystem v1 Architecture Comparison: claude/v1 vs codex/v1

Date: 2026-04-04

## Structure at a Glance

| Dimension | claude/v1 | codex/v1 |
|---|---|---|
| Total files | 20 | ~22 (incl. gitkeeps) |
| Paradigm | Documentation-first | Executable-first |
| Primary interface | Read markdown, follow instructions | Run `bin/codexctl` commands |
| Config format | Markdown prose | YAML + plain text |
| Task storage | Single `TASKS.md`, inline | Individual files in `tasks/cards/<ID>.md` |
| Verification | Manual fill-in template | Runnable `verify-phase1.sh` script |
| Output directories | Single `outputs/` (referenced, not created) | Separate `audits/`, `reports/`, `logs/` with `.gitkeep` |

---

## Where codex/v1 Was Architecturally Stronger

**1. Executable automation layer — significant advantage.**
Codex shipped a real CLI: `bin/codexctl status`, `codexctl verify-phase1`, `codexctl new-task`, `codexctl dispatch`. These aren't descriptions of what to do — they run. `verify-phase1.sh` actually checks file existence and prints PASS/FAIL. `dispatch-worktree.sh` actually creates git worktrees. Claude's system required an agent to read a workflow doc and execute steps manually; Codex's system gave the agent a tool to run.

**2. Individual task card files.**
Codex stored each task as `tasks/cards/TASK-001.md` and auto-generated them via `new-task.sh`. As task count grows this scales — you can grep, list, and operate on individual cards without parsing a large monolithic file. Claude's single `TASKS.md` is manageable early but becomes unwieldy at 50+ tasks.

**3. Machine-parseable config.**
`config/gates.yaml`, `config/roles.yaml`, `config/test-baseline.yaml` are structured data — parseable by scripts, renderable by tools, diffable cleanly. Claude encoded the same information as prose that only humans and LLMs can interpret. Codex's YAML can be consumed by `verify-phase1.sh`; Claude's prose cannot.

**4. Phase-role mapping in `roles.yaml`.**
Codex explicitly modelled `phase_role_profile`: Phase 1 activates five roles, Phase 2+ activates four with conditional Explorer/Simplifier. Machine-readable and enforceable by scripts.

**5. Separated output directories.**
`audits/`, `reports/`, `logs/` with `.gitkeep` is cleaner than Claude's single `outputs/` directory. Different artifact types stay separate.

---

## Where claude/v1 Was Architecturally Stronger

**1. Content depth and cold-startability — decisive advantage.**
Claude's `CLAUDE.md` was a complete project context document: directory map table, agent model table, shell scripting standards with code examples, environment variables, service contract, named fragility files, testing section, gates. Codex's `CLAUDE.md` was 40 lines covering the same topics at 20% depth.

**2. Agent prompt prefixes.**
Every Claude role file ended with a concrete prompt prefix block to copy-paste when invoking a subagent. Codex defined roles in `roles.yaml` — clean for machines, useless as an agent prompt.

**3. `services-CLAUDE.md` — deployable immediately.**
Claude built the actual `services/CLAUDE.md` context file, ready to copy to the project. Codex had no equivalent.

**4. Fragility register depth.**
Claude's `fragility-register.md` had policy levels, file-by-file entries with specific risks, pre-conditions checklist, rollback procedure, and a change log. Codex had `serialization-paths.txt` (a four-line list).

**5. Workflow depth with specific commands.**
`workflows/phase1.md` provided actual bash commands to run at each step, checkbox acceptance criteria, explicit parallel/serial annotations. Codex's `runbooks/phase1.md` was 30 lines.

**6. Templates with worked examples.**
Claude's templates included fully worked examples and detailed guidance. Codex's templates were minimal fill-in skeletons.

**7. High-fragility workflow.**
Claude had a dedicated `workflows/high-fragility.md` for GitHub sync changes. Codex had no equivalent.

**8. Memory system integration.**
Claude's role files explicitly instructed agents to write to the project memory system. Codex made no mention of memory.

---

## Side-by-Side: Same Concept, Different Implementation

| Concept | claude/v1 | codex/v1 | Edge |
|---|---|---|---|
| Gates A–E | Rich markdown with scan commands | `gates.yaml` structured data | Tie |
| Role definitions | Prose + prompt prefix | YAML | Claude for agents; Codex for tooling |
| Task card format | 8-field template + worked example | 8-field skeleton | Claude |
| Verifier sign-off | 7-section adversarial checklist | 4-section table | Claude |
| Phase 1 execution | Step-by-step with commands | High-level + runbook | Codex for automation, Claude for guidance |
| Worktree dispatch | Documented in workflow prose | `dispatch-worktree.sh` actually runs | Codex |
| Phase 1 verification | Manual checklist walkthrough | `verify-phase1.sh` PASS/FAIL script | Codex |
| Task creation | Manual copy of template | `new-task.sh` generates from template | Codex |
| System health check | Described in README | `system-status.sh` runs and reports | Codex |
| Fragility policy | Dedicated register, file-by-file | Four-line text file | Claude |
| Context files | CLAUDE.md + services-CLAUDE.md ready | CLAUDE.md only, thin | Claude |
| Memory system | Explicitly integrated | Not addressed | Claude |

---

## What Each v1 System Was Built For

**claude/v1** was built for **agent readability and cold-startability**. Every file was written assuming an LLM would read it and act on it without supplementary prompting. The prompt prefixes, the worked examples, the fragility detail, the specific commands — all served an agent that needs to pick up the system from zero and execute correctly.

**codex/v1** was built for **operational repeatability and machine enforcement**. The CLI, YAML configs, and scripts meant a human or scripted process could check system state and create work without reading prose. `codexctl verify-phase1` gives a binary answer with no interpretation required.

---

## Hybrid Recommendation (led to v2)

**Take from codex/v1:**
- `bin/codexctl` + the 5 scripts
- YAML config files (gates, roles, test-baseline)
- Individual task card files in `tasks/cards/` + `new-task.sh`
- Separate `audits/`, `reports/`, `logs/` directories

**Take from claude/v1:**
- Full `CLAUDE.md` content (cold-startable)
- `services-CLAUDE.md` (deployable)
- `fragility-register.md` (file-by-file policy)
- Agent prompt prefixes in role files
- Template depth and worked examples
- `workflows/high-fragility.md`
- Memory system integration in role files

The unified system: Codex's automation layer executes; Claude's documentation layer teaches.
