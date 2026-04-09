## TASK-EXT-DENSITY-001: Integrate 00sapo/TWDensity as ww profile uda density

Goal:                 Add due-date density scoring to ww profiles. TWDensity adds a
                      `density` UDA that counts how many tasks share a similar due-date
                      window and adjusts urgency accordingly — prevents urgency spikes
                      when tasks cluster on the same date.

Upstream:             https://github.com/00sapo/TWDensity
                      Author: 00sapo · MIT License · Python · Active Jun 2024
                      pipx install twdensity

Profile isolation:    Reads TASKRC/TASKDATA. Writes density UDA values to task data.
                      Per-profile by default.

Citation model:       TWDensity introduces two UDAs (density, densitywindow) and a set
                      of urgency.uda.density.<n>.coefficient entries in .taskrc.
                      ww's citation approach for this type of extension:
                        - UDAs prefixed with no service namespace (density*, not twdensity*)
                        - classify_uda() in uda-manager.sh needs a new classification rule:
                          UDAs sourced from known extensions are tagged [extension:<name>]
                          alongside the existing [source:<service>] pattern
                        - service-uda-registry.yaml gets a new section: extensions
                          listing density + densitywindow with source=twdensity
                        - ww profile uda list shows [extension:twdensity] badge on these UDAs
                      This establishes the citation pattern for all future extension UDAs.

Proposed command syntax:
                      ww profile density install     Install twdensity + write UDAs to .taskrc
                      ww profile density run         Run twdensity to update density values
                      ww profile density config      Show/edit density window and urgency weights
                      ww profile density help        Usage + attribution

Attribution in help:
                      Powered by TWDensity · 00sapo
                      https://github.com/00sapo/TWDensity · MIT License

Acceptance criteria:  1. ww profile density install: pipx install twdensity + idempotent
                         UDA block written to active profile .taskrc
                      2. ww profile density run: calls twdensity with correct TASKRC/TASKDATA
                      3. service-uda-registry.yaml updated with density UDAs under extensions:
                      4. ww profile uda list shows [extension:twdensity] on density UDAs
                      5. docs/taskwarrior-extensions/twdensity-integration.md written

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/system/config/service-uda-registry.yaml
                      /Users/mp/ww/system/config/command-syntax.yaml
                      /Users/mp/ww/docs/taskwarrior-extensions/twdensity-integration.md

Fragility:            SERIALIZED: bin/ww
                      Low — additive .taskrc writes only

Status:               complete

Completion note:      Implemented in commit 2984728 / merge. Delivered:
                      profile-density.sh (install/run/config/help + attribution),
                      service-uda-registry.yaml extensions: section,
                      profile-uda.sh extension badge classification,
                      bin/ww density routing, CSSOT update,
                      twdensity-integration.md (includes citation pattern docs).
                      19 pre-existing failures, zero regressions.
