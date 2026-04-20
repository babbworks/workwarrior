# arzano/taskmonad

**URL:** https://github.com/arzano/taskmonad  
**Stars:** 5  
**Language:** Haskell  
**Last push:** 2019-03-30  
**Archived:** No  
**Topics:** gtd, taskwarrior, todo, xmonad  

## Description

TaskMonad: xmonad + taskwarrior

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 7  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +1: Shell integration — ww is shell-first
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration

## README excerpt

```
<p align="center"><img width=17.5% src="https://raw.githubusercontent.com/mmagorsc/taskmonad/master/docs/images/taskmonad_raw.png"></p>
<p align="center"><img width=60% src="https://raw.githubusercontent.com/mmagorsc/taskmonad/master/docs/images/taskmonad_label.png"></p>

<p align="center">
<a href="https://www.haskell.org/ghc/" ><img src="https://img.shields.io/badge/ghc-8.4.1%2B-blue.svg"></a>
<a href="https://travis-ci.org/mmagorsc/taskmonad"> <img src="https://api.travis-ci.org/mmagorsc/taskmonad.svg?branch=master"></a>
<a href="http://hackage.haskell.org/package/TaskMonad-1.0.1"> <img src="https://img.shields.io/badge/hackage-1.0.1-brightgreen.svg"></a>
<a href="https://codeclimate.com/github/mmagorsc/taskmonad"> <img src="https://api.codeclimate.com/v1/badges/e4de6996bf5bb710d0e7/maintainability"></a>
<a href="#contributing"> <img src="https://img.shields.io/badge/contributions-welcome-orange.svg"></a>
<a href="https://opensource.org/licenses/BSD-3-Clause"><img src="https://img.shields.io/badge/license-BSD-blue.svg"></a>
</p>

## Table Of Contents 

- [Basic Overview](#basic-overview)
- [Installation](#installation)
- [Usage](#usage)
- [Features](#features)
- [Documentation](#documentation)
- [Contributing](#contributing)

## Basic Overview

Basically, TaskMonad provides a collection of tools which can be used to access taskwarrior from xmonad.

[![Screencast](https://raw.githubusercontent.com/mmagorsc/taskmonad/master/docs/images/taskmonad-screencast.gif)](https://taskmonad.magorsch.de)

## Installation

### Using cabal

To install TaskMonad from hackage just execute:

``` shell
$ cabal update
$ cabal install TaskMonad
```

Afterwards import TaskMonad in your `xmonad.hs`  

``` haskell
import TaskMonad
```

### Without cabal

To install Taskmonad without using cabal just download and copy the source code into your `~/.xmonad/lib/` folder. The folder structure should afterwards look like this:

``` shell
.xmonad 
|-- lib
|   |-- Taskmonad.hs
|   |-- Taskmonad
|   |   |-- GridSelect.hs
|   |   |-- Prompt.hs
|   |   |-- ScratchPad.hs
|   |   `-- Utils.hs
|   |-- GridSelect
|   |   `-- Extras.hs
|   `-- ...
|-- xmonad.hs
```

Afterwards import TaskMonad in your `xmonad.hs`  

``` haskell
import TaskMonad
```


## Usage
To get started, add a manage hook for the taskwarrior scratchpad:

``` haskell
-- ...

... , manageHook = namedScratchpadManageHook taskwarriorScratchpads
```

After that you can bind the taskwarrior prompt to a key to get started: 

``` haskell
... , ("M-p",     taskwarriorPrompt [(\x -> x == "processInbox", processInbox)])
```

You can also bind any other TaskMonad action to a key. For example:

``` haskell
... , ("M-S-p",   taskwarriorScratchpad)       -- Opens the taskwarrior scratchpad

... , ("M-C-p",   taskSelect "status:pending") -- Displays all pending tasks

... , ("M-C-S-p", tagSelect)                   -- Displays all tags using a gridselect
```

In general you can customize the tools ad libitum. A good way to get st
```