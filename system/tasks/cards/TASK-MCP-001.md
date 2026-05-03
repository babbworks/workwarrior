## TASK-MCP-001: Integrate taskwarrior-mcp as ww mcp command

Goal:                 Wrap hnsstrk/taskwarrior-mcp as ww mcp — an MCP server that exposes
                      TaskWarrior to any MCP-capable AI agent (Claude Code, Amazon Q, Gemini,
                      etc.) with full ww profile isolation. Directly serves the vision of AI
                      agents managing their own ww profiles.

Upstream:             https://github.com/hnsstrk/taskwarrior-mcp
                      Author: hnsstrk · MIT License · Python · Last push: 2026-03-18
                      11 MCP tools, 4 slash commands, 2 specialized agents, auto-skill.
                      Supports TW_MCP_TASKRC and TW_MCP_TASK_DATA env var overrides.

Acceptance criteria:  1. ww mcp install
                         - Checks for uv, installs if missing (brew install uv)
                         - Clones hnsstrk/taskwarrior-mcp to ~/.local/share/ww/mcp/taskwarrior/
                         - Runs: uv tool install -e ./mcp-server
                         - Verifies taskwarrior-mcp binary is on PATH
                         - Prints attribution: upstream repo, author, license

                      2. ww mcp register [--scope user|project]
                         - Runs: claude mcp add --transport stdio --scope <scope> taskwarrior
                             --env TW_MCP_TASKRC=$TASKRC
                             --env TW_MCP_TASK_DATA=$TASKDATA
                             -- taskwarrior-mcp
                         - Default scope: user
                         - Requires active profile (TASKRC/TASKDATA must be set)
                         - Prints: registered for profile <name> with scope <scope>

                      3. ww mcp status
                         - Shows: installed (yes/no), registered scopes, active profile
                         - Shows env vars that will be passed: TW_MCP_TASKRC, TW_MCP_TASK_DATA

                      4. ww mcp help
                         - Usage, subcommands, full attribution block:
                             Powered by taskwarrior-mcp · hnsstrk
                             https://github.com/hnsstrk/taskwarrior-mcp · MIT License

                      5. docs/taskwarrior-extensions/mcp-integration.md written:
                         - Assessment, decision rationale, profile isolation mechanism
                         - How to use with Claude Code, Amazon Q, Gemini
                         - Per-profile registration pattern
                         - AI agent usage examples (agent managing its own profile)

                      6. mcp domain added to CSSOT (command-syntax.yaml)

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/system/config/command-syntax.yaml
                      /Users/mp/ww/docs/taskwarrior-extensions/mcp-integration.md  (new)

Tests required:       Manual: ww mcp install; ww mcp status; ww mcp register
                      bats tests/ (regression check only — no new BATS needed for install wrappers)

Rollback:             git checkout /Users/mp/ww/bin/ww
                      git checkout /Users/mp/ww/system/config/command-syntax.yaml
                      rm -rf ~/.local/share/ww/mcp/taskwarrior/

Fragility:            SERIALIZED: bin/ww (one writer at a time)

Risk notes:           Zero source modification to upstream. Profile isolation via
                      TW_MCP_TASKRC/TW_MCP_TASK_DATA env vars — same pattern as tui.
                      install step clones to ~/.local/share/ww/mcp/ (outside repo, not committed).
                      register step calls claude CLI — must not fail if claude is absent,
                      just warn and print the manual registration command.
                      Attribution must appear in both ww mcp help and mcp-integration.md.

Status:               complete

Completion note:      Implemented in commit 602d240 / merge ac19057+. Delivered:
                      cmd_mcp() in bin/ww (install/register/status/help with attribution),
                      mcp + tui domains in CSSOT, docs/taskwarrior-extensions/mcp-integration.md.
                      Zero source modification to upstream. Profile isolation via
                      TW_MCP_TASKRC/TW_MCP_TASK_DATA. 19 pre-existing failures, zero regressions.
