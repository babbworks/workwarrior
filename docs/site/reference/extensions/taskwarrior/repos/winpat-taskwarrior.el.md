# winpat/taskwarrior.el

**URL:** https://github.com/winpat/taskwarrior.el  
**Stars:** 9  
**Language:** Emacs Lisp  
**Last push:** 2022-02-13  
**Archived:** No  
**Topics:** emacs, taskwarrior  

## Description

An interactive emacs frontend to taskwarrior

## Category

Import / Export

## Workwarrior Integration Rating

**Score:** 2  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: GitHub is ww's primary issue source
- +1: Import/export useful for profile migration

## README excerpt

```
# Taskwarrior.el
![](https://github.com/winpat/taskwarrior.el/workflows/CI/badge.svg)

An interactive emacs frontend for taskwarrior.

> NOTE: **This major mode is under heavy infrequent development.**

## Installation
Eventually my goal is to make taskwarrior.el available through MELPA. Currently I simply load the
necessary elisp through:

``` emacs-lisp
(use-package taskwarrior
  :init
  (load "~/yourcheckout/taskwarrior.el")
  :bind
  (("C-x t" . taskwarrior)
   ("C-x t" . taskwarrior)))
```

## Configuration
TBD

## Development
While developing we don't want taskwarrior.el to mess with our taskwarrior tasks. That's why we use
[direnv](https://direnv.net/) to export $TASKRC and $TASKDATA to point to the git repository.

With direnv you can either launch emacs within the
taskwarrior.el repository to make use of the mentioned einvironment variables or use the excellent
[emacs-direnv mode](https://github.com/wbolster/emacs-direnv) to make emacs direnv aware.

```