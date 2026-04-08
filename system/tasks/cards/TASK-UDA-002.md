## TASK-UDA-002: Unicode indicator system for UDA groups

Goal:                 Define a systematic unicode character scheme for UDA indicators,
                      where each UDA group has a distinct unicode character that appears
                      in TaskWarrior's indicator column. Makes the presence of UDA data
                      visible at a glance in task reports without showing values.

Background:           TaskWarrior supports uda.<name>.indicator=<char> which displays
                      in a special column in reports. A consistent unicode scheme keyed
                      to UDA group membership gives users an instant visual dashboard
                      of which metadata categories are populated per task.

Acceptance criteria:  1. A unicode indicator map is defined in system/config/uda-indicator-map.yaml
                         assigning one unicode character per UDA group/category.
                         Initial scheme (subject to user confirmation):
                           [github]     ⑆  (or similar — linked/chained symbol)
                           [time]       ⏱  (timer)
                           [financial]  ₿  (or ¥/$  — currency-neutral)
                           [identity]   ◈  (person/identity)
                           [content]    ✎  (writing/pen)
                           [planning]   ⊞  (grid/structure)
                           [system]     ⚙  (gear/config)
                           [custom]     ◆  (diamond — user-defined)

                      2. ww profile uda add automatically assigns the indicator
                         character matching the UDA's group membership.

                      3. ww profile uda list shows the indicator character in the
                         display alongside name/type/label columns.

                      4. A report column definition `uda_indicators` is written into
                         .taskrc that concatenates all indicator chars for a task
                         into a compact presence summary column.

                      5. Indicator characters are single-width in standard terminals
                         — multi-width emoji excluded from the default set.

                      6. User can override any indicator via ww profile uda add --advanced
                         or ww profile uda perm <name> indicator:<char>.

Write scope:          /Users/mp/ww/system/config/uda-indicator-map.yaml  (new)
                      /Users/mp/ww/services/profile/subservices/uda-manager.sh
                      /Users/mp/ww/bin/ww  (indicator assignment in uda add)

Tests required:       Manual: task list with indicator column after adding UDAs
                      bats tests/test-profile-uda.bats (indicator written to .taskrc)

Fragility:            Low — additive .taskrc writes only

Risk notes:           Unicode terminal width is environment-dependent. Test on both
                      macOS Terminal and common Linux terminals before finalising
                      character choices. Some unicode chars render as double-width
                      in certain terminal emulators and break column alignment.
                      Confirm indicator character set with user before implementation.

Depends on:           TASK-UDA-001 (profile uda add must exist before indicator
                      assignment can be wired in)

Status:               pending
