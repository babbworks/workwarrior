## TASK-URG-001: Interactive urgency coefficient tuning

Goal:                 Surface TaskWarrior's urgency scoring system through a ww-native
                      interactive interface. Allow users to view current coefficients,
                      understand what drives urgency on their tasks, and adjust
                      coefficients per UDA group, project tag, or profile without
                      needing to know raw .taskrc syntax.

Background:           TaskWarrior urgency is a weighted sum:
                        urgency = Σ (coefficient × factor_value)
                      UDA coefficients:
                        urgency.uda.<name>.coefficient        — presence of any value
                        urgency.uda.<name>.<value>.coefficient — specific value match
                      Both types stack. Current defaults give due date the most weight
                      (12.0), blocking tasks next (8.0). UDA coefficients are 0 by
                      default unless explicitly set.

                      Use cases this enables:
                        - Mark all tasks in a "review" phase as more urgent than "dev"
                        - Make tasks with goals set rank higher than tasks without
                        - Give a specific profile's tasks a global urgency boost
                        - Give a group of profiles shared urgency rules

Acceptance criteria:  1. ww profile urgency show
                         - Displays current urgency coefficients in readable format
                         - Groups by: built-in factors | UDA presence | UDA values
                         - Shows effective urgency score for each currently active task
                           alongside the breakdown of which factors contribute

                      2. ww profile urgency set <factor> <value>
                         - Sets urgency.<factor>.coefficient=<value> in .taskrc
                         - Validates value is numeric
                         - Examples:
                             ww profile urgency set uda.phase.review 5.0
                             ww profile urgency set due 10.0

                      3. ww profile urgency tune
                         - Interactive wizard: shows each UDA group and current coefficient
                         - Prompts to raise/lower/leave each one
                         - Confirms changes before writing to .taskrc
                         - Shows before/after urgency ranking for top 10 tasks

                      4. ww profile urgency reset
                         - Removes all ww-managed urgency coefficients from .taskrc
                         - Restores TW defaults

                      5. Group-level urgency:
                         - ww group urgency set <group> <factor> <value>
                         - Writes coefficient into each member profile's .taskrc
                         - Shared urgency rules propagate across group members

                      6. ww profile urgency explain <task-id>
                         - Shows full urgency breakdown for a specific task:
                             due date:    +8.4  (due in 3 days)
                             phase=review: +5.0
                             goals set:   +2.0
                             blocked:     -5.0
                             ─────────────────
                             total:       10.4

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/services/profile/urgency.sh  (new service)
                      /Users/mp/ww/system/config/command-syntax.yaml

Tests required:       bats tests/
                      Manual: ww profile urgency show / tune / explain <id>

Fragility:            Low — .taskrc writes only; no external side effects

Risk notes:           Coefficient changes affect task ranking globally within the profile.
                      The interactive wizard must clearly show the impact before confirming.
                      Group-level propagation writes to multiple .taskrc files — confirm
                      scope with user before executing.

Depends on:           TASK-UDA-001 (UDA groups must be defined to tune by group)

Status:               complete

Completion note:      Implemented in commit 6f3fb4b. Delivered: services/profile/urgency.sh
                      (show/set/tune/reset/explain/group subcommands), WW URGENCY sentinel
                      block in .taskrc, bin/ww routing, CSSOT update, 226-test
                      test-profile-urgency.bats.
