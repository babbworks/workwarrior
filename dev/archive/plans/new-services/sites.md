# Service Concept: Sites

## Purpose

Spin up documentation sites and simple websites from content within one or more profiles.
Aggregates, prepares, and ratifies text and data from profile sources (journals, decisions,
plans, bases, reports, etc.) and publishes them through a site-generation engine.

The core idea: profile content that is currently private and local can be selectively
surfaced as a structured website — a personal wiki, a project site, a team knowledge hub.

---

## Status

**Parked — research required.**

This service will integrate one or more open source static site generators or documentation
engines at its core, in a similar pattern to how Functions integrates external CLI tools.

Before a concept can be ratified, research is needed to identify:
- Which open source site generators best fit (e.g. Hugo, MkDocs, Docusaurus, Zola, Quartz)
- How the aggregation and content-preparation pipeline works across multiple profiles
- What "ratifying" content means — review/approval flow before content is included in a build
- How profile isolation is respected (what gets included, what stays private)
- What the ww CLI surface looks like (build, serve, publish, include/exclude sources)

**Do not create a task card until research is complete and a backend is chosen.**
