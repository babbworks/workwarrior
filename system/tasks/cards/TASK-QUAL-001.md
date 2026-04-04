## TASK-QUAL-001: Enforce artifact hygiene across repository

Goal:                 Prevent generated/local artifacts from polluting diffs and tracked history.

Acceptance criteria:  1. `.gitignore` covers known runtime artifacts (`.DS_Store`, sqlite, logs, generated config).
                      2. Already tracked artifacts are untracked safely.
                      3. Hygiene check script can be run before merge.

Write scope:          /Users/mp/ww/.gitignore
                      /Users/mp/ww/system/scripts/check-artifacts.sh
                      /Users/mp/ww/system/workflows/phase1.md

Tests required:       git ls-files '*.DS_Store' '*.sqlite3'
                      bash /Users/mp/ww/system/scripts/check-artifacts.sh
                      git status --short

Rollback:             git checkout /Users/mp/ww/.gitignore /Users/mp/ww/system/scripts/check-artifacts.sh /Users/mp/ww/system/workflows/phase1.md

Fragility:            None

Risk notes:           Existing behavior affected: repository cleanliness and review signal quality.
                      Tests currently covering write scope: explicit git-tracking checks.
                      Rollback verification: ignore/check script revert.

Status:               pending

