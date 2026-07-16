## TASK-SVC-003: Add service discovery info and help commands

Goal:                 Implement discoverable `ww service list/info/help` flows so users can navigate services from CLI.

Acceptance criteria:  1. `ww service list` enumerates available services with short descriptions.
                      2. `ww service info <name>` shows command syntax and scope requirements.
                      3. `ww service help <name>` routes to detailed usage help.

Write scope:          ~/ww/bin/ww
                      ~/ww/services/README.md
                      ~/ww/docs/service-development.md
                      ~/ww/dev/config/command-syntax.yaml

Tests required:       bats ~/ww/dev/tests/test-service-discovery.bats
                      bash ~/ww/dev/tests/test-service-discovery.sh
                      ~/ww/bin/ww service list

Rollback:             git checkout ~/ww/bin/ww ~/ww/services/README.md ~/ww/docs/service-development.md ~/ww/dev/config/command-syntax.yaml

Fragility:            SERIALIZED: ~/ww/bin/ww

Risk notes:           Existing behavior affected: service routing and help behavior.
                      Tests currently covering write scope: service discovery tests.
                      Rollback verification: file revert returns old list-only behavior.

Status:               complete
