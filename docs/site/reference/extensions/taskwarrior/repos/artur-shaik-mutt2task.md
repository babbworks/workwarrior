# artur-shaik/mutt2task

**URL:** https://github.com/artur-shaik/mutt2task  
**Stars:** 18  
**Language:** Python  
**Last push:** 2024-04-18  
**Archived:** No  
**Topics:** email, mutt, python, shell, taskopen, taskwarrior  

## Description

Creates task in taskwarrior from email within mutt

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
Slight modification of already existed [mutt2task](https://gist.github.com/noqqe/6562350) script.

Dependencies:
  - [taskwarrior](https://taskwarrior.org/);
  - [taskopen](https://github.com/ValiValpas/taskopen) script;
  - [elinks](http://elinks.or.cz/).

Based on this [blogpost](http://www.nixternal.com/mark-e-mails-in-mutt-as-tasks-in-taskwarrior/)

This script creates task in `taskwarrior` from email within `mutt`. The subject of email becomes task name, and the body exports to `taskopen` note.

# Install

Change your location to script directory, and then link it:

```
ln -s $PWD/mutt2task.py ~/bin/
```

Add this to your `.muttrc`:

```
macro index,pager t "<pipe-message>mutt2task.py<enter>"
```

# Usage

Just press `t` on email or inside email.

```