# JoeyMckenzie/questlog-mcp

**URL:** https://github.com/JoeyMckenzie/questlog-mcp  
**Stars:** 0  
**Language:** TypeScript  
**Last push:** 2026-03-15  
**Archived:** No  
**Topics:** ai, claude, codex, mcp, taskwarrior  

## Description

General purpose MCP for Taskwarrior.

## Category

Time Tracking

## Workwarrior Integration Rating

**Score:** 2  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos

## README excerpt

```
# questlog-mcp

[![CI](https://github.com/joeymckenzie/taskwarrior-mcp/actions/workflows/ci.yml/badge.svg)](https://github.com/joeymckenzie/taskwarrior-mcp/actions/workflows/ci.yml)
[![npm version](https://img.shields.io/npm/v/questlog-mcp)](https://www.npmjs.com/package/questlog-mcp)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

An MCP server that exposes [Taskwarrior](https://taskwarrior.org/) task management to AI assistants and agentic coding tools. It wraps the `task` CLI and surfaces a set of structured tools for creating, querying, modifying, and managing tasks directly from your AI coding environment.

## Requirements

- [Taskwarrior](https://taskwarrior.org/download/) v3.x (v2 is not supported)
- Node.js v18 or later

### Install Taskwarrior

**macOS (Homebrew):**

```sh
brew install task
```

**Linux (apt):**

```sh
sudo apt install taskwarrior
```

Verify the installation and confirm you are on version 3:

```sh
task --version
```

## Tools

| Tool            | Description                                                                 |
| --------------- | --------------------------------------------------------------------------- |
| `task_list`     | List tasks with an optional Taskwarrior filter string                       |
| `task_get`      | Get a single task by its numeric ID                                         |
| `task_add`      | Add a new task with optional project, priority, tags, and due date          |
| `task_bulk_add` | Add multiple tasks at once                                                  |
| `task_complete` | Mark a task as complete by ID                                               |
| `task_modify`   | Modify an existing task's description, project, priority, tags, or due date |
| `task_delete`   | Delete a task by ID                                                         |
| `task_annotate` | Add an annotation (note) to a task                                          |
| `task_summary`  | Get a high-level summary of all tasks with counts and a project breakdown   |
| `task_start`    | Start time tracking on a task                                               |
| `task_stop`     | Stop time tracking on a task                                                |

### Tool Details

**`task_list`**

Lists tasks. Accepts an optional `filter` string using standard Taskwarrior filter syntax.

```
filter: "project:work status:pending"
filter: "priority:H due:today"
filter: "+home"
```

**`task_get`**

Returns a single task by its numeric ID.

```
id: 42
```

**`task_add`**

Creates a new task. Only `description` is required.

```
description: "Write release notes"
project: "work"
priority: "H"   // H, M, or L
tags: ["docs", "release"]
due: "2024-12-31"
```

**`task_bulk_add`**

Creates multiple tasks in a single call. Accepts an array of task objects with the same fields as `task_add`. Requires at least one task.

```
tasks: [
  { description: "Set up
```