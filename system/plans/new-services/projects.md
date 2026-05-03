# Service Concept: Projects

## Purpose

A first-class service for binding ww profiles to external project management systems,
synchronising structured task metadata (UDAs) to and from those systems, and surfacing
project-level views that span tasks, time, and contributors across profiles.

`projects` is the integration layer between the ww data model and the project tracking
tools that teams and individuals already use. It is not a project manager itself — it
is the bridge that makes ww data visible and actionable in those tools, and makes
those tools' data visible inside ww.

---

## Why not Groups

Groups is a profile organisation service — it defines which profiles belong together,
manages shared configuration inheritance, and provides group-level aliases and
activation shortcuts. Groups is infrastructure and config.

`projects` is a data and integration service. It owns:
- External system bindings (which GitHub Project, Linear workspace, Jira board)
- UDA ↔ external field mappings
- Sync lifecycle (create, push, pull, status, archive)
- Project-level reporting across those bindings

Conflating these into groups would make groups responsible for external API calls,
auth, and field mapping — concerns that have nothing to do with profile organisation.
Groups tells ww which profiles are related. Projects tells ww how to expose those
profiles' data to the outside world.

They can be composed: a group can have a projects binding, meaning all profiles in
the group contribute to a shared external project view. But groups does not depend
on projects and projects does not depend on groups.

---

## Relationship to Existing Sync Engine

The existing `github-sync` service (services/custom/github-sync.sh) handles
bidirectional sync of individual tasks to individual GitHub issues. It is a
task-level sync engine.

`projects` is a project-level integration layer that operates above that. It binds
a profile (or group of profiles) to an external project, manages field schema
between the ww UDA set and the project's custom field definitions, and can drive
bulk operations (populate a new project from all tasks in a profile, archive completed
tasks, generate project reports).

The two layers are complementary:
- `github-sync`: task ↔ issue (per-task, bidirectional)
- `projects`: profile ↔ project (per-profile, schema + lifecycle)

Over time, `projects` may absorb or supersede `github-sync` for profiles that have
a full project binding — at that point, individual issue sync becomes a sub-operation
of the project sync rather than a standalone service.

---

## Backends

### GitHub Projects V2 (primary — speculative)

GitHub's Projects V2 API is GraphQL-only and supports custom fields per project:

| Field type | ww UDA type | Example UDAs |
|---|---|---|
| Text | string | goals, deliverables, scope, desc, risks, notes |
| Number | numeric | manhours, dollars, quantity |
| Date | date | due, reviewby, submitby, draftby |
| Single-select | string (low-cardinality) | phase, type, status-extended |
| Iteration | — | No direct TW equivalent; could map to sprint UDAs |

A profile binding would look like:

```yaml
# profiles/acme/.config/ww-projects/github.yaml
backend: github_projects_v2
project_id: PVT_kwDOBxxxxxxx        # GitHub Project V2 node ID
org: exampleorg
field_map:
  goals:        "Goals"             # TW UDA → GitHub Project field name
  deliverables: "Deliverables"
  phase:        "Phase"             # single-select
  stack:        "Stack"
  manhours:     "Estimated Hours"
  reviewby:     "Review By"
```

**What this enables:**
- `ww projects push` → writes all linked tasks' UDA values to GitHub Project item fields
- `ww projects pull` → reads GitHub Project item field values back into TW UDAs
- `ww projects create` → provisions a GitHub Project with custom fields matching
  the profile's UDA schema (bootstraps from `.taskrc` UDA definitions)
- `ww projects status` → shows field coverage (which UDAs have values vs. blanks)
- `ww projects board` → opens the GitHub Project URL in the browser

**Auth scope:** requires `project` OAuth scope in addition to `repo`. The oracle
token directive (`@oracle:eval:gh auth token`) would need to confirm this scope.
A new `gh auth refresh -s project` step would be needed if the scope is missing.

### Label encoding (near-term, no new API scope)

A simplified projects mode using only the GitHub Issues API. Maps selected low-
cardinality UDAs to namespaced labels (`phase:dev`, `scope:large`, `type:feature`).

This is what TASK-SYNC-006 specifies. It is a stepping stone to full Projects V2
integration — same config shape, subset of field types, no GraphQL required.

### Issue body YAML (near-term, no new API scope)

Maps selected rich-text UDAs to a fenced YAML block in the issue body. Works with
any GitHub repo without Projects V2. This is what TASK-SYNC-007 specifies.

Together, SYNC-006 + SYNC-007 deliver ~70% of the value of Projects V2 with 20%
of the complexity and zero new auth requirements. They are the pragmatic path
while Projects V2 integration is designed.

### Future backends (speculative)

| Backend | What it enables |
|---|---|
| Linear | Native issue/cycle/project model; clean API; popular with eng teams |
| Jira | Enterprise requirement; complex field model; high value for consulting profiles |
| Notion | Flexible database model; good for knowledge-heavy profiles (research, writing) |
| Plane | Open source alternative to Linear; self-hostable |
| GitHub Classic Projects | Deprecated — skip |

Each backend would implement the same interface:
- `projects_push_fields()` — write UDA values to external fields
- `projects_pull_fields()` — read external fields back to UDAs
- `projects_create()` — provision project with schema from .taskrc UDAs
- `projects_status()` — report sync state

---

## Profile ↔ Project Binding

Each profile that participates in external project sync has a binding config at:

```
profiles/<name>/.config/ww-projects/<backend>.yaml
```

This file is gitignored (contains project IDs and potentially scoped tokens).
A template lives at `resources/profile/ww-projects/<backend>.yaml.example`.

The binding config declares:
- Which backend
- Which external project (ID or URL)
- Which UDAs participate and their external field names
- Sync direction (push-only, pull-only, bidirectional)
- Conflict resolution strategy (local-wins, remote-wins, last-write-wins)

---

## Groups + Projects Composition

A group can declare a shared project binding that aggregates tasks from all member
profiles into a single external project view:

```yaml
# groups/work/config.yaml
name: work
profiles: [acme, bravo]
projects:
  github_projects_v2:
    project_id: PVT_kwDOBxxxxxxx
    org: exampleorg
    field_map:
      goals: "Goals"
      phase: "Phase"
```

When `p-acme` is active and the user runs `ww projects push`, the service looks for:
1. A profile-level binding (`profiles/acme/.config/ww-projects/github.yaml`)
2. A group-level binding for any group the active profile belongs to

This means a `work` group project shows tasks from both `acme` and `bravo` in a
single GitHub Project view — each task is a project item, each item has fields
populated from the owning task's UDAs. Contributors see a unified board regardless
of which profile owns each task.

**Why this is powerful:** GitHub Projects becomes the reporting and planning surface
for the entire `work` group, with task ownership still cleanly isolated per profile
inside ww. You get team visibility without sacrificing individual profile isolation.

---

## The "Broader Shoulders" Rationale

Projects is intentionally designed to be more than a GitHub sync helper. The name
is chosen deliberately to signal that this service is the home for any feature that
concerns project-level organisation, external visibility, or structured reporting
across a profile's task set. That includes:

1. **Schema management** — bootstrapping external projects from profile UDA
   definitions; keeping external field schemas in sync as `.taskrc` evolves
2. **Bulk operations** — populate a new GitHub Project from 50 existing tasks in
   one command rather than manually enabling sync on each
3. **Cross-profile aggregation** — group-level project views as described above
4. **Milestone and roadmap tracking** — map TW due dates and project milestones
   to GitHub milestone objects or Projects iteration fields
5. **Project templates** — `ww projects template apply <template-name>` to
   provision a new GitHub Project with a predefined custom field schema
   (e.g. a "software project" template with phase, stack, scope, deliverables)
6. **Archive and lifecycle** — `ww projects archive` to mark a project complete,
   move tasks to a completed state, and close the external project
7. **Future: reporting** — feed project field data into the `reports` service
   for structured output (velocity, coverage, field completion rates)
8. **Future: external triggers** — respond to GitHub Project field changes via
   webhook (if ww ever supports a daemon mode) and write them back to TW

---

## Implementation Sequence (speculative)

| Phase | What | Prerequisite |
|---|---|---|
| 1 | SYNC-006: label encoding for categorical UDAs | QUAL-004 |
| 2 | SYNC-007: body YAML block for rich UDAs | SYNC-006 |
| 3 | Projects service skeleton — `ww projects`, config schema, binding format | SYNC-007 |
| 4 | GitHub Projects V2 GraphQL client (`lib/github-projects.sh`) | Projects skeleton |
| 5 | `projects create` — provision GitHub Project from .taskrc UDAs | GraphQL client |
| 6 | `projects push/pull` — field value sync via Projects V2 API | `projects create` |
| 7 | Group binding support — aggregate view across group member profiles | Groups service |
| 8 | Project templates — reusable field schemas for common project types | `projects create` |

Phases 1–2 are already task-carded (SYNC-006, SYNC-007) and can proceed now.
Phase 3 can begin as a concept card in this directory once SYNC-007 is complete.
Phases 4–8 are speculative and should not be carded until Phase 3 is live.

---

## Open Questions

- Should `projects` be in `services/custom/` alongside `github-sync`, or in a new
  `services/integration/` category to signal its broader scope?
- The `project` OAuth scope may not be granted by default via `gh auth login`.
  Should `ww projects init` run `gh auth refresh -s project` automatically?
- For group-level bindings, who owns the conflict when acme and bravo both push
  a different value for the same project field? Last-write-wins is the default
  but may not be right for all fields.
- Should `projects` eventually absorb `github-sync` (task-level sync) as a
  sub-command, or stay as a separate layer that composes with it?

---

## Status

**Draft concept — not yet in task pipeline.**
Promote to task card once SYNC-006 and SYNC-007 are complete and the GraphQL
client design has been validated against a test project.
