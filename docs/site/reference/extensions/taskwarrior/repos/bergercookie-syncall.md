# bergercookie/syncall

**URL:** https://github.com/bergercookie/syncall  
**Stars:** 601  
**Language:** Python  
**Last push:** 2025-11-21  
**Archived:** No  
**Topics:** asana, caldav, calendar, google, google-calendar, google-calender, google-keep, google-tasks, notion, python3, sync, synchronization-service, task-management, taskwarrior  

## Description

Bi-directional synchronization between services such as Taskwarrior, Google Calendar, Notion, Asana, and more

## Category

Sync

## Workwarrior Integration Rating

**Score:** 7  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +1: Shell integration — ww is shell-first
- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Python — tooling language used in ww

## README excerpt

```
# syncall

<p align="center">
  <img src="https://raw.githubusercontent.com/bergercookie/syncall/master/misc/meme.png"/>
</p>

<a href="https://github.com/bergercookie/syncall/actions" alt="master">
<img src="https://github.com/bergercookie/syncall/actions/workflows/tests.yml/badge.svg?branch=master" /></a>
<img src="https://github.com/bergercookie/syncall/actions/workflows/linters.yml/badge.svg?branch=master" /></a>
<a href='https://coveralls.io/github/bergercookie/syncall?branch=master'>
<img src='https://coveralls.io/repos/github/bergercookie/syncall/badge.svg?branch=master' alt='Coverage Status' /></a>
<a href="https://github.com/pre-commit/pre-commit">
<img src="https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white" alt="pre-commit"></a>
<a href="https://github.com/bergercookie/syncall/blob/master/LICENSE" alt="LICENSE">
<img src="https://img.shields.io/github/license/bergercookie/syncall.svg" /></a>
<a href="https://pypi.org/project/syncall" alt="PyPI">
<img src="https://img.shields.io/pypi/pyversions/syncall.svg" /></a>
<a href="https://badge.fury.io/py/syncall">
<img src="https://badge.fury.io/py/syncall.svg" alt="PyPI version" height="18"></a>
<a href="https://pepy.tech/project/syncall">
<img alt="Downloads" src="https://pepy.tech/badge/syncall"></a>
<a href="https://github.com/psf/black">
<img alt="Code style: black" src="https://img.shields.io/badge/code%20style-black-000000.svg"></a>

## Description

`syncall` is your one-stop software to bi-directionally synchronize and keep in
sync the data from a variety of services. The framework is targeted towards, but
not limited to, the synchronization of note-taking and task management data.
Each synchronization comes with its own executable which handles the
synchronization services/sides at hand.

One of the main goals of `syncall` is to be extendable. Thus it should be easy
to introduce support for either a new service / synchronization side (e.g.,
[`ClickUp`](https://clickup.com/)) or a new synchronization altogether (e.g.,
ClickUp <-> Google Keep) given that you [implement the corresponding
synchronization sides and conversion
methods](docs/implement-a-new-synchronization.md). See also the
[CONTRIBUTING](CONTRIBUTING.md) guide to get started.

At the moment the list of supported synchronizations is the following:

<table style="undefined;table-layout: fixed; width: 823px">
<thead>
  <tr>
    <th></th>
    <th>Description</th>
    <th>Executable</th>
  </tr>
</thead>
<tbody>
  <tr>
    <td><a href="https://github.com/bergercookie/syncall/blob/master/docs/readme-tw-gtasks.md">README</a></td>
    <td> <a href="https://taskwarrior.org/">Taskwarrior</a> ⬄ <a href="https://support.google.com/tasks/answer/7675772">Google Tasks</a></td>
    <td><tt>tw-gtasks-sync</tt></td>
  </tr>
  <tr>
    <td><a href="https://github.com/bergercookie/syncall/blob/master/docs/readme-tw-gcal.md">README</a></td>
    <td> <a href="https://taskwarrior.org/">Taskwarrior</a> ⬄ <
```