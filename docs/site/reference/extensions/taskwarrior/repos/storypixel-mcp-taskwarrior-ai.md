# storypixel/mcp-taskwarrior-ai

**URL:** https://github.com/storypixel/mcp-taskwarrior-ai  
**Stars:** 2  
**Language:** JavaScript  
**Last push:** 2026-04-07  
**Archived:** No  
**Topics:** ai-tools, claude, mcp, model-context-protocol, productivity, taskwarrior  

## Description

AI-native Taskwarrior bridge MCP server for Claude - Natural language task management with project context awareness

## Category

Sync

## Workwarrior Integration Rating

**Score:** 6  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +2: Urgency coefficients are a ww UDA focus area
- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration
- -2: Mobile — outside ww scope

## README excerpt

```
# MCP Taskwarrior AI Bridge

An AI-native Taskwarrior bridge that provides natural language task management for Claude Code and other AI systems. This MCP (Model Context Protocol) server extends Taskwarrior with context-aware, natural language capabilities while building on top of the existing Taskwarrior infrastructure.

## Features

- **Natural Language Processing**: Convert everyday language into Taskwarrior commands
- **Project Context Awareness**: Automatically detects current project/ticket context
- **Ticket Integration**: Sync tasks from ticket checklists (supports .tickets/ directory structure)
- **Eisenhower Matrix**: Organize tasks by urgency and importance
- **Smart Task Addition**: Intelligently parse priorities, due dates, projects, and tags
- **Shareable & Versioned**: Configuration can be tracked in Git

## Installation

### Prerequisites

1. Install Taskwarrior (if not already installed):
```bash
brew install task
```

2. Install Node.js (v20 or later):
```bash
brew install node
```

### Setup

1. Clone the repository:
```bash
git clone https://github.com/storypixel/mcp-taskwarrior-ai.git
cd mcp-taskwarrior-ai
```

2. Install dependencies:
```bash
npm install
```

3. Build the project:
```bash
npm run build
```

### Integration with Claude Code

Add the server to your Claude Code MCP configuration:

1. Open your Claude Code settings
2. Add to MCP servers:

```json
{
  "mcpServers": {
    "taskwarrior": {
      "type": "stdio",
      "command": "node",
      "args": ["/path/to/mcp-taskwarrior-ai/dist/index.js"],
      "env": {}
    }
  }
}
```

Or using the Claude CLI:
```bash
claude mcp add taskwarrior -s project -- node /path/to/mcp-taskwarrior-ai/dist/index.js
```

## Usage

### Natural Language Commands

The bridge understands natural language for task management:

- **Adding tasks**: "add fix the login bug", "create task for code review", "todo implement caching"
- **Listing tasks**: "show all tasks", "what should I work on next", "list urgent tasks", "show tasks for today"
- **Completing tasks**: "mark task 5 as done", "complete task 1", "finish the review task"
- **Context queries**: "where am I", "what's my current project", "show current context"

### Available Tools

#### `task_natural`
Execute Taskwarrior commands using natural language.

```typescript
{
  query: "add fix the authentication bug with high priority"
}
```

#### `task_smart_add`
Add tasks with structured metadata:

```typescript
{
  description: "Implement user authentication",
  project: "myheb-android",
  priority: "H",
  due: "tomorrow",
  tags: ["security", "auth"]
}
```

#### `task_ticket_sync`
Import tasks from a ticket's checklist:

```typescript
{
  ticket: "DRX-12345"
}
```

#### `task_eisenhower`
Get tasks organized by Eisenhower Matrix quadrants.

#### `task_where_am_i`
Get current context and suggested next actions based on project state.

#### `task_context_set`
Set the current project/context for all task operations:

```typescript
{
  contex
```