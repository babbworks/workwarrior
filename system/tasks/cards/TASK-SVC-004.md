## TASK-SVC-004: Add profile import and restore workflow

Goal:                 Complement profile backup with safe import/restore commands.

Acceptance criteria:  1. `ww profile import <archive>` creates a profile from backup archive.
                      2. `ww profile restore <profile> <archive>` restores existing profile safely.
                      3. Restore process includes preflight validation and rollback guidance.

Write scope:          /Users/mp/ww/scripts/manage-profiles.sh
                      /Users/mp/ww/lib/profile-manager.sh
                      /Users/mp/ww/docs/usage-examples.md
                      /Users/mp/ww/system/config/command-syntax.yaml

Tests required:       bats /Users/mp/ww/tests/test-backup-portability.bats
                      bats /Users/mp/ww/tests/test-profile-management-properties.bats
                      bash /Users/mp/ww/tests/test-scripts-integration.sh

Rollback:             git checkout /Users/mp/ww/scripts/manage-profiles.sh /Users/mp/ww/lib/profile-manager.sh /Users/mp/ww/docs/usage-examples.md /Users/mp/ww/system/config/command-syntax.yaml

Fragility:            None

Risk notes:           Existing behavior affected: backup/restore lifecycle and profile integrity.
                      Tests currently covering write scope: backup portability and profile management suites.
                      Rollback verification: restore/import command branches removed on revert.

Status:               complete

