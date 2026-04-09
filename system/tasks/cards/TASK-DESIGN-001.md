## TASK-DESIGN-001: Service discovery interviews — overview docs for all undeveloped services

Goal:                 Quiz the user about each service category that has no implementation yet.
                      Synthesize their responses + Orchestrator analysis into a service-overview.md
                      placed inside each service's folder. These docs become the design departure
                      point: when development of a service is undertaken, Claude reads the overview
                      and uses it to ask targeted follow-up questions before building.

Undeveloped services  (0 or stub files — confirmed 2026-04-08):
(interview queue):    base, diagnostic, help, kompare, network, open, saves, unique,
                      verify, warrior, you, z-default

Partially developed   (have files but no clear design doc):
(lower priority):     export, extensions, find, groups, models, x-delete

Interview format:     For each service:
                      1. Claude asks: what is this service for? who uses it? what commands should it expose?
                         what data does it read/write? any upstream tools to wrap?
                      2. User responds conversationally.
                      3. Claude asks follow-up questions if design is underspecified.
                      4. Claude writes service-overview.md to services/<name>/service-overview.md
                         covering: purpose, target user, command surface sketch, data dependencies,
                         integration points, open questions.

Acceptance criteria:  1. services/<name>/service-overview.md exists for every service in the
                         interview queue above (at minimum all 12 undeveloped ones).
                      2. Each overview includes: Purpose, User, Command surface sketch,
                         Data / integrations, Open questions for design/dev phase.
                      3. No implementation code is written — design docs only.
                      4. When a service later enters development, Orchestrator reads its
                         service-overview.md and uses it to drive the initial Builder contract.

Write scope:          services/base/service-overview.md
                      services/diagnostic/service-overview.md
                      services/help/service-overview.md
                      services/kompare/service-overview.md
                      services/network/service-overview.md
                      services/open/service-overview.md
                      services/saves/service-overview.md
                      services/unique/service-overview.md
                      services/verify/service-overview.md
                      services/warrior/service-overview.md
                      services/you/service-overview.md
                      services/z-default/service-overview.md

Tests required:       None — document deliverables only.

Fragility:            None — new files only, no existing code touched.

Status:               pending
