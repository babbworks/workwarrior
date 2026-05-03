# bergercookie/tw-hooks

**URL:** https://github.com/bergercookie/tw-hooks  
**Stars:** 15  
**Language:** Python  
**Last push:** 2023-01-22  
**Archived:** No  
**Topics:** automation, python, python3, task, taskmanager, taskwarrior, taskwarrior-hooks  

## Description

Collection of Taskwarrior hooks + detection and registration mechanism

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 5  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +1: GitHub is ww's primary issue source
- +1: Import/export useful for profile migration
- +1: Python — tooling language used in ww

## README excerpt

```
# Taskwarrior Hooks

<p align="center">
  <img src="https://raw.githubusercontent.com/bergercookie/tw-hooks/master/misc/logo.png"/>
</p>

<a href="https://github.com/bergercookie/tw-hooks/actions" alt="CI">
<img src="https://github.com/bergercookie/tw-hooks/actions/workflows/ci.yml/badge.svg" /></a>
<a href="https://github.com/pre-commit/pre-commit">
<img src="https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white" alt="pre-commit"></a>

<a href='https://coveralls.io/github/bergercookie/tw-hooks?branch=master'>
<img src='https://coveralls.io/repos/github/bergercookie/tw-hooks/badge.svg?branch=master' alt='Coverage Status' /></a>
<a href="https://github.com/bergercookie/tw-hooks/blob/master/LICENSE.md" alt="LICENSE">
<img src="https://img.shields.io/github/license/bergercookie/tw-hooks.svg" /></a>
<a href="https://pypi.org/project/tw_hooks/" alt="pypi">
<img src="https://img.shields.io/pypi/pyversions/tw-hooks.svg" /></a>
<a href="https://badge.fury.io/py/tw-hooks">
<img src="https://badge.fury.io/py/tw-hooks.svg" alt="PyPI version" height="18"></a>
<a href="https://pepy.tech/project/tw-hooks">
<img alt="Downloads" src="https://pepy.tech/badge/tw_hooks"></a>
<a href="https://github.com/psf/black">
<img alt="Code style: black" src="https://img.shields.io/badge/code%20style-black-000000.svg"></a>

## Description

This is a collection of [Taskwarrior
hooks](https://taskwarrior.org/docs/hooks_guide.html) that I use in my
day-to-day workflows. It comes along a detection and easy-registration mechanism
that should make it easy to develop and then distribute your own hooks. The
hooks are structured as classes under the `tw_hooks/hooks` directory.

## Installation

Install it from `PyPI`:

```sh
pip3 install --user --upgrade tw_hooks
```

To get the latest version install directly from source:

```sh
pip3 install --user --upgrade git+https://github.com/bergercookie/tw-hooks
```

After the installation, you have to run the `install-hooks-shims` executable
(which by this point should be in your `$PATH`). Running it will create shims
(thin wrapper scripts) under `~/.task/hooks` in order to register all the hooks
with Taskwarrior.

## Available hooks

Currently the following hooks are available out-of-the-box:

<table style="undefined;table-layout: fixed; width: 823px">
<thead>
  <tr>
    <th>Hook</th>
    <th>Description</th>
    <th>Events</th>
  </tr>
</thead>
<tbody>
  <tr>
    <td><tt>AutoTagBasedOnTags</tt></td>
    <td>Inspect the list of tags in the added/modified tasks provided and add additional tags if required</td>
    <td><tt>on-modify</tt>, <tt>on-add</tt></td>
  </tr>
  <tr>
    <td><tt>CorrectTagNames</tt></td>
    <td>Change tag names based on a predefined lookup table</td>
    <td><tt>on-modify</tt>, <tt>on-add</tt></td>
  </tr>
  <tr>
    <td><tt>DetectMutuallyExclusiveTags</tt></td>
    <td>See whether the user has specified an incompatible combination of tags</td>
    <td><tt>on-modify</tt>, <tt>on-ad
```