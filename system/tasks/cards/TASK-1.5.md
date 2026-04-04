## TASK-1.5: Artifact cleanup

Goal:                 Ensure .gitignore excludes all generated artifacts so future PRs
                      carry no noise in their diffs.
Acceptance criteria:  1. git status on a clean working tree shows none of:
                         .DS_Store, .sqlite3, github-sync logs, generated config
                      2. .gitignore covers: **/.DS_Store, *.sqlite3, github-sync/,
                         profiles/*/.config/, profiles/*/list/
                      3. bin/wwctl verify-phase1 passes all hygiene checks
Write scope:          /Users/mp/ww/.gitignore
                      git rm --cached for already-tracked artifacts (no file content change)
Tests required:       git status (verify clean output)
                      bin/wwctl verify-phase1 (hygiene section)
Rollback:             git checkout .gitignore
                      git restore --staged <any accidentally staged files>
Fragility:            Low — .gitignore only
Risk notes:           Items to add to .gitignore:
                        **/.DS_Store
                        profiles/*/.task/taskchampion.sqlite3
                        profiles/*/.task/taskchampion.sqlite3-shm
                        profiles/*/.task/taskchampion.sqlite3-wal
                        profiles/*/.task/github-sync/
                        profiles/*/.config/
                        profiles/*/list/
                        system/audits/
                        system/reports/
                        system/logs/
                      Already tracked: .DS_Store files in root, profiles/, services/
Status:               pending
