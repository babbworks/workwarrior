# sznicolas/pytaskwarrior

**URL:** https://github.com/sznicolas/pytaskwarrior  
**Stars:** 1  
**Language:** Python  
**Last push:** 2026-04-07  
**Archived:** No  
**Topics:** taskwarrior, taskwarrior3  

## Description

Python module wrapping Taskwarrior

## Category

Sync

## Workwarrior Integration Rating

**Score:** 13  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +2: Urgency coefficients are a ww UDA focus area
- +3: UDAs — core to ww service model
- +1: Shell scripting — matches ww stack
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration
- +1: Python — tooling language used in ww

## README excerpt

```
# pytaskwarrior

[![Python 3.12+](https://img.shields.io/badge/python-3.12+-blue.svg)](https://www.python.org/downloads/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Code style: ruff](https://img.shields.io/badge/code%20style-ruff-000000.svg)](https://github.com/astral-sh/ruff)
[![Tests](https://github.com/sznicolas/pytaskwarrior/workflows/CI/badge.svg)](https://github.com/sznicolas/pytaskwarrior/actions)
[![Coverage](https://img.shields.io/badge/coverage-96%25-brightgreen.svg)](https://github.com/sznicolas/pytaskwarrior)
[![PyPI version](https://img.shields.io/pypi/v/pytaskwarrior.svg)](https://pypi.org/project/pytaskwarrior/)

A modern Python wrapper for [TaskWarrior](https://taskwarrior.org/) v3.4, the command-line task management tool.

**v2.0.0**: Major release with breaking API changes (Context.define now accepts ContextDTO; UdaConfig.type → UdaConfig.uda_type). All tests passing and documentation updated.

## Features

- **Full CRUD operations** - Create, read, update, delete tasks
- **Type-safe** - Pydantic models with full type hints
- **Context management** - Define, apply, and switch contexts
- **UDA support** - User Defined Attributes
- **Recurring tasks** - Full recurrence support
- **Annotations** - Add notes to tasks
- **Date calculations** - Use TaskWarrior's date expressions

## Requirements

- Python 3.12+
- TaskWarrior 3.4+ installed and accessible via `task` command

> **Note:** If you need to build TaskWarrior 3.x from source, see [Building TaskWarrior 3.x](docs/building-taskwarrior.md) for a Docker-based build process and detailed instructions.

## Installation

```bash
pip install pytaskwarrior==2.0.0
```

Or install from source:

```bash
git clone https://github.com/sznicolas/pytaskwarrior.git
cd pytaskwarrior
pip install -e .
```

## Quick Start

### Running the bundled examples in isolation

The examples in the examples/ directory are designed to be independent of your personal TaskWarrior configuration. They use the bundled examples/taskrc_example and examples/task_data so they won't modify your default ~/.taskrc or TaskWarrior database.

To run an example script (from the repository root):

```bash
python examples/example_1_basic.py
```

To run the task CLI manually with the same resources (from the repository root):

```bash
task rc:examples/taskrc_example rc.data.location=examples/task_data <command>
```

Replace the relative paths with absolute paths (for example, $(pwd)/examples/taskrc_example) if you prefer.


```python
from taskwarrior import TaskWarrior, TaskInputDTO, Priority

# Initialize TaskWarrior (uses default ~/.taskrc)
tw = TaskWarrior()

# Create a simple task
task = TaskInputDTO(description="Buy groceries")
added_task = tw.add_task(task)
print(f"Created task #{added_task.index}: {added_task.uuid}")

# Create a task with more details
urgent_task = TaskInputDTO(
    description="Finish project report",
    priority=Priority.HIGH,
    proj
```