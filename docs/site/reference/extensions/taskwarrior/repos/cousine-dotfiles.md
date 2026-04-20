# cousine/dotfiles

**URL:** https://github.com/cousine/dotfiles  
**Stars:** 0  
**Language:** Shell  
**Last push:** 2026-03-03  
**Archived:** No  
**Topics:** neovim, oh-my-zsh, taskwarrior, tmux, tmux-powerline, zsh  

## Description

Dotfiles for NeoVim, Tmux, Zsh, and TaskWarrior

## Category

Reports & Visualisation

## Workwarrior Integration Rating

**Score:** 3  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: Shell scripting — matches ww stack
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source

## README excerpt

```
# Cousine's dotfiles

## Screenshots

![ZSH & Tmux](screenshots/zsh-tmux.png)
![NeoVim](screenshots/neovim.png)

## Configurations includes

* NeoVim (Vim should work too)
* BashIt custom scripts (Although I'm no longer using bash)
* Oh my zsh custom scripts
* Tmux
* [TaskWarrior](https://taskwarrior.org/)

## Installation

A zsh script for installation is available (for bash you'll have to do it manually).

```
$ install.zsh
```

NOTE: THIS MAY MESS UP YOUR SETUP, BE SURE YOU UNDERSTAND WHAT YOU ARE INSTALLING
BEFORE RUNNING THIS SCRIPT!

## VIM Cheat Sheet

A VIM cheat sheet is available [here]( ./vim_cheat_sheet.md )

## Message Of The Day (MOTD)

The motd script will automatically check for a `motd` text file in your home dir,
if found, it will `cat` this file and then check for a `.motd.zsh` script in `~`
and run it.

The motd run automatically only on the first pane in tmux, but you can call it
anytime using the `motd` alias.

In the screenshot above I'm using [wego](https://github.com/schachmat/wego) for
the weather report, and [TaskWarrior](https://taskwarrior.org/) for my pending
tasks.

```