# GothenburgBitFactory/taskchampion

**URL:** https://github.com/GothenburgBitFactory/taskchampion  
**Stars:** 150  
**Language:** Rust  
**Last push:** 2026-04-05  
**Archived:** No  
**Topics:** rust, task-tracking, taskwarrior  

## Description

Personal task-tracking library

## Category

Sync

## Workwarrior Integration Rating

**Score:** 2  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation

## README excerpt

```
TaskChampion
------------

TaskChampion implements the task storage and synchronization behind Taskwarrior.
It includes an implementation with Rust and C APIs, allowing any application to maintain and manipulate its own replica.
It also includes a specification for tasks and how they are synchronized, inviting alternative implementations of replicas or task servers.

See the [documentation](https://gothenburgbitfactory.org/taskchampion/) for more!

## Structure

There are two crates here:

 * `taskchampion` (root of the repository) - the core of the tool
 * [`xtask`](./xtask) (private) - implementation of the `cargo xtask msrv` command

## Rust API

The Rust API, as defined in [the docs](https://docs.rs/taskchampion/latest/taskchampion/), supports simple creation and manipulation of replicas and the tasks they contain.

The Rust API follows semantic versioning.

```