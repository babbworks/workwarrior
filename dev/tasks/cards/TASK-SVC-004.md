## TASK-SVC-004: Add profile import and restore workflow

Goal:                 Complement profile backup with safe import/restore commands.

Acceptance criteria:  1. `ww profile import <archive>` creates a profile from backup archive.
                      2. `ww profile restore <profile> <archive>` restores existing profile safely.
                      3. Restore process includes preflight validation and rollback guidance.

Write scope:          ~/ww/scripts/manage-profiles.sh
                      ~/ww/lib/profile-manager.sh
                      ~/ww/docs/usage-examples.md
                      ~/ww/dev/config/command-syntax.yaml

Tests required:       bats ~/ww/dev/tests/test-backup-portability.bats
                      bats ~/ww/dev/tests/test-profile-management-properties.bats
                      bash ~/ww/dev/tests/test-scripts-integration.sh

Rollback:             git checkout ~/ww/scripts/manage-profiles.sh ~/ww/lib/profile-manager.sh ~/ww/docs/usage-examples.md ~/ww/dev/config/command-syntax.yaml

Fragility:            None

Risk notes:           Existing behavior affected: backup/restore lifecycle and profile integrity.
                      Tests currently covering write scope: backup portability and profile management suites.
                      Rollback verification: restore/import command branches removed on revert.

Status:               complete

