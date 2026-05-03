# Service Concept: Worlds

## Purpose

Meta-workspaces that group profiles and services into named contexts. A "world" is a
higher-order layer above profiles — potentially integrating a window manager, multiplexer,
or workspace switcher at its core.

---

## Status

**Parked — research required.**

This service will integrate one or more open source projects at its core, in a similar
pattern to how Functions integrates external CLI tools.

Before a concept can be ratified, research is needed to identify:
- Which open source projects are appropriate (e.g. tmux/zellij session managers,
  i3/sway workspace tools, or custom profile-group orchestration)
- What the relationship between a world, its profiles, and its services looks like
- Whether a world is a runtime concept (active session) or a persistent config, or both

**Do not create a task card until research is complete and a backend is chosen.**
