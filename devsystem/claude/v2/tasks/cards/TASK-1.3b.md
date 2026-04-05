## TASK-1.3b: Explorer B — Code/Test Reality Audit

Goal:                 Produce a test coverage map, code-vs-doc gap list, and required
                      test baseline per change type.
Acceptance criteria:  1. Every lib/ file has a coverage classification
                         (covered/gap-critical/gap-important/gap-deferred)
                      2. Every TODO/FIXME in lib/github-*.sh and lib/sync-*.sh is identified
                         and severity-classified
                      3. Required test baseline per change type is defined
                         (lib / service / profile / bin_ww / github_sync)
                      4. Top regression-risk hotspots identified (min 5, with file:line)
                      5. Output written to devsystem/claude/v2/audits/<date>-explorer-b.md
Write scope:          devsystem/claude/v2/audits/<date>-explorer-b.md (new file only)
Tests required:       N/A — read-only audit
Rollback:             Delete output file
Fragility:            None — read-only
Risk notes:           Read: all lib/github-*.sh, lib/sync-*.sh (TODOs + dry-run paths);
                      all tests/ files (what they cover); all services/ --help responses.
                      Use template: devsystem/claude/v2/templates/explorer-b-output.md
                      Run in parallel with TASK-1.3a
Status:               pending
