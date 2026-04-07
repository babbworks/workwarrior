# Working Conventions

Confirmed preferences, corrections, and collaboration norms for this project.
Apply these without being told again. Any agent working on this project — regardless of tool — must read this file.

---

## The Operator

Creator and primary operator of Workwarrior. High technical level — comfortable with bash, shell scripting, git, CLI tooling. Does not need hand-holding on basics. Prefers direct, specific answers.

**Vision:** Workwarrior should support AI agent usage — an agent managing its own profile, logging activities via Tasks + Issues + Journals. Design decisions must account for machine consumers, not just human users.

**Working style:**
- Gives high-level direction ("go", "continue", "do all three") and expects autonomous execution
- Wants to be included on direction decisions for complex or system-critical tasks — ask before choosing approach
- Reviews work at milestones, not at every step
- Tolerates autonomy on implementation details once direction is confirmed

---

## Path and Naming

**The install path is `/Users/mp/ww`. Never use `workwarrior` in paths.**
`WW_BASE=/Users/mp/ww`. The name `workwarrior` is the product name only, not a path component.

**Dev/agent files do not belong at the project root.**
`/Users/mp/ww` is a hybrid — software project (`bin/`, `lib/`, `services/`) and user data container (`profiles/`). `system/` is the control plane. `system/CLAUDE.md` and `system/TASKS.md` are authoritative. Never propose deploying dev files to the project root.

---

## Response Style

**Don't summarize what you just did at the end of responses.**
The operator can read the diff and tool output. Lead with results or the next decision. Skip trailing "here's what I did" summaries unless something non-obvious happened.

---

## Before Editing Any File

**Always read the current file state before editing.**
Multiple agents (Claude Code, Codex, Q, Gemini) may work on this repo across sessions. A file may have been modified since the last session. Never edit based on a remembered version.

---

## Direction on Complex Tasks

**Ask before choosing approach on tasks touching SERIALIZED files, HIGH FRAGILITY files, or with irreversible consequences.**
Pre-flight direction questions are welcome. Implementation details within a confirmed approach do not need approval.

SERIALIZED files: `bin/ww`, `lib/shell-integration.sh`
HIGH FRAGILITY files: all `lib/github-*.sh`, `lib/sync-*.sh`, `services/custom/github-sync.sh`

---

## Multi-Agent Context

This repo is worked on by multiple AI agents across sessions (Claude Code, Codex, Amazon Q, and potentially others). No agent's tool-native memory (e.g. `~/.claude/`, `~/.codex/`) is authoritative. `system/` is the only memory store. Decisions go to `system/logs/decisions.md`. Task state goes to `system/TASKS.md`.
