## TASK-ISSUES-002: Bugwarrior profile setup for alpha and bravo profiles

Goal:                 Only the `acme` profile has bugwarrior configured. The `alpha` and `bravo`
                      profiles need equivalent setup so issue pull works across all profiles.

Acceptance criteria:  1. `profiles/alpha/.config/bugwarrior/bugwarriorrc` written and validated.
                      2. `profiles/bravo/.config/bugwarrior/bugwarriorrc` written and validated.
                      3. Both profiles have GitHub UDAs appended to their `.taskrc` via
                         `bugwarrior uda`.
                      4. `i pull` runs cleanly under each profile.
                      5. `BUGWARRIORRC` is exported correctly when each profile is activated
                         (already implemented in use_task_profile — just needs config files).

Write scope:          $WW_BASE/profiles/alpha/.config/bugwarrior/bugwarriorrc  (new)
                      $WW_BASE/profiles/bravo/.config/bugwarrior/bugwarriorrc  (new)
                      $WW_BASE/profiles/alpha/.taskrc  (UDA append)
                      $WW_BASE/profiles/bravo/.taskrc  (UDA append)

Tests required:       Manual: p-alpha && i pull; p-bravo && i pull

Rollback:             rm profiles/alpha/.config/bugwarrior/bugwarriorrc
                      rm profiles/bravo/.config/bugwarrior/bugwarriorrc
                      git checkout profiles/alpha/.taskrc profiles/bravo/.taskrc

Fragility:            Low — profile data only, no lib or service changes.

Risk notes:           Determine correct GitHub login/org/token for each profile before writing config.
                      Use @oracle:eval:gh auth token if the same gh auth covers all profiles.

Status:               deferred

Deferral reason:      alpha and bravo do not currently have GitHub issue sync needs.
                      Strategic direction changed: acme is now the exemplar profile.
                      Reopen if alpha/bravo require independent GitHub auth in future.
