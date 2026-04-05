# Service Concept: Agents

## Purpose

Dispatch, track, and log AI agent sessions within the workwarrior profile context.
Profile-aware agent task management — likely wraps or integrates an open source agent
framework or task queue.

---

## Status

**Parked — research required.**

This service will integrate one or more open source agent / AI task management projects
at its core, in a similar pattern to how Functions integrates external CLI tools.

Before a concept can be ratified, research is needed to identify:
- Which open source agent frameworks or orchestration tools are appropriate
- How agent sessions, prompts, and outputs are stored per-profile
- What the CLI surface should be (dispatch, status, log, replay)
- How this interacts with existing ww services (tasks, decisions, plans)

**Do not create a task card until research is complete and a backend is chosen.**
