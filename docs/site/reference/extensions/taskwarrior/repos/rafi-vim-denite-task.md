# rafi/vim-denite-task

**URL:** https://github.com/rafi/vim-denite-task  
**Stars:** 2  
**Language:** Python  
**Last push:** 2017-05-15  
**Archived:** Yes  
**Topics:** denite, issue, neovim, task, taskwarrior, vim  

## Description

TaskWarrior source for Denite.  List, view, and preview tasks from Neo/Vim

## Category

Widgets & Editor Integrations

## Workwarrior Integration Rating

**Score:** 2  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: GitHub is ww's primary issue source
- +1: Python — tooling language used in ww

## README excerpt

```
# denite-taskwarrior

[TaskWarrior] Denite source for lists, view, and preview tasks.

## Features

- View task as a buffer
- Pretty lists with flexible formatting
- Preview integration

## Installation

Use your favorite plugin manager, mine is [dein.vim].

### Requirements

- Vim or Neovim
- [denite.nvim]
- Python 3.4 or later

## Usage

```viml
:Denite task
```

### Configuration

You can set the order option globally:

```viml
call denite#custom#var('task', 'taskrc', '~/.taskrc')
call denite#custom#var('task', 'data_dir', '~/.task')
call denite#custom#var('task', 'format', '{id:3.3} | {priority:1.1} | {project:15.15} | {description:40.40} | {entry} | {due}')
call denite#custom#var('task', 'date_format', '%y-%m-%d %H:%M')
call denite#custom#var('task', 'label_width', 17)
```

- Default values shown.

## Customize

Example of changing formatting:

```viml
call denite#custom#var('task', 'formats', {
  \     'format': '{id:3.3} | {priority:1.1} | {project:15.15} | {description}',
  \ })
```

Formatting applied via [str.format()], when using padding or truncating,
denite-task will transform your integers into percentage to leverage win-width.

## Credits & Contribution

- [robgolding/tasklib] - great light-weight API for TaskWarrior

Plugin maintained by Rafael Bodill.

Pull requests are welcome.

[TaskWarrior]: https://taskwarrior.org/
[robgolding/tasklib]: https://github.com/robgolding/tasklib
[str.format()]: https://docs.python.org/3/library/string.html#formatstrings
[denite.nvim]: https://github.com/Shougo/denite.nvim
[dein.vim]: https://github.com/Shougo/dein.vim

```