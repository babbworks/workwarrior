# tbabej/taskwiki

**URL:** https://github.com/tbabej/taskwiki  
**Stars:** 912  
**Language:** Python  
**Last push:** 2025-06-14  
**Archived:** No  
**Topics:** plugin, python, taskwarrior, todolist, vim  

## Description

Proper project management with Taskwarrior in vim.

## Category

Sync

## Workwarrior Integration Rating

**Score:** 10  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +2: Sync capability relevant to ww profile isolation
- +2: Urgency coefficients are a ww UDA focus area
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: Import/export useful for profile migration
- +1: Python — tooling language used in ww

## README excerpt

```
## Taskwiki

_Proper project management in vim.
Standing on the shoulders of vimwiki and Taskwarrior_

[![GitHub Actions build status](https://github.com/tools-life/taskwiki/workflows/tests/badge.svg?branch=master)](https://github.com/tools-life/taskwiki/actions)
[![Coverage Status](https://coveralls.io/repos/tools-life/taskwiki/badge.svg?branch=master)](https://coveralls.io/r/tools-life/taskwiki?branch=master)
[![Code Health](https://landscape.io/github/tbabej/taskwiki/master/landscape.svg?style=flat)](https://landscape.io/github/tbabej/taskwiki/master)
[![Chat with developers](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/tbabej/taskwiki)
```
                   _____         _   __        ___ _    _
        a         |_   _|_ _ ___| | _\ \      / (_) | _(_)         a
   command-line     | |/ _` / __| |/ /\ \ /\ / /| | |/ / |   personal wiki
    todo list       | | (_| \__ \   <  \ V  V / | |   <| |      for vim
     manager        |_|\__,_|___/_|\_\  \_/\_/  |_|_|\_\_|
```
### Installation

#### Make sure you satisfy the requirements

* Vim 7.4 or newer, with +python or +python3 (NeoVim is also supported)
* [Vimwiki](https://github.com/vimwiki/vimwiki/tree/dev) (the dev branch)

        git clone https://github.com/vimwiki/vimwiki ~/.vim/bundle/ --branch dev

* [Taskwarrior](http://taskwarrior.org) (version 2.4.0 or newer),
install either from [sources](http://taskwarrior.org/download/)
or using your [package manager](http://taskwarrior.org/download/#dist)

        sudo dnf install task

* [tasklib](https://github.com/GothenburgBitFactory/tasklib/) (version 2.4.3 or newer),
Python library for Taskwarrior.

        sudo pip3 install tasklib

* **For neovim users:** Note that `pynvim` is a required python 3 provider in case you are using neovim

        sudo pip3 install pynvim

#### Python2 support

Taskwiki is slowly deprecating Python 2 support. Future features are no longer
developed with Python2 compatibility in mind.

#### Install taskwiki

Using pathogen (or similar vim plugin manager), the taskwiki install is
as simple as:

    git clone https://github.com/tools-life/taskwiki ~/.vim/bundle/taskwiki

However, make sure your box satisfies the requirements stated above.

To access documentation, run :helptags taskwiki and then :help taskwiki.

#### Optional enhancements

The following optional plugins enhance and integrate with TaskWiki.
At very least,I'd recommend the AnsiEsc plugin - Taskwarrior
charts are much more fun when they're colorful!

* [vim-plugin-AnsiEsc](https://github.com/powerman/vim-plugin-AnsiEsc)
adds color support in charts.

        git clone https://github.com/powerman/vim-plugin-AnsiEsc ~/.vim/bundle/

* [tagbar](https://github.com/majutsushi/tagbar)
provides taskwiki file navigation.

        git clone https://github.com/majutsushi/tagbar ~/.vim/bundle/

* [vim-taskwarrior](https://github.com/farseer90718/vim-taskwarrior)
enables grid view.

        git clone https://github.com/farseer90718/vim-taskwarr
```