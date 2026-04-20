# MCP Integration: taskwarrior-mcp

**Upstream:** https://github.com/hnsstrk/taskwarrior-mcp
**Author:** hnsstrk · MIT License · Python
**Last assessed:** 2026-04-09

---

## Summary

`taskwarrior-mcp` is a Python MCP server exposing 11 TaskWarrior tools to any
MCP-capable AI agent. It integrates into workwarrior with **zero source modification** —
profile isolation works automatically through ww's existing `TASKRC`/`TASKDATA`
environment variables, which map directly to the server's `TW_MCP_TASKRC` and
`TW_MCP_TASK_DATA` config vars.

---

## Profile Isolation — How It Works

ww exports these env vars on profile activation:

```
TASKRC    = ~/ww/profiles/<name>/.taskrc
TASKDATA  = ~/ww/profiles/<name>/.task
```

`taskwarrior-mcp` reads `TW_MCP_TASKRC` and `TW_MCP_TASK_DATA` at startup.
`ww mcp register` passes the active profile's values at registration time:

```bash
claude mcp add --transport stdio --scope user taskwarrior \
  --env TW_MCP_TASKRC=$TASKRC \
  --env TW_MCP_TASK_DATA=$TASKDATA \
  -- taskwarrior-mcp
```

Each profile registration is independent. Switching profiles and re-registering
gives the MCP client access to that profile's task database.

---

## Integration Decision: No Modification

| Factor | Assessment |
|--------|------------|
| License | MIT — permissive, no restrictions |
| Profile isolation | Native via TW_MCP_TASKRC / TW_MCP_TASK_DATA env vars |
| Source modification required | **No** |
| MCP client compatibility | Any MCP client (Claude Code, Amazon Q, Gemini, etc.) |
| Install method | uv tool install (Python, editable) |
| Upstream maintenance | Active (Mar 2026) |

---

## What ww Adds

- `ww mcp install` — clone + install via uv, with attribution
- `ww mcp register [--scope user|project]` — register with active profile's TASKRC/TASKDATA
- `ww mcp status` — show install state, active profile, env vars that will be passed
- `ww mcp help` — usage + full attribution

---

## Quick Start

```bash
# 1. Install the MCP server
ww mcp install

# 2. Activate a profile
p-work

# 3. Register with your MCP client (default scope: user)
ww mcp register

# 4. Restart your MCP client — tasks are now accessible
```

---

## Using with Different AI Agents

### Claude Code
`ww mcp register` calls `claude mcp add` automatically if the `claude` CLI is present.

### Amazon Q / Gemini / Other MCP Clients
`ww mcp register` prints the manual registration command when `claude` CLI is absent:

```
command: taskwarrior-mcp
env:
  TW_MCP_TASKRC: /Users/mp/ww/profiles/work/.taskrc
  TW_MCP_TASK_DATA: /Users/mp/ww/profiles/work/.task
```

Configure your MCP client with these values.

---

## AI Agent Usage Examples

Once registered, any MCP client can manage tasks in the active profile:

```
"What are my open tasks?"
"Create a task 'Review PR #42' with high priority, due Friday, project Dev"
"Mark task a1b2c3d4 as done"
"Show me all tasks in project babbworks"
"/task-review"
"/task-plan"
```

---

## Per-Profile Registration Pattern

Each ww profile can have its own MCP registration. To switch profiles:

```bash
p-personal
ww mcp register --scope project   # registers personal profile for current project
```

The `--scope user` registration is global; `--scope project` is per-directory.
Use `project` scope when different projects should use different ww profiles.

---

## AI Agent Vision

This integration directly serves ww's design goal: AI agents managing their own
ww profiles. An agent with MCP access to a dedicated profile can:

- Log tasks as it works (`task add`)
- Track time via TimeWarrior hooks (already wired per-profile)
- Query its own task history
- Sync tasks to GitHub issues via the existing github-sync engine

The profile isolation contract means an agent's task data never bleeds into
a human operator's profile.

---

## Server Install Location

The server is cloned to `~/.local/share/ww/mcp/taskwarrior/` — outside the repo,
not committed. The binary (`taskwarrior-mcp`) is installed via `uv tool install`
into uv's tool bin directory (typically `~/.local/bin/`).

To update: `ww mcp install` (re-runs git pull + uv tool install).
To remove: `uv tool uninstall taskwarrior-mcp && rm -rf ~/.local/share/ww/mcp/taskwarrior/`
