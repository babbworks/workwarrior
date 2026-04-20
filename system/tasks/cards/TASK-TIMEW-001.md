## TASK-TIMEW-001: ww timew extensions surface — billable hours and per-profile extension management

Goal:                 Add ww timew extensions as a per-profile TimeWarrior extension manager.
                      First extension: trev-dev/timew-billable for billable hour reports.
                      Solves the path problem: timew extensions must live in
                      $TIMEWARRIORDB/extensions/, not the global ~/.timewarrior/extensions/.

Upstream (billable):  https://github.com/trev-dev/timew-billable
                      Author: trev-dev · MIT License · Nim · Last push: 2024-06-08
                      Billable hour reports with per-client rates, CSV export, terminal tables.
                      Requires Nim + Nimble to build from source.

Acceptance criteria:  1. ww timew extensions list
                         - Lists installed extensions in active profile's $TIMEWARRIORDB/extensions/
                         - Shows: name, source (upstream URL), version if detectable

                      2. ww timew extensions install billable
                         - Checks for nim/nimble, warns if missing with install hint
                         - Clones trev-dev/timew-billable to a temp dir
                         - Builds: nim c -d:release src/billable.nim
                         - Installs binary to $TIMEWARRIORDB/extensions/billable
                         - Prints attribution: upstream repo, author, license

                      3. ww timew extensions install <url>
                         - Generic install from any GitHub URL
                         - Clones, attempts nim/python/shell detection, installs to profile extensions/

                      4. ww timew extensions remove <name>
                         - Removes from active profile's extensions/ only

                      5. ww timew extensions help
                         - Usage, subcommands, attribution for billable:
                             Powered by timew-billable · trev-dev
                             https://github.com/trev-dev/timew-billable · MIT License

                      6. docs/taskwarrior-extensions/timew-billable-integration.md written:
                         - Assessment, decision rationale, per-profile path mechanism
                         - billable configuration (rates, project markers)
                         - Example: timew report billable after ww timew extensions install billable

                      7. timew extensions domain added to CSSOT

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/system/config/command-syntax.yaml
                      /Users/mp/ww/docs/taskwarrior-extensions/timew-billable-integration.md  (new)

Tests required:       Manual: ww timew extensions install billable; timew report billable
                      bats tests/ (regression check)

Rollback:             git checkout /Users/mp/ww/bin/ww
                      git checkout /Users/mp/ww/system/config/command-syntax.yaml
                      rm $TIMEWARRIORDB/extensions/billable

Fragility:            SERIALIZED: bin/ww
                      Low overall — no lib changes, no .taskrc writes

Risk notes:           Nim build dependency is the main risk — if nim is absent, install
                      must fail gracefully with a clear message, not a build error.
                      Per-profile extension path ($TIMEWARRIORDB/extensions/) must be
                      created if it doesn't exist.
                      Attribution must appear in ww timew extensions help and the doc.
                      Disjoint write set from TASK-MCP-001 only if bin/ww edits are
                      serialized — dispatch after MCP-001 is merged.

Status:               complete — 2026-04-20

Completion note:      Implemented `ww timew extensions {list,install,remove,help}` in `bin/ww`
                      (per-profile `$TIMEWARRIORDB/extensions/`, metadata `*.ww-ext.json`).
                      Preset `billable` builds trev-dev/timew-billable with `nim c -d:release src/billable.nim`.
                      Generic `install <https://…git>` supports billable layout, nimble, or first `.sh`.
                      Doc: `docs/taskwarrior-extensions/timew-billable-integration.md`.
                      CSSOT: `system/config/command-syntax.yaml` domain `timew`.
                      BATS: `tests/test-timew-extensions.bats`.
