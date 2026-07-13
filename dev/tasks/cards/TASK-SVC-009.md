## TASK-SVC-009: ww network CLI — promote browser network checks to CLI command

Goal:                 `ww network [check|status]` runs the same connectivity checks that the browser Network section uses (internet/IP, GitHub API, Ollama) and prints a compact terminal report.

Acceptance criteria:  - [ ] `ww network` / `ww network status` prints connectivity table: internet (latency + IP), github (latency), ollama (status/models)
                      - [ ] `ww network check` alias for status
                      - [ ] `ww network help` shows usage
                      - [ ] Exit 0 if all checks pass; exit 1 if any fail
                      - [ ] `services/network/network.sh` promoted from stub
                      - [ ] bin/ww routes `network` to the service

Write scope:          - `services/network/network.sh` (implement)
                      - `bin/ww` (add `network)` case)

Notes:                priority: M · area: cli · created: 2026-04-27

Status:               complete — 2026-07-13 (verified by execution: `ww network status|check|help` all pass; exit 0 all-pass / 1 on failure)
