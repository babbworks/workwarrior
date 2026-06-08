# Service Concept: Bases (Knowledge Bases)

## Purpose

Profile-scoped knowledge base service. Stores, indexes, and retrieves reference material —
notes, documents, snippets, links, structured knowledge — within a profile context.

---

## Status

**Parked — research required.**

This service will integrate one or more open source knowledge base / PKM / search projects
at its core, in a similar pattern to how Functions integrates external CLI tools.

Before a concept can be ratified, research is needed to identify:
- Which open source projects (e.g. zk, nb, Obsidian-compatible stores, ripgrep-based tools,
  vector search, etc.) best fit the workwarrior philosophy
- How the chosen project(s) are embedded — vendored, installed as deps, or wrapped as services
- What the profile-isolation model looks like for the chosen backend
- What the CLI surface should be once the backend is known

**Do not create a task card until research is complete and a backend is chosen.**
