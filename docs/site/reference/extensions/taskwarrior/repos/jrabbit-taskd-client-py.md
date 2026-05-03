# jrabbit/taskd-client-py

**URL:** https://github.com/jrabbit/taskd-client-py  
**Stars:** 18  
**Language:** Python  
**Last push:** 2022-12-08  
**Archived:** No  
**Topics:** python, taskd, taskwarrior  

## Description

:hammer: :snake: A python client for taskd

## Category

Sync

## Workwarrior Integration Rating

**Score:** 4  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration
- +1: Python — tooling language used in ww
- -1: Taskserver — ww doesn't use sync server

## README excerpt

```
taskd-client-py
===============
[![PyPI version](https://img.shields.io/pypi/v/taskc.svg)](https://pypi.python.org/pypi/taskc)
[![Build Status](https://travis-ci.org/jrabbit/taskd-client-py.svg?branch=master)](https://travis-ci.org/jrabbit/taskd-client-py)

A client library providing an interface to [Taskd (from taskwarrior)](https://gothenburgbitfactory.org/projects/taskd.html)

Library users will have some obligations as per the protocol. (key storage, sync key, tasks themselves (and additional data), etc)


Getting Started
---------------
* `pip install taskc`
```python 
from taskc.simple import TaskdConnection
tc = TaskdConnection.from_taskrc() # only works if you have taskwarrior setup
resp = tc.pull()
```

User considerations
-------------------
* For taskd < 1.1.0 set `client.allow` in your taskd config ex: `client.allow=^task [2-9],^Mirakel [1-9],^taskc-py [0-9]`
* optionally enable connection debugging for output when running taskd interactively `debug.tls=2`
* for convience we're assuming ~/.task is your taskwarrior conf dir
* [if you run into trouble](https://taskwarrior.org/docs/taskserver/troubleshooting-sync.html)

```