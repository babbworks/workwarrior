# LikiPiki/taskwarriorExtension

**URL:** https://github.com/LikiPiki/taskwarriorExtension  
**Stars:** 2  
**Language:** Go  
**Last push:** 2021-05-11  
**Archived:** No  
**Topics:** extension, golang, taskwarrior  

## Description

Taskwarrior commands extension. Split tasks, create tasks faster, show tasks like a tree. Easy to use, incredibly fast!

## Category

API Libraries

## Workwarrior Integration Rating

**Score:** 1  
**Rating:** ★★☆☆☆  Low  

### Scoring notes

- +1: GitHub is ww's primary issue source

## README excerpt

```
# Taskwarrior Extension
![build](https://github.com/likipiki/taskwarriorExtension/actions/workflows/build.yaml/badge.svg)

Taskwarrior commands extension. See [WIKI](https://github.com/LikiPiki/taskwarriorExtension/wiki) for more details!

## Features
- fast, written on golang language 
- simple customizable and extensible
- zero configuration
- colorfull output

## Installation
If you have got Golang installed on your machine, use this command. Else, see instructions in [Documentation](https://github.com/LikiPiki/taskwarriorExtension/wiki/Development#building)

```
go install github.com/likipiki/taskwarriorExtension ./cmd/tj
```

## Avaliable commands
- `tj tree [project-name]` -- show project and subprojects tasks like tree
- `tj ctx [context]` -- Setting up context
- `tj add [task]` -- Add new task with context
- `tj sp [task-number] [new-task]` -- Split task to smaller ones

[Read more about commands](https://github.com/LikiPiki/taskwarriorExtension/wiki#commands)

## Development
Branching model, plugin creation and others your can find in the [Development](https://github.com/LikiPiki/taskwarriorExtension/wiki/Development) page.

## References
- [TaskWarrior](https://taskwarrior.org)
- [go-taskwarrior library](https://github.com/jubnzv/go-taskwarrior)

```