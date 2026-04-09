# huantrinh1802/taskwarrior_flow

**URL:** https://github.com/huantrinh1802/taskwarrior_flow  
**Stars:** 6  
**Language:** Python  
**Last push:** 2024-09-26  
**Archived:** No  
**Topics:** cli-tools, python, taskwarrior  

## Description

CLI to improve Taskwarrior workflow

## Category

TUI / Interactive

## Workwarrior Integration Rating

**Score:** 3  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: Shell integration — ww is shell-first
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos

## README excerpt

```
# Taskwarrior Flow (TWF)

Taskwarrior Flow (TWF) is a plugin designed to enhance your Taskwarrior workflow by providing a set of utilities accessible via the command-line interface (CLI). Whether you're managing tasks, creating queries, or working with templates, TWF aims to streamline your Taskwarrior experience.

## Installation

### Using pipx

```shell
pipx install taskwarrior_flow
```

## Usage

Please see the [USAGE.md](./USAGE.md) for more information

## Features

### Query

Allow users to save common queries that can be used to search tasks easily.
For example, `project:Work +scopeA +scopeB due:today+2days`

### Task template

Allow users to save templates that can be used to create tasks easily

### Multiple task groups

Instead of having one task database (i.e. $HOME/.task/), using `twf [GROUP] [Taskwarrior commands]` will allow users to use different task databases (i.e. $HOME/.task_[GROUP])

### Natural date parsing

Users can specify dates in natural language, such as "tomorrow", "next week", "last year", etc.

- In the template, users can define fields to be date, this enables natural date parsing
- In task group, users can use a special syntax to specify dates, such as `due:@tomorrow at 2pm@`

## Related tools

- This CLI is a complementary tool for [taskwarrior](https://taskwarrior.org)
- This CLI is designed to work well with my [taskwarrior Neovim Plugin](https://github.com/huantrinh1802/m_taskwarrior_d.nvim)

```