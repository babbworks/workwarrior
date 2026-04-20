# naggie/dstask

**URL:** https://github.com/naggie/dstask  
**Stars:** 1153  
**Language:** Go  
**Last push:** 2026-04-04  
**Archived:** No  
**Topics:** bash, cli, command-line, git, gtd, notes, notes-app, notes-management-system, notes-tool, sync, task, taskwarrior, terminal, terminal-based, todo, zsh  

## Description

Git powered terminal-based todo/note manager --  markdown note page per task. Single binary!

## Category

Sync

## Workwarrior Integration Rating

**Score:** 10  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +2: Profile concept maps directly to ww
- +1: Shell integration — ww is shell-first
- +1: Shell scripting — matches ww stack
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration

## README excerpt

```
<p align="center">
<img align="center" src="etc/icon.png" alt="icon" height="64" />
</p>

<h1 align="center">dstask</h1>

<p align="center">
<i>Single binary terminal-based TODO manager with git-based sync + markdown notes per task</i>
</p>

<p align="center">
<a href="https://cloud.drone.io/naggie/dstask"><img src="https://cloud.drone.io/api/badges/naggie/dstask/status.svg" /></a>
<a href="https://goreportcard.com/report/github.com/naggie/dstask"><img src="https://goreportcard.com/badge/github.com/naggie/dstask" /></a>
<a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-blue.svg" /></a>
<a href="http://godoc.org/github.com/naggie/dstask"><img src="https://img.shields.io/badge/godoc-reference-blue.svg"/></a>
<a href="https://gophers.slack.com/archives/C01ED7UKLBH"><img src="https://img.shields.io/badge/Gophers/dstask-yellow.svg?logo=slack"/></a>
</p>

<br>
<br>
<br>

Dstask is a personal task tracker designed to help you focus. It is similar to
[Taskwarrior](https://taskwarrior.org/) but uses git to synchronise instead of
a special protocol.

If you're at home in the terminal, and with solving the occasional merge
conflict, then dstask is for you!

https://github.com/user-attachments/assets/589d06fd-7486-46e4-b838-ce85af12f0fc

[Video courtesy of xGoivo -- thanks!](https://www.reddit.com/r/taskwarrior/comments/1o7itzg/what_do_you_guys_think_about_this_taskwarrior/)




Features:

<a href="https://repology.org/project/dstask/versions">
    <img src="https://repology.org/badge/vertical-allrepos/dstask.svg" alt="Packaging status" align="right">
</a>

- Powerful context system (automatically applies filter/tags to queries and new tasks)
- **Git powered sync**/undo/resolve ([passwordstore.org](https://www.passwordstore.org/) style) which means no need to set up a sync server, and syncing between devices is easy!
- Task listing won't break with long task text
- `note` command -- edit a **full markdown note** for each task. **Checklists are useful here.**
- `open` command -- **open URLs found in specified task** (including notes) in the browser
- zsh/bash completion (including tags and projects in current context) for speed; PowerShell completion on Windows
- A single statically-linked binary
- [import tool](doc/dstask-import.md) which can import GitHub issues or taskwarrior tasks.

Non-features:

- Collaboration. This is a personal task tracker. Use another system for
  projects that involve multiple people. Note that it can still be beneficial
  to use dstask to track what you are working on in the context of a
  multi-person project tracked elsewhere.

Requirements:

- Git
- A 256-color capable terminal

# Screenshots

<table>
    <tbody>
        <tr>
            <td>
                <p align="center">
                    <img src="https://github.com/naggie/dstask/raw/master/etc/dstask.png">
                    <em>Next command (default when no command is specified)</em>
                </p>
            </
```