# hnsstrk/taskwarrior-mcp

**URL:** https://github.com/hnsstrk/taskwarrior-mcp  
**Stars:** 0  
**Language:** Python  
**Last push:** 2026-03-18  
**Archived:** No  
**Topics:** claude, mcp, productivity, python, taskwarrior  

## Description

MCP server for Taskwarrior — use with Claude Code, Claude Desktop, or any MCP client

## Category

Sync

## Workwarrior Integration Rating

**Score:** 10  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +2: Sync capability relevant to ww profile isolation
- +1: Shell integration — ww is shell-first
- +1: Shell scripting — matches ww stack
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Python — tooling language used in ww

## README excerpt

```
# Taskwarrior MCP

A complete [Taskwarrior](https://taskwarrior.org/) integration for [Claude Code](https://claude.ai/code) — MCP server with 11 tools, slash commands, specialized agents, and an auto-invoked skill.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/Python-%3E%3D3.10-blue.svg)](https://www.python.org/)
[![MCP](https://img.shields.io/badge/MCP-Compatible-green.svg)](https://modelcontextprotocol.io/)

## Features

- **11 MCP Tools** -- Create, list, modify, complete, delete, start/stop tasks, query projects, tags, and statistics
- **4 Slash Commands** -- `/task-review`, `/task-plan`, `/task-inbox`, `/task-sync`
- **2 Specialized Agents** -- `task-manager` (full write access) and `task-reviewer` (read-only analysis)
- **Auto-Skill** -- Activates automatically when context involves tasks, todos, or deadlines
- **Hooks** -- Visual feedback after write operations
- **Shell-Injection Prevention** -- Pydantic validation on all inputs, `subprocess` with `shell=False`
- **Taskwarrior 2.x and 3.x** -- Supports both major versions

## Prerequisites

- [Taskwarrior](https://taskwarrior.org/) 2.x or 3.x (must be in `$PATH`)
- Python >= 3.10
- [uv](https://docs.astral.sh/uv/)
- [Claude Code](https://claude.ai/code)

## Installation

### 1. Clone and Install the MCP Server

```bash
git clone https://github.com/hnsstrk/taskwarrior-mcp.git
cd taskwarrior-mcp
uv tool install -e ./mcp-server
```

This installs `taskwarrior-mcp` as an editable tool. Code changes take effect immediately.

### 2. Register the MCP Server in Claude Code

```bash
claude mcp add --transport stdio --scope user taskwarrior \
  --env TW_MCP_LOG_LEVEL=WARNING \
  -- taskwarrior-mcp
```

### 3. Load the Plugin

```bash
claude --plugin-dir /path/to/taskwarrior-mcp/plugin
```

For persistent access, add a shell alias to your `~/.zshrc` or `~/.bashrc`:

```bash
alias claude='claude --plugin-dir /path/to/taskwarrior-mcp/plugin'
```

## Quick Start

Once installed, you can interact with Taskwarrior directly through Claude Code:

```
> What are my open tasks?
> Create a task "Review PR #42" with high priority, due end of week, in project Dev
> Mark task a1b2c3d4 as done
> /task-review
```

The skill activates automatically whenever you mention tasks, todos, or deadlines. You can also use the slash commands for structured workflows.

## Configuration

All settings are configured via environment variables with the prefix `TW_MCP_`:

| Variable | Default | Description |
|----------|---------|-------------|
| `TW_MCP_TASK_BINARY` | `task` | Path to the Taskwarrior binary |
| `TW_MCP_TASK_DATA` | -- | Override for `rc.data.location` |
| `TW_MCP_TASKRC` | -- | Path to an alternative `.taskrc` |
| `TW_MCP_DEFAULT_LIMIT` | `50` | Default limit for task listings |
| `TW_MCP_COMMAND_TIMEOUT` | `30` | Timeout in seconds |
| `TW_MCP_LOG_LEVEL` | `INFO` | Log level (DEBUG, INFO, WARNING, ERROR) |
| `TW_MCP_AUTO_SYNC` | `false` | A
```