# Service Concept: Systems

## Purpose

System configuration and environment management across machines. Manages dotfiles,
system configs, installed tools, and environment state — likely integrates an open source
dotfile manager or system provisioning tool at its core.

---

## Status

**Parked — research required.**

This service will integrate one or more open source projects at its core, in a similar
pattern to how Functions integrates external CLI tools.

Before a concept can be ratified, research is needed to identify:
- Which open source tools best fit (e.g. chezmoi, dotbot, GNU stow, nix, ansible)
- How system-level management relates to profile-level isolation
- What the ww CLI surface should be once backend is known

**Do not create a task card until research is complete and a backend is chosen.**
