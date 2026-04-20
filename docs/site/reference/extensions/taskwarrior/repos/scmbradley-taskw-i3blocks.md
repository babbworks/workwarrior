# scmbradley/taskw-i3blocks

**URL:** https://github.com/scmbradley/taskw-i3blocks  
**Stars:** 2  
**Language:** Python  
**Last push:** 2021-05-20  
**Archived:** No  
**Topics:** blocklets, i3blocks, taskwarrior  

## Description

A block for i3blocks that displays information about taskwarrior active tasks

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 9  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +3: Uses TimeWarrior — already integrated in ww
- +2: Hook-based — ww can install hooks per profile
- +2: Urgency coefficients are a ww UDA focus area
- +1: GitHub is ww's primary issue source
- +1: Python — tooling language used in ww

## README excerpt

```


# Taskwarrior active task blocklet

![GitHub tag (latest SemVer)](https://img.shields.io/github/v/tag/scmbradley/taskw-i3blocks)
![Maintenance](https://img.shields.io/maintenance/yes/2021)
[![Code style: black](https://img.shields.io/badge/code%20style-black-000000.svg)](https://github.com/psf/black)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

This is the readme for `taskw-i3blocks` v0.3.1.
This blocklet shows what task(s) you currently have active in TaskWarrior.
The blocklet will display the description of one of the active tasks
and an indication of how many other active tasks you have.

The script has been tested in python 3.6, 3.8 and 3.9 on ubuntu 20.10 with regolith,
and has no dependencies apart from a standard python install
and (obviously) at least one of [`taskwarrior`](https://taskwarrior.org/) and [`timewarrior`](https://timewarrior.net/).

A version of the script has been submitted to [`i3blocks-contrib`](https://github.com/vivien/i3blocks-contrib) 
but the most up to date version is available from [this repo](https://github.com/scmbradley/taskw-i3blocks).


## Config options

 - `TASKW_TF` : whether to display information about tasks (from taskwarrior). By default it displays the description of (one of) the active task(s).
 - `TIMEW_TF` : whether to display information about time durations (from timewarrior). Displays minutes and hours. We don't display seconds because the block only updates every 15 seconds, and we don't display longer stretches of time because if you spend more than 24 hours on a task, you aren't making your tasks small enough.
 - `TIMEW_DESC_OVERRIDE` : whether to pull task description information from taskwarrior (false) or timewarrior (true). Will also set `TIMEW_TF` to true if true.
 - `TASKW_MAX_LENGTH` : the number of characters to truncate long task descriptions at.
 - `TASKW_NOTASK_MSG` : the text to display if there are no active tasks.
 - `TASKW_SORT_URGENCY` : a boolean to determine whether to display the most urgent active task (or the default behaviour which is to display the task which has been active longest).
 - `TASKW_PENDING_TF` : a boolean to determine whether to display the total number of pending tasks
 - `TASKW_MAIN_FILTER` option allows you to select a filter to display. The default is `+ACTIVE`.
 

## Timewarrior integration

Integration between taskwarrior and timewarrior is via a taskwarrior hook that starts/stops timewarrior when you 
start/stop a task in taskwarrior.
What this means is that if you have multiple tasks ongoing, the current timew duration is for 
the *most recently started* task (and the time for the task started earlier will be stopped when a newer task is started).
So having multiple ongoing tasks doesn't really play nice with timewarrior.
To make sure the task description matches the task to which the timew duration refers,
we could do one of two things: 
optionally sort tasks by most recent start t
```