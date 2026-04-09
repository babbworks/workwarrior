# jrcharney/taskwarrior-themes

**URL:** https://github.com/jrcharney/taskwarrior-themes  
**Stars:** 3  
**Language:** —  
**Last push:** 2024-05-14  
**Archived:** No  
**Topics:** archlinux, taskwarrior, themes  

## Description

Righting a wrong that the ArchLinux did not fix

## Category

Time Tracking

## Workwarrior Integration Rating

**Score:** 4  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +3: Uses TimeWarrior — already integrated in ww
- +1: GitHub is ww's primary issue source

## README excerpt

```
# taskwarrior-themes
Righting a wrong that the ~~GothenburgBitFactory~~ *Arch Linux* forgot to fix.

## About

Were you like me looking around for where @GothenburgBitFactory put the themes for Taskwarrior? Are you using an Arch-based Linux distro (e.g. Arch Linux or Manjaro)? Could you not find where the Task Warrior themes should be (e.g. `/usr/share/task/themes`, `/usr/share/taskwarrior/themes` or `~/.task/themes`)?

This repo exist to fix that problem.


## Installation

1. Clone this repo. (`git clone https://github.com/jrcharney/taskwarrior-themes`)
2. Copy or move the `themes` directory to the `~/.task` directory. (`cp -r themes ~/.task`)
3. Add `include ~/.task/themes/theme-name-file.theme` to your `~/.taskrc` file. The lines should be already there, you just need to uncomment one of theme.

You might also want to add `editor=nano` (or your favorite editor) and `color=on` down near the bottom of `~/.taskrc` just to be sure.


## What in here?

Included are the standard task warrior themes.

- dark-16.theme
- dark-256.theme
- dark-blue-256.theme
- dark-gray-256.theme
- dark-green-256.theme
- dark-red-256.theme
- dark-violets-256.theme
- dark-yellow-green.theme
- light-16.theme
- light-256.theme
- solarized-dark-256.theme
- solarized-light-256.theme

See the [Taskwarrior Themes](https://taskwarrior.org/docs/themes/) page to see what those look like.

Eventually, I'd like to add my own themes, or maybe an app or script that creates a theme from a color swatch.

## Why use this?

[I checked with the GBF](https://github.com/GothenburgBitFactory/taskwarrior/issues/3069), and it turned out that the party responsible for not including the themes were the folks at Arch Linux.  This should work with other distros and probably should work with Timewarrior too.

```