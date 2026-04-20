# soywod/kronos.vim

**URL:** https://github.com/soywod/kronos.vim  
**Stars:** 199  
**Language:** Vim script  
**Last push:** 2019-11-11  
**Archived:** Yes  
**Topics:** datetime, python3, task-manager, taskwarrior, time-manager, vim, vim-plugin, worktime  

## Description

A simple task and time manager. Project moved here:

## Category

Sync

## Workwarrior Integration Rating

**Score:** 8  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +3: Uses TimeWarrior — already integrated in ww
- +2: Sync capability relevant to ww profile isolation
- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration
- +1: Python — tooling language used in ww
- -2: Dormant project

## README excerpt

```
⚠️ *Project archived. Have a look at [unfog](https://github.com/unfog-io/unfog-vim), its successor.*

# Kronos.vim [![Build Status](https://travis-ci.org/soywod/kronos.vim.svg?branch=master)](https://travis-ci.org/soywod/kronos.vim)

A simple task and time manager.

<p align="center">
  <img src="https://user-images.githubusercontent.com/10437171/50441115-77205f80-08f9-11e9-97d4-b7b64741d8f2.png"></img>
</p>

## Table of contents

  * [Requirements](#requirements)
  * [Usage](#usage)
    * [Create](#create)
    * [Read](#read)
    * [Update](#update)
    * [Start/stop](#startstop)
    * [Done](#done)
    * [Hide done tasks](#hide-done-tasks)
    * [Context](#context)
    * [Sort](#sort)
    * [Worktime](#worktime)
    * [Delete](#delete)
  * [Backend](#backend)
  * [Import](#import)
  * [Mappings](#mappings)
  * [Contributing](#contributing)
  * [Changelog](#changelog)
  * [Credits](#credits)

## Requirements

  - VIM v8+ or NVIM v0.3.4+ (not tested on lower versions)
  - Python v3.3+ (check it with `:echo has('python3')` and `:!python3 --version`)

## Usage

```vim
:Kronos
```

Then you can create, read, update, delete tasks using Vim mapping. The table
will automatically readjust when you save the buffer (`:w`).

### Create

To create a task, you can:

- Write or copy a full table line: `|id|desc|tags|active|due|`
- Follow the Kronos format: `<desc> <tags> <due>`

![Create
task](https://user-images.githubusercontent.com/10437171/50438709-61a63800-08ef-11e9-8f49-aa02b6da7f3b.gif)

A tag should start by a `+`. You can add as many tags as you need.

A due should start by a `:`. There is 3 kinds of due:

  - The absolute due: `:DDMMYY:HHMM`, which correspond to a specific date.
  - The approximative due, which is a partial absolute, for eg. `:DD`,
    `::HH`, `:DDM:M`. Kronos will try to find the closest date matching this
    due.
  - The relative due, which is relative to the actual date. For eg. `:1y`,
    `:2mo`, `:4h`. Available units: `y, mo, w, d, h, m`.<br /> *Note: unit
    order should be respected, from the biggest to the smallest.  `2y4mo24m` is
    valid, `3m4d` is not.*

Here some use cases:

| Actual date | Given pattern | Due |
| --- | --- | --- |
| 03/03/2019 21:42 | `:4` | 04/03/2019 00:00 |
| 03/03/2019 21:42 | `:2` | 02/04/2019 00:00 |
| 03/03/2019 21:42 | `:0304` or `:034` | 03/04/2019 00:00 |
| 03/03/2019 21:42 | `:3004` or `304` | 30/04/2019 00:00 |
| 03/03/2019 21:42 | `:0202` | 02/02/2020 00:00 |
| 03/03/2019 21:42 | `:020221` | 02/02/2021 00:00 |
| 03/03/2019 21:42 | `::22` | 03/03/2019 22:00 |
| 03/03/2019 21:42 | `::19` | 04/03/2019 19:00 |
| 03/03/2019 21:42 | `:4:2150` | 04/03/2019 21:50 |
| 03/03/2019 21:42 | `:2d` | 05/03/2019 21:42 |
| 03/03/2019 21:42 | `:1w10m` | 10/03/2019 21:52 |
| 03/03/2019 21:42 | `:1y13mo1h` | 03/04/2021 22:42 |

*Note: the date format is DD/MM/YYYY HH:MM*

### Read

To show focused task details, press `<K>`:

![Read
task](https://user-images.githubusercontent.com/10437171/50438871-2f490a80-
```