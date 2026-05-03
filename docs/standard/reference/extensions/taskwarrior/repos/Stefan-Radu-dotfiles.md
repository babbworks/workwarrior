# Stefan-Radu/dotfiles

**URL:** https://github.com/Stefan-Radu/dotfiles  
**Stars:** 3  
**Language:** Python  
**Last push:** 2026-02-25  
**Archived:** No  
**Topics:** allacritty, dotfiles, neovim, taskwarrior, tmux, vim, zsh  

## Description

hooray, here you'll find my dotfiles. they're cool I know

## Category

CLI Tools

## Workwarrior Integration Rating

**Score:** 3  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: Shell integration — ww is shell-first
- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source

## README excerpt

```
# Dotfiles

Hello kind stranger. This is a collection of config files (.dotfiles) for
software I use very often on my main computer. I hope you find something useful
here.

## Setup as git --bare repo instructions

This is inspired from [this guide](https://www.atlassian.com/git/tutorials/dotfiles).
I like to user the `.dotfiles` directory with the `dot` command.

### Setup <dot> as an alias for the git command

Add the following in your shell config `.bash.rc`, `zshrc`, or `config.fish`,
etc.

    alias dot="/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME"

### Clone and get your files


    git clone --bare https://github.com/Stefan-Radu/dotfiles $HOME/.dotfiles
    git checkout

An override warning might appear, but it's easily solved.

## Notes

I also save my `.gitconfig` file, so I don't have to do any additional git
settings, such as: custom log, templates, username, now showing untracked
files, etc.

```