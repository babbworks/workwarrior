# Zebradil/taskwarrior-hooks

**URL:** https://github.com/Zebradil/taskwarrior-hooks  
**Stars:** 5  
**Language:** Python  
**Last push:** 2020-05-10  
**Archived:** No  
**Topics:** taskwarrior  

## Description

My personal hook collection for the Taskwarrior task manager hero.

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 2  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile

## README excerpt

```
# Taskwarrior-hooks-collection

My personal hook collection for the Taskwarrior task manager hero.

## Hooks list

|Title|Triggers|Result|
|-----|--------|------|
|__buy_wait__|add, modify|If project is `Buy` or its subproject, then places task in waiting list (sets `wait:someday`)
|__remove_next__|start, done|Removes task from waiting list (removes `wait:someday`) and removes `next` tag
|__commit__|exit|Commits all changes in the `.task` directory if it's a git repository|

## Misc

`taskupd.sh` contains function for updating `.task` repository.

```