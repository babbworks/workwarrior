## TASK-UDA-001: Build ww profile uda surface — list, add, remove, group, manage, perm

Goal:                 Wire uda-manager.sh as ww profile uda manage. Build the full
                      ww profile uda subcommand surface as the canonical UDA management
                      layer for all profiles. Redirect ww issues uda to here with a
                      printed message. Update bin/ww, cmd_profile, and CSSOT.

Acceptance criteria:  1. ww profile uda list
                         - Reads .taskrc and outputs all UDAs grouped by source:
                           [github]   githubnumber, githubtitle, githubstate ...
                           [system]   goals, phase, scope, stack, risks ...
                           [custom]   any user-defined UDAs not in known service sets
                         - Columns: name | type | label | source | permissions
                         - ww profile udas (plural) is an alias producing identical output
                         - <profilename> udas produces identical output via profile namespace

                      2. ww profile uda add [name]
                         - If name not passed, prompts for it
                         - Tier 1 (always prompted): name, type
                         - Tier 2 (prompted, skippable): label, values (string only),
                           default, optional flag
                         - Values flow:
                           a. User enters comma-separated values
                           b. System echoes back ordered list with positions
                           c. "This order is your sort order — confirm or re-enter?"
                           d. "Allow unset/empty? [Y/n]" — appends trailing comma if yes
                           e. If no trailing comma, default is required
                         - Tier 3 (--advanced flag): indicator, color, urgency coefficients
                         - Writes uda.<name>.type, .label, .values, .default to .taskrc
                         - Idempotent: warns if UDA name already exists, offers update

                      3. ww profile uda remove <name>
                         - Warns if UDA belongs to a known service (github*, bugwarrior*)
                         - Warns if UDA has values set on any task in the profile
                         - Requires --force to proceed past either warning
                         - Removes all uda.<name>.* lines from .taskrc

                      4. ww profile uda group <name>
                         - Prompts: description (free text), tags (space-separated)
                         - Prompts: which UDAs to include (numbered list, multi-select)
                         - Writes WW UDA GROUPS block to end of .taskrc:
                             # === WW UDA GROUPS ===
                             # group:work udas:goals,phase,scope description:"..." tags:github,planning
                             # === END WW UDA GROUPS ===
                         - Idempotent: updates existing group if name matches

                      5. ww profile uda manage
                         - Drops into uda-manager.sh interactive session
                         - uda-manager.sh updated to read active profile context
                           (WORKWARRIOR_BASE, TASKRC) rather than hardcoded paths
                         - Warns before delete/rename of service-managed UDAs

                      6. ww profile uda perm <name> <permission>
                         - Writes to profiles/<name>/.config/sync-permissions
                         - Valid permissions: nosync, deny:<service>, deny:<service>:<channel>,
                           readonly, writeonly, private, noreport, noexport, noai, managed, locked
                         - Multiple permissions comma-separated: nosync,noai
                         - Displays current permissions for a UDA when no permission arg given

                      7. ww issues uda
                         - Prints: "UDA management has moved to: ww profile uda"
                         - Prints: "Run 'ww profile uda list' to see all UDAs"
                         - Exits 0 (not an error, just a redirect)

                      8. BATS tests cover: list output grouped correctly, add writes
                         correct .taskrc lines, remove with and without --force,
                         group block written and updated, uda redirect message

Write scope:          $WW_BASE/bin/ww
                      $WW_BASE/services/profile/subservices/uda-manager.sh
                      $WW_BASE/lib/sync-permissions.sh  (new)
                      $WW_BASE/system/config/command-syntax.yaml
                      $WW_BASE/tests/test-profile-uda.bats  (new)

Tests required:       bats tests/test-profile-uda.bats
                      bats tests/
                      Manual: ww profile uda list / add goals / group work / perm goals nosync

Rollback:             git checkout $WW_BASE/bin/ww
                      git checkout $WW_BASE/services/profile/subservices/uda-manager.sh
                      rm $WW_BASE/lib/sync-permissions.sh

Fragility:            SERIALIZED: bin/ww (one writer at a time)
                      HIGH FRAGILITY: any .taskrc write must be additive and non-destructive

Risk notes:           .taskrc writes must never corrupt existing TW config.
                      Use append + section-replace pattern for the UDA GROUPS block.
                      uda-manager.sh path hardcoding must be removed before wiring.
                      sync-permissions file is gitignored (profile config).
                      Depends on: profile namespace (Option B) for acme udas form —
                      that can be a follow-up; list/add/remove/group/perm can ship first.

Status:               complete

Completion note:      Implemented in commit 7ab0b2b. Delivered: profile-uda.sh service
                      (list/add/remove/group/perm), lib/sync-permissions.sh, service-uda-registry.yaml,
                      bin/ww routing, CSSOT update, 34 BATS tests in test-profile-uda.bats,
                      test-smoke.bats (12 pre-flight checks). ww issues uda redirect implemented.
