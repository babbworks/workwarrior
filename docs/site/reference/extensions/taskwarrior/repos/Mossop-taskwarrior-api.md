# Mossop/taskwarrior-api

**URL:** https://github.com/Mossop/taskwarrior-api  
**Stars:** 3  
**Language:** TypeScript  
**Last push:** 2023-01-09  
**Archived:** No  
**Topics:** api, taskwarrior, typescript  

## Description

A typesafe asynchronous API for accessing taskwarrior.

## Category

Sync

## Workwarrior Integration Rating

**Score:** 6  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +3: UDAs — core to ww service model
- +1: GitHub is ww's primary issue source

## README excerpt

```

# taskwarrior-api

[![Commit checks](https://github.com/Mossop/taskwarrior-api/workflows/Commit%20checks/badge.svg)](https://github.com/Mossop/taskwarrior-api/actions?query=workflow%3A%22Commit+checks%22)
[![codecov](https://codecov.io/gh/Mossop/taskwarrior-api/branch/master/graph/badge.svg)](https://codecov.io/gh/Mossop/taskwarrior-api)

An asynchronous API for interracting with [Taskwarrior](https://taskwarrior.org/).

Planned features include:

* Asynchronous using promises.
* Type-safe using TypeScript.
* Full support for UDAs.
* Hides most of the low-level bits of Taskwarrior from you.
* A good suite of automated tests.

## Alternatives

Why not use the existing [taskwarrior](https://www.npmjs.com/package/taskwarrior) module?

It was last updated four years ago so I didn't have a lot of confidence that it would be still
working. Also the github repository hosting it seems to have been deleted.

Why not use [taskwarrior-lib](https://www.npmjs.com/package/taskwarrior-lib)

It's a nice looking library however its API is synchronous and pretty low-level. By all means use it
if that is what you're looking for.


```