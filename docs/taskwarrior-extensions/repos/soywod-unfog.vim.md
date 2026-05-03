# soywod/unfog.vim

**URL:** https://github.com/soywod/unfog.vim  
**Stars:** 72  
**Language:** Vim Script  
**Last push:** 2022-10-10  
**Archived:** No  
**Topics:** haskell, task-manager, taskwarrior, time-tracker, vim, vim-plugin, viml, vimscript, worktime  

## Description

⏱ Vim plugin for Unfog CLI task & time manager.

## Category

Reports & Visualisation

## Workwarrior Integration Rating

**Score:** 6  
**Rating:** ★★★★☆  High  

### Scoring notes

- +3: Uses TimeWarrior — already integrated in ww
- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos

## README excerpt

```
# ⏱ Unfog.vim

Vim plugin for [Unfog](https://github.com/soywod/unfog) CLI task & time manager.

![image](https://user-images.githubusercontent.com/10437171/89771094-1199da80-db00-11ea-8e65-12da9ec4161a.png)

## Table of contents

  * [Installation](#installation)
  * [Usage](#usage)
    * [Add](#add)
    * [Info](#info)
    * [Edit](#edit)
    * [Toggle](#toggle)
    * [Done](#done)
    * [Context](#context)
    * [Worktime](#worktime)
  * [Mappings](#mappings)
  * [Contributing](#contributing)
  * [Changelog](https://github.com/soywod/unfog.vim/blob/master/CHANGELOG.md#changelog)
  * [Credits](#credits)

## Installation

First you need to install the [unfog
CLI](https://github.com/soywod/unfog#installation):

```bash
curl -sSL https://raw.githubusercontent.com/soywod/unfog/master/install.sh | sh
```

Then you can install this plugin with your favorite plugin manager. For eg:
with [vim-plug](https://github.com/junegunn/vim-plug), add to your `.vimrc`:

```viml
Plug "soywod/unfog.vim"
```

Then:

```viml
:PlugInstall
```

## Usage

It is recommanded to first read [the Unfog CLI
documentation](https://github.com/soywod/unfog#usage) to understand the
concept.

To list tasks:

```viml
:Unfog
```

Then you can manage tasks using Vim mapping. The table will automatically
readjust on buffer save (`:w`). Also have a look at the [mappings](#mappings)
section for special actions.

### Add

![gif](https://user-images.githubusercontent.com/10437171/90293908-7a2ce280-de85-11ea-9bc6-ee4440f17abd.gif)

### Info

Default mapping: [`K`](#mappings) (Shift-k).

![gif](https://user-images.githubusercontent.com/10437171/90294136-0212ec80-de86-11ea-9621-041eb7586ff8.gif)

### Edit

![gif](https://user-images.githubusercontent.com/10437171/90294280-58802b00-de86-11ea-8b43-7829d1ec334d.gif)

### Toggle

Default mapping: [`<CR>`](#mappings) (Enter).

![gif](https://user-images.githubusercontent.com/10437171/90294511-e8be7000-de86-11ea-8d45-da0810474074.gif)

### Done

![gif](https://user-images.githubusercontent.com/10437171/90294634-2de2a200-de87-11ea-8efe-462c9c6e39bf.gif)

### Context

Default mapping: [`gc`](#mappings) (Go to Context).

![gif](https://user-images.githubusercontent.com/10437171/90294906-e14b9680-de87-11ea-8de3-46848a99763c.gif)

### Worktime

Default mapping: [`gw`](#mappings) (Go to Worktime).

![gif](https://user-images.githubusercontent.com/10437171/90295164-81092480-de88-11ea-88b6-d4cf990cc6e7.gif)

## Mappings

Here the default mappings:

| Function | Mapping |
| --- | --- |
| List done tasks | `gd` |
| List deleted tasks | `gD` |
| [Toggle task](#toggle) | `<CR>` |
| [Show task infos](#show) | `K` |
| [Set context](#context) | `gc` |
| [Show worktime](#worktime) | `gw` |
| Jump to the next cell | `<C-n>` |
| Jump to the prev cell | `<C-p>` |
| Delete in cell | `dic` |
| Change in cell | `cic` |
| Visual in cell | `vic` |

You can customize them:

```vim
nmap gd     <plug>(unfog-list-done)
nmap gD     <plug>(unfog-list-deleted)
nmap <cr>   <plug
```