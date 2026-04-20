# kdheepak/taskwarrior-tui

**URL:** https://github.com/kdheepak/taskwarrior-tui  
**Stars:** 1982  
**Language:** Rust  
**Last push:** 2026-04-08  
**Archived:** No  
**Topics:** cli, rust, taskwarrior, tui, tui-rs  

## Description

`taskwarrior-tui`: A terminal user interface for taskwarrior

## Category

Sync

## Workwarrior Integration Rating

**Score:** 14  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +3: Uses TimeWarrior — already integrated in ww
- +2: Sync capability relevant to ww profile isolation
- +2: Urgency coefficients are a ww UDA focus area
- +3: UDAs — core to ww service model
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration

## README excerpt

```
# `taskwarrior-tui`

> [!IMPORTANT]
> [`taskwarrior` v3.x](https://github.com/GothenburgBitFactory/taskwarrior/releases/tag/v3.0.0) may break `taskwarrior-tui` features in unexpected ways. Please file a bug report if you encounter a bug.
>
> taskwarrior-tui [v0.25.4](https://github.com/kdheepak/taskwarrior-tui/releases/tag/v0.25.4) is the last version supporting taskwarrior v2.x as backend.

[![CI](https://github.com/kdheepak/taskwarrior-tui/workflows/CI/badge.svg)](https://github.com/kdheepak/taskwarrior-tui/actions?query=workflow%3ACI)
[![](https://img.shields.io/github/license/kdheepak/taskwarrior-tui)](https://github.com/kdheepak/taskwarrior-tui/blob/main/LICENSE)
[![](https://img.shields.io/github/v/release/kdheepak/taskwarrior-tui)](https://github.com/kdheepak/taskwarrior-tui/releases/latest)
[![](https://img.shields.io/static/v1?label=platform&message=linux-64%20|%20osx-64%20|%20win-32%20|%20win-64&color=lightgrey)](https://github.com/kdheepak/taskwarrior-tui/releases/latest)
[![](https://img.shields.io/github/languages/top/kdheepak/taskwarrior-tui)](https://github.com/kdheepak/taskwarrior-tui)
[![](https://img.shields.io/coveralls/github/kdheepak/taskwarrior-tui)](https://coveralls.io/github/kdheepak/taskwarrior-tui)
[![](https://img.shields.io/badge/taskwarrior--tui-docs-red)](https://kdheepak.com/taskwarrior-tui)
[![](https://img.shields.io/github/downloads/kdheepak/taskwarrior-tui/total)](https://github.com/kdheepak/taskwarrior-tui/releases/latest)

A Terminal User Interface (TUI) for [Taskwarrior](https://taskwarrior.org/) that you didn't know you wanted.

### Features

- vim-like navigation
- live filter updates
- add, delete, complete, log tasks
- multiple selection
- tab completion
- colors based on taskwarrior

![](https://user-images.githubusercontent.com/1813121/159858280-3ca31e9a-fc38-4547-a92d-36a7758cf5dc.gif)

### Showcase

<details>
<summary><b>Demo</b>: (video)</summary>
<a href="https://www.youtube.com/watch?v=0ZdkfNrIAcw"><img src="https://img.youtube.com/vi/0ZdkfNrIAcw/0.jpg" /></a>
</details>

<details>
  <summary><b>User Interface</b>: (gif)</summary>
  <img src="https://user-images.githubusercontent.com/1813121/113251568-bdef2380-927f-11eb-8cb6-5d95b00eee53.gif"></img>
</details>

<details>
  <summary><b>Multiple selection</b>: (gif)</summary>
  <img src="https://user-images.githubusercontent.com/1813121/113252636-4e7a3380-9281-11eb-821d-874c86d11105.gif"></img>
</details>

<details>
  <summary><b>Tab completion</b>: (gif)</summary>
  <img src="https://user-images.githubusercontent.com/1813121/113711977-cfcb2f00-96a2-11eb-8b06-9fd17903561d.gif"></img>
  <img src="https://user-images.githubusercontent.com/1813121/152730495-f0abd6b9-d710-44e6-a7f9-c15a68cc8233.png"></img>
  <img src="https://user-images.githubusercontent.com/1813121/152730497-44ce00d1-3a7c-4658-80d1-4df8d161cab8.png"></img>
  <img src="https://user-images.githubusercontent.com/1813121/152730498-cd75efed-d2c0-48e6-b82f-594e0a2a5dff.png"></img>
  <img sr
```