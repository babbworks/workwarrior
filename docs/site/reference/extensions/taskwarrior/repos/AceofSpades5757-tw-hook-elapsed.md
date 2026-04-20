# AceofSpades5757/tw-hook-elapsed

**URL:** https://github.com/AceofSpades5757/tw-hook-elapsed  
**Stars:** 1  
**Language:** Rust  
**Last push:** 2024-06-26  
**Archived:** No  
**Topics:** elapsed, hook, hooks, rust, task-management, taskwarrior, time-management  

## Description

Taskwarrior hook to add an `elapsed` UDA field, and to persist `start` field.

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 4  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +3: UDAs — core to ww service model
- +1: GitHub is ww's primary issue source
- -2: Mobile — outside ww scope

## README excerpt

```
# Description

_Adding existing time has been disabled._

Taskwarrior hooks to add the UDA elapsed on new tasks and modified tasks, anything with a start and end value. This is useful for tracking time spent on tasks.

It also helps preserve the start and end time of a task, which is removed by Taskwarrior when an end time is added.

This hook is **not** good for tracking time spent on tasks that you toggle on and off and will break any other hooks that are designed to do this.

This hook **is** good for tracking time spent on tasks that you explicilty start and finish and you'd like to keep that information. I use this to track my shifts at work.

~~Elapsed is calculated by `existing_time + (end_date - start_date)`.~~

Elapsed is calculated by `end_date - start_date`.

# Installation

_Note that there are a couple noop (no operation) hooks that are included as well. They'll be removed in due time._

Requires that the Rust toolchain be installed. If you need a release, create an issue and I'll start making releases.

## Using [`just`](https://github.com/casey/just)

_Need to have [`just`](https://github.com/casey/just) installed._

`just install`

This will put `on-add_elapsed` and `on-modify_elapsed` binaries in `~/.task/hooks`.

## Manually

1. Create installation binary in a local build directory: `cargo install --root ./build --path .`
1. Copy the binaries to your hooks directory (by default in `~/.task/hooks`): `cp ./build/bin/* ~/.task/hooks/`

# Scenarios

Adding/Logging a Task:

* If task has a start and end date: Add elapsed time
* If task is missing a start or end date: Do nothing

Modifying a Task:

* If task has a start and end date: Add elapsed time ~~to existing time~~
* If task is missing a start or end date: Do nothing

```