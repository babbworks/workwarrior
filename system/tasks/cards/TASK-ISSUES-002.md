## TASK-ISSUES-002: Bugwarrior profile setup for john and mark profiles

Goal:                 Only the `babb` profile has bugwarrior configured. The `john` and `mark`
                      profiles need equivalent setup so issue pull works across all profiles.

Acceptance criteria:  1. `profiles/john/.config/bugwarrior/bugwarriorrc` written and validated.
                      2. `profiles/mark/.config/bugwarrior/bugwarriorrc` written and validated.
                      3. Both profiles have GitHub UDAs appended to their `.taskrc` via
                         `bugwarrior uda`.
                      4. `i pull` runs cleanly under each profile.
                      5. `BUGWARRIORRC` is exported correctly when each profile is activated
                         (already implemented in use_task_profile — just needs config files).

Write scope:          /Users/mp/ww/profiles/john/.config/bugwarrior/bugwarriorrc  (new)
                      /Users/mp/ww/profiles/mark/.config/bugwarrior/bugwarriorrc  (new)
                      /Users/mp/ww/profiles/john/.taskrc  (UDA append)
                      /Users/mp/ww/profiles/mark/.taskrc  (UDA append)

Tests required:       Manual: p-john && i pull; p-mark && i pull

Rollback:             rm profiles/john/.config/bugwarrior/bugwarriorrc
                      rm profiles/mark/.config/bugwarrior/bugwarriorrc
                      git checkout profiles/john/.taskrc profiles/mark/.taskrc

Fragility:            Low — profile data only, no lib or service changes.

Risk notes:           Determine correct GitHub login/org/token for each profile before writing config.
                      Use @oracle:eval:gh auth token if the same gh auth covers all profiles.

Status:               deferred

Deferral reason:      john and mark do not currently have GitHub issue sync needs.
                      Strategic direction changed: babb is now the exemplar profile.
                      Reopen if john/mark require independent GitHub auth in future.
