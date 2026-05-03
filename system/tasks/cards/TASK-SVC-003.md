## TASK-SVC-003: Add service discovery info and help commands

Goal:                 Implement discoverable `ww service list/info/help` flows so users can navigate services from CLI.

Acceptance criteria:  1. `ww service list` enumerates available services with short descriptions.
                      2. `ww service info <name>` shows command syntax and scope requirements.
                      3. `ww service help <name>` routes to detailed usage help.

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/services/README.md
                      /Users/mp/ww/docs/service-development.md
                      /Users/mp/ww/system/config/command-syntax.yaml

Tests required:       bats /Users/mp/ww/tests/test-service-discovery.bats
                      bash /Users/mp/ww/tests/test-service-discovery.sh
                      /Users/mp/ww/bin/ww service list

Rollback:             git checkout /Users/mp/ww/bin/ww /Users/mp/ww/services/README.md /Users/mp/ww/docs/service-development.md /Users/mp/ww/system/config/command-syntax.yaml

Fragility:            SERIALIZED: /Users/mp/ww/bin/ww

Risk notes:           Existing behavior affected: service routing and help behavior.
                      Tests currently covering write scope: service discovery tests.
                      Rollback verification: file revert returns old list-only behavior.

Status:               complete
