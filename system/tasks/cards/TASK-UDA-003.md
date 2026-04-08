## TASK-UDA-003: UDA color schema — systematic color rules for TaskWarrior reports

Goal:                 Implement a ww-wide color convention for UDA fields that maps
                      UDA group membership to the established ww color scheme.
                      Color rules are written into .taskrc at profile creation and
                      when UDAs are added, giving users an immediate visual layer
                      in TaskWarrior reports without manual configuration.

Background color scheme (ww canonical):
                      Orange  — writing / content     (journals, narrative, documentation)
                      Blue    — time / actions        (scheduling, tracking, timewarrior)
                      Green   — tasks / planning      (status, phases, project management)
                      Red     — profile / identity    (people, orgs, github identity)
                      Purple  — unique identifiers    (IDs, URLs, reference numbers)
                      Black/White — accounting        (ledger, financial, currency)

Acceptance criteria:  1. system/config/uda-color-map.yaml defines:
                         - The canonical color-to-group mapping above
                         - Which UDA names belong to each group
                         - The TW color syntax for each (e.g. "color.uda.goals=orange")

                      2. ww profile uda add automatically writes color.uda.<name>=<color>
                         to .taskrc based on group membership.

                      3. ww profile create writes all color rules for all defined UDAs
                         into the new profile's .taskrc from the canonical map.

                      4. ww profile uda add --advanced allows color override per UDA.

                      5. Color rules for specific values (color.uda.phase.review=bold green)
                         are supported for UDAs with defined values — the map can include
                         per-value color overrides.

                      6. The color block in .taskrc is managed as a ww section:
                             # === WW COLOR RULES ===
                             color.uda.goals=orange
                             color.uda.phase.review=bold green
                             ...
                             # === END WW COLOR RULES ===

                      7. ww profile uda color <name> [color] — show or set color for a UDA
                         interactively if no color arg given.

Write scope:          /Users/mp/ww/system/config/uda-color-map.yaml  (new)
                      /Users/mp/ww/bin/ww
                      /Users/mp/ww/services/profile/subservices/uda-manager.sh
                      /Users/mp/ww/scripts/create-ww-profile.sh  (write color block on create)

Tests required:       bats tests/test-profile-uda.bats
                      Manual: task list after profile create — verify color rules active

Fragility:            Low — additive .taskrc writes only

Risk notes:           TW color names are terminal-dependent. Confirm that "orange" is
                      a valid TW color or use the rgb: prefix. TW supports:
                      black, red, green, yellow, blue, magenta, cyan, white,
                      bright variants, and rgb:R/G/B. "orange" may require rgb:255/165/0.
                      Purple may require rgb:128/0/128 or color5.
                      Test color rendering on both macOS and Linux before finalising.

Depends on:           TASK-UDA-001 (uda add must exist)

Status:               pending
