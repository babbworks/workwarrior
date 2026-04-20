# somecho/utility-scripts

**URL:** https://github.com/somecho/utility-scripts  
**Stars:** 13  
**Language:** Clojure  
**Last push:** 2023-06-02  
**Archived:** No  
**Topics:** babashka, clojure, deps-edn, java, ledger-cli, ripgrep, taskwarrior  

## Description

A collection of helper scripts for Clojure, Java, Ledger and Taskwarrior. Written in Clojure.

## Category

Sync

## Workwarrior Integration Rating

**Score:** 13  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +2: Sync capability relevant to ww profile isolation
- +1: Shell integration — ww is shell-first
- +1: Shell scripting — matches ww stack
- +2: JRNL is part of ww toolchain
- +2: Hledger is part of ww toolchain
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration

## README excerpt

```
# Somē's utility scripts

Here are some utility scripts I wrote for myself. At first I wrote the scripts in a shell scripting language. But then I discovered [Babashka](https://github.com/babashka/babashka) and I love Clojure. I decided to port all the scripts to Clojure instead. You will need [Babashka](https://github.com/babashka/babashka) to run these scripts. These are helper tools for [Clj](https://clojure.org/guides/deps_and_cli), Java, [Ledger](https://github.com/ledger/ledger) and [Taskwarrior](https://github.com/GothenburgBitFactory/taskwarrior).

### [Scripts](#scripts) included:
1. [accountsof](#accountsof) - outputs the name of all accounts used in a [Ledger](https://github.com/ledger/ledger) journal file
2. [cljminimal](#cljminimal) - creates an ultra barebones deps.edn [clj](https://clojure.org/guides/deps_and_cli) project for quick hacking
3. [depo](#depo) - adds dependencies to Clojure projects. Supports `deps.edn`,`project.clj`,`shadow-cljs.edn`.
4. [jrun](#jrun) - single file Java runner 
5. [keepbooks](#keepbooks) - simple transaction entry helper for [Ledger](https://github.com/ledger/ledger) CLI accounting. Supports interactive entry.
6. [on-modify-log](#on-modify-log) - a [Taskwarrior](https://github.com/GothenburgBitFactory/taskwarrior) hook to log the latest modified task
7. [projectsof](#projectsof) - finds directories of certain project types
8. [resumetask](#resumetask) - resumes latest modified [Taskwarrior](https://github.com/GothenburgBitFactory/taskwarrior) task
9. [startnewtask](#startnewtask) - creates and starts a new [Taskwarrior](https://github.com/GothenburgBitFactory/taskwarrior) task
10. [stoptasks](#stoptasks) - stops all active [Taskwarrior](https://github.com/GothenburgBitFactory/taskwarrior) tasks
11. [taskinfo](#taskinfo) - prints the attribute of a [Taskwarrior](https://github.com/GothenburgBitFactory/taskwarrior) task
 
## Installation
You need to first [install Babashka](https://github.com/babashka/babashka#quickstart). 
 ```sh
 git clone https://github.com/somecho/utility-scripts
 cd utility-scripts
 ./install.clj 
 ```
 This will copy all the scripts into `~/.local/bin`. Make sure `~/.local/bin` is in your path to call the scripts globally.
 
### Uninstalling
 To uninstall, simply call `uninstall-some-scripts` and all the scripts will be deleted from `~/.local/bin`.
 
## [accountsof](./accountsof.clj)
Outputs the names of all the accounts used in a [Ledger](https://github.com/ledger/ledger) journal file. Example: `accountsof LEDGERFILE`.

## [cljminimal](./cljminimal.clj)
A script to create an ultraminimal clj project with an empty deps.edn and a singular hello world main function. To use, simply call `cljminimal my-minimal-clj-project` and a project called `my-minimal-clj-project` will be created for you. Mainly used for quick hacking and throwaway prototyping.

## [depo](./depo.clj)
Adds dependencies to Clojure projects. To use, run the script at the root of a project containing a `deps.edn`, `pr
```