# DISTREAT/taskwarrior-android

**URL:** https://github.com/DISTREAT/taskwarrior-android  
**Stars:** 1  
**Language:** Shell  
**Last push:** 2025-04-25  
**Archived:** Yes  
**Topics:** taskwarrior, taskwarrior3  

## Description

Build files for compiling statically-linked taskwarrior binaries on Android

## Category

Hooks

## Workwarrior Integration Rating

**Score:** -1  
**Rating:** ★☆☆☆☆  Unlikely  

### Scoring notes

- +1: Shell scripting — matches ww stack
- -2: Mobile — outside ww scope

## README excerpt

```
# Compiling Taskwarrior for Android

This repository contains scripts to cross-compile Taskwarrior 3 for Android.

## Philosophy

With Taskwarrior's major release v3, many efforts to port Taskwarrior
to Android were halted. Additionally, the rewrite of parts into Rust made
it somewhat tricky to compile, especially since the platform is not a
common place for Taskwarrior.

Therefore, the purpose of this repository is to provide a more accessible
means of integrating Taskwarrior into other open-source projects.

## Compilation

To compile Taskwarrior for Android, a Docker installation is assumed:

```bash
git submodule update --init --recursive
./build.sh arm64-v8a
```

This will generate the build files for `./taskwarrior` under `./taskwarrior/build`.

```