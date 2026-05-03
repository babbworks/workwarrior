# ftapajos/scheduler

**URL:** https://github.com/ftapajos/scheduler  
**Stars:** 6  
**Language:** Python  
**Last push:** 2026-03-06  
**Archived:** No  
**Topics:** taskwarrior, timewarrior  

## Description

 Uses data from taskwarrior and timewarrior to indicate which task should be done next 

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 10  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +3: Uses TimeWarrior — already integrated in ww
- +2: Hook-based — ww can install hooks per profile
- +2: Urgency coefficients are a ww UDA focus area
- +1: Shell integration — ww is shell-first
- +1: Import/export useful for profile migration
- +1: Python — tooling language used in ww

## README excerpt

```
# TL;DR

Uses data from [taskwarrior](https://taskwarrior.org/) and [timewarrior](https://timewarrior.net/) to indicate which task should be done next considering both its urgency and the time already spent on it. Its logic is inspired on the [Linux CFS scheduler](https://docs.kernel.org/scheduler/sched-design-CFS.html).

# Installation

## Dependencies

The following dependencies are not python dependencies and must be installed through your system's package manager

* [Taskwarrior](https://taskwarrior.org/)
* [Timewarrior](https://timewarrior.net/)
* [Hook for linking Taskwarrior to Timewarrior](https://timewarrior.net/docs/taskwarrior/)

## Install with pip

It is possible to install via pip by:

```
pip install taskwarrior-scheduler
```

# How to use it

1. Run ``next`` to know on what task you should focus next
2. Log the task you are doing to timewarrior (preferably via a [taskwarrior hook](https://timewarrior.net/docs/taskwarrior/))
3. When you feel you are not performing as you should, or when you feel reached an important milestone, or when the task is too dull to be handled, hit ``next`` and check if there is another task you could focus on.
4. Stop the time tracking whenever you stop working

## Hints 

1. Do not change tasks when you feel you are being productive, even if the task you are working on isn't the most urgent;
2. Learn to do "partial breaks" by [filtering tasks] (https://taskwarrior.org/docs/filter/) (yes, I am talking about the ``-work`` during office hours). The script will know how to balance back when you stop this partial break;
2. Define clear criteria for when you should be working on tasks and when you should be taking breaks or partial breaks;
3. Learn to distinguish between the times when you need a little push to get things done, when you need a partial break, when you need a full break and when you need to sleep.

# How does it work

## Introduction

Taskwarrior is meant to be used to organize tasks according to their urgencies, so that the user can dedicate always to complete the most urgent task. However, sometimes the most urgent task is too complex and takes a lot of time and effort to be completed.

The [best practices](https://taskwarrior.org/docs/best-practices/) state that, in this case, a complex task should be broken into smaller units of work, so that the user has the opportunity to plan ahead. This is a sensible advice, but users are humans. And humans are not always in the best state of mind to realize they are getting stuck in a task that should be better planned, specially if they are too focused on getting it done as soon as possible.

My story in that matter started by the second half of 2024, when I had to get my master thesis done in (what seemed to me was) a very short time. I was stuck in a chapter and no matter the strategy, I was simply stuck. I tried breaking into smaller tasks but it didn't work because I got stuck into every related task, no regardless how small it was. Pomodoro timer 
```