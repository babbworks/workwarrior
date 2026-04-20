# Zebradil/powerline-taskwarrior

**URL:** https://github.com/Zebradil/powerline-taskwarrior  
**Stars:** 74  
**Language:** Python  
**Last push:** 2026-03-30  
**Archived:** No  
**Topics:** powerline, powerline-segment, powerline-taskwarrior, taskwarrior, taskwarrior-segment  

## Description

䷡→䷆ A Powerline segment for displaying information from Taskwarrior task manager

## Category

CLI Tools

## Workwarrior Integration Rating

**Score:** 3  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: Shell integration — ww is shell-first
- +1: GitHub is ww's primary issue source
- +1: Python — tooling language used in ww

## README excerpt

```
# Powerline Taskwarrior

![CI](https://github.com/zebradil/powerline-taskwarrior/actions/workflows/ci.yml/badge.svg)
[![PyPI](https://img.shields.io/pypi/v/powerline-taskwarrior.svg)](https://pypi.python.org/pypi/powerline-taskwarrior)
[![PyPI](https://img.shields.io/pypi/l/powerline-taskwarrior.svg)](https://opensource.org/licenses/MIT)

A set of [Powerline][1] segments for showing information retrieved from [Taskwarrior][2] task manager.

It shows a current context and the most urgent active task.

![screenshot][4]

## Requirements

Taskwarrior segments require:
- [task][2] v2.4.2 or later,
- Python `^3.7` (support for Python 2.7 was dropped)

## Installation

### AUR

```sh
yay -S python-powerline-taskwarrior
```

### PIP

```sh
pip install --user -U powerline-taskwarrior
```

It can also be installed system-wide, but this is usually a bad idea.

### Debian

On Debian (testing or unstable), installation can be performed with apt:

```sh
apt install python-powerline-taskwarrior
```

## Usage

### Activate segments

To activate Taskwarrior segments add them to your segment configuration.
See more about powerline configuration in [the official documentation][7].
For example, I store powerline configuration in
`~/.config/powerline/themes/shell/default.json`.

These are available powerline-taskwarrior segments:

- display current context name
  ```json
  {
      "function": "powerline_taskwarrior.context",
      "priority": 70
  }
  ```

- display the count of pending tasks
  ```json
  {
      "function": "powerline_taskwarrior.pending_tasks_count",
      "priority": 70
  }
  ```

- display the most urgent active task
  ```json
  {
      "function": "powerline_taskwarrior.active_task",
      "priority": 70
  }
  ```

- display the most urgent next task
  ```json
  {
      "function": "powerline_taskwarrior.next_task",
      "priority": 70
  }
  ```

- *obsolete* segment displays both of listed above
  ```json
  {
      "function": "powerline_taskwarrior.taskwarrior",
      "priority": 70
  }
  ```

### Color scheme

Taskwarrior-powerline requires custom colorscheme to be configured.
Add the following to your colorschemes (`.config/powerline/colorschemes/default.json`):

```json
{
  "groups": {
    "taskwarrior:context": "information:regular",
    "taskwarrior:pending_tasks_count": "information:priority",
    "taskwarrior:active_id": { "bg": "mediumgreen", "fg": "black", "attrs": [] },
    "taskwarrior:active_desc": { "bg": "green", "fg": "black", "attrs": [] },
    "taskwarrior:next_id": { "bg": "brightyellow", "fg": "black", "attrs": [] },
    "taskwarrior:next_desc": { "bg": "yellow", "fg": "black", "attrs": [] }
  }
}

```

And here you can configure the colors.

See [powerline colorschemes docs][6] for more details.

### Further customization

If you have a custom name for `task` command, it should be specified via `task_alias` argument in the segment configuration.

`powerline_taskwarrior.active_task` and `powerline_taskwarrior.next_task` segm
```