# guludo/taskwarrior-autotagger

**URL:** https://github.com/guludo/taskwarrior-autotagger  
**Stars:** 3  
**Language:** Python  
**Last push:** 2021-07-07  
**Archived:** No  
**Topics:** taskwarrior  

## Description

Taskwarrior hook for automatic tagging

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 5  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source
- +1: Python — tooling language used in ww

## README excerpt

```
# Taskwarrior Autotagger Hook

This project provides `on-add` and `on-modify`
[Taskwarrior](https://taskwarrior.org/) hooks for automatically adding tags to
tasks based on their tags or projects.


## Install

In order to install, simply checkout this repository somewhere in your file
system and create symbolic links to the hook scripts. For example:

```bash
git clone https://github.com/guludo/taskwarrior-autotagger.git
ln -s $(realpath taskwarrior-autotagger/on-*.taskwarrior-autotagger.py) ~/.task/hooks/
```

The hooks are `python3` scripts, so that is required to be installed in your
system.


## Usage

Create a configuration file named `autotagger.cfg` in your taskwarrior
directory (usually `~/.task`). This file follows the INI format. Each target
tag has its own section, which is named `tag.<target>`, where `<target>` is a
placeholder for the tag that will be automatically added to the task. Such a
section can define the following values:

- `tags`: space-separated list of tags that cause `<target>` to be added to the
  task. If the task contains any of the tags in this list, then the target tag
  is added to the task.

- `projects`: space-separated list of projects that cause `<target>` to be
  added to the task.

Example:

```ini
[tag.phd]
# Any of these tags cause the tag phd to be added to my task
tags = machinelearning calculus stats
```

```