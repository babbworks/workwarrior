## TASK-HEUR-001: Regenerate heuristic engine rules from current command surface

Goal:                 Rebuild cmd-heuristics.yaml from the current ww command surface.
                      The existing 627-rule corpus was compiled against an earlier CLI
                      layout and is stale. The heuristic engine powers natural language
                      routing in the browser CMD panel and will eventually be used by
                      the popup interface.

Depends on:           — (independent; the compiler already exists at scripts/compile-heuristics.py)

Acceptance criteria:  1. scripts/compile-heuristics.py runs successfully against the
                         current bin/ww command surface and services/ layout.
                      2. config/cmd-heuristics.yaml is regenerated with rules covering
                         all current commands and subcommands.
                      3. The browser's CMD panel correctly routes at least 10 representative
                         natural language inputs through the refreshed heuristic set.
                      4. No regression in existing heuristic matches that still apply.
                      5. New commands added since last compilation (list new, list switch,
                         list which, lists, stream status, etc.) have heuristic coverage.

Write scope:          config/cmd-heuristics.yaml                 (regenerated)
                      scripts/compile-heuristics.py              (may need updates for new commands)
                      config/cmd-heuristics-corpus.yaml          (if corpus needs expansion)

Tests required:       Manual: ww browser → CMD panel → test 10+ natural language inputs
                      Manual: verify new commands are routable via heuristic

Rollback:             git checkout config/cmd-heuristics.yaml

Fragility:            None. Generated config file; no production code touched.

Risk notes:           (Orchestrator) The compiler reads the command surface to generate
                      rules. If the command surface has changed significantly since
                      the last compilation, the corpus (training examples) may also need
                      updating. Check config/cmd-heuristics-corpus.yaml for coverage gaps.
                      The heuristic engine is loaded at browser server startup — restart
                      the browser after regeneration to pick up new rules.

Status:               pending
Taskwarrior:          (assign live TW id on dispatch)
