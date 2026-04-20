# LanHikari22/TTM

**URL:** https://github.com/LanHikari22/TTM  
**Stars:** 4  
**Language:** Python  
**Last push:** 2025-06-14  
**Archived:** No  
**Topics:** docker, notes, schedule, task, taskwarrior, time, todo  

## Description

Docker-based time/task/notes environment to be used over the CLI anywhere

## Category

Sync

## Workwarrior Integration Rating

**Score:** 6  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +1: Shell scripting — matches ww stack
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos

## README excerpt

```
<div align="center">
  <pre>
  ████████╗████████╗███╗░░░███╗
  ╚══██╔══╝╚══██╔══╝████╗░████║
  ░░░██║░░░░░░██║░░░██╔████╔██║
  ░░░██║░░░░░░██║░░░██║╚██╔╝██║
  ░░░██║░░░░░░██║░░░██║░╚═╝░██║
  ░░░╚═╝░░░░░░╚═╝░░░╚═╝░░░░░╚═╝
  </pre>
  <p>An integrated environment for time and task management over docker</p>
</div>

<!-- <p align="center">

  <a href="https://github.com/sponsors/jeffreytse">
    <img src="https://img.shields.io/static/v1?label=sponsor&message=%E2%9D%A4&logo=GitHub&link=&color=greygreen"
      alt="Donate (GitHub Sponsor)" />
  </a>

  <a href="https://github.com/jeffreytse/zsh-vi-mode/releases">
    <img src="https://img.shields.io/github/v/release/jeffreytse/zsh-vi-mode?color=brightgreen"
      alt="Release Version" />
  </a>

  <a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/badge/License-MIT-brightgreen.svg"
      alt="License: MIT" />
  </a>

  <a href="https://liberapay.com/jeffreytse">
    <img src="http://img.shields.io/liberapay/goal/jeffreytse.svg?logo=liberapay"
      alt="Donate (Liberapay)" />
  </a>

  <a href="https://patreon.com/jeffreytse">
    <img src="https://img.shields.io/badge/support-patreon-F96854.svg?style=flat-square"
      alt="Donate (Patreon)" />
  </a>

  <a href="https://ko-fi.com/jeffreytse">
    <img height="20" src="https://www.ko-fi.com/img/githubbutton_sm.svg"
      alt="Donate (Ko-fi)" />
  </a>

</p> -->

<div align="center">
  <h4>
    <a href="#-whyttm">Why TTM?</a> |
    <a href="#-features">Features</a> |
    <a href="#%EF%B8%8F-installation">Install</a> |
    <a href="#-usage">Usage</a> |
    <a href="#-future">Future</a> |
    <a href="#-credits">Credits</a> |
    <a href="#-license">License</a>
  </h4>
</div>

<div align="center">
  <sub>Built with ❤︎ by Mohammed Alzakariya
  <!-- <a href="https://jeffreytse.net">jeffreytse</a> and
  <a href="https://github.com/jeffreytse/zsh-vi-mode/graphs/contributors">contributors </a> -->
</div>
<br>

<!-- <img alt="TTM Demo" src="https://user-images.githubusercontent.com/9413602/105746868-f3734a00-5f7a-11eb-8db5-22fcf50a171b.gif" /> TODO -->

## 🤔 Why TTM?

Linux offers many powerful tools for time and task management and note taking. This includes 
taskwarrior and TUI front ends for it such as vit. It includes tmux and vim which can be extended
for quick context switching, searching and recording of data to keep our attention focused. 

Unfortunately, setting up the right environment takes a lot of work and is not easily reproducible
across systems. TTM Offers a fully integrated solution working out of the box with Docker. It
includes customizations to tmux, vim, and taskwarrior to enhance user experience and navigation.

Taskwarrior by default needs a lot of configurations which can also be redundant. TTM configures
all of this off the bat and offers a subtasks feature and integration between taskwarrior and a
calendar react app running
```