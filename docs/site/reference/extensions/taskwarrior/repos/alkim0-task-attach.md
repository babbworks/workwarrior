# alkim0/task-attach

**URL:** https://github.com/alkim0/task-attach  
**Stars:** 8  
**Language:** Python  
**Last push:** 2020-08-30  
**Archived:** No  
**Topics:** mutt, taskwarrior  

## Description

A set of scripts to manage attachments in TaskWarrior

## Category

NLP / AI

## Workwarrior Integration Rating

**Score:** 1  
**Rating:** ★★☆☆☆  Low  

### Scoring notes

- +1: GitHub is ww's primary issue source

## README excerpt

```
# **task-attach**
**task-attach** is a set of utility scripts to manage attachments in TaskWarrior. Currently, TaskWarrior has no built-in support for attaching external files or resources to tasks (via annotations), and **task-attach** hopes to address this problem. **task-attach** is inspired the by the [**taskopen**](https://github.com/ValiValpas/taskopen) script, but has the following additional features:
- Support for attachments other than files (i.e., urls and emails)
- A `mutt2task` script which helps you create tasks from emails
- A `open-via-mutt` script which opens mutt and jumps to the email corresponding to the given message-id.

## Installation
To install **task-attach**, simply run:
```
pip install task-attach
```
This installs the scripts:
- [`task-attach-add`](#task-attach-add)
- [`task-attach-new`](#task-attach-new)
- [`task-attach-open`](#task-attach-open)
- [`open-via-mutt`](#open-via-mutt)
- [`mutt2task`](#mutt2task)


## Configuration
Upon the first run of any of the `task-attach-**` scripts, a config file will be created at `$XDG_CONFIG_HOME/task-attach/config.yaml`. For specific configuration options, please see the generated file.


## task-attach-add
This script attaches an already existing resource to a task. The basic syntax of the command is as follows:
```
task-attach-add [-t {file,mail,url}] <id-or-filter> <spec> [<comment> ...]
```
For example if I want to attach a grocery list to a "Go grocery shopping" task:
```
$ task add Go grocery shopping
Created task 1.
$ task-attach-add 1  ~/grocery-list The grocery list.
$ task info 1

Name          Value
ID            1
Description   Go grocery shopping
                2020-08-30 12:57:45 The grocery list. file:/home/$user/grocery-list
```
Or if I want to associate a URL with a task:
```
$ task add Remember to star!
Created task 2.
$ task-attach-add 2 github.com/alkim0/task-attach github link
$ task info 2

Name          Value
ID            2
Description   Remember to star!
                2020-08-30 13:04:56 github link url:http://github.com/alkim0/task-attach
```
Similarly, the resource specification can be a message-id (with the enclosing "<>") for an email.

Note that `task-attach-add` is meant to work only for existing resources, so if the given resource is a file, the path must exist.

The script tries to guess the best type for the given resource specification, but the `-t` flag can be specified to make the resource type explicit.


## task-attach-new
Sometimes, I just want to create a new notes file to associate with a task without having to think about it. That is what `task-attach-new` is for. The syntax is:
```
task-attach-new [-e EDITOR] [-t ext] <id-or-filter> [<comment> ...]
```
This creates a new file in the `~/tasknotes` directory ([configurable](#configuration)) with a randomly generated UUID and opens it up with the specified editor. After editing, saving, and quitting the file, `task-attach-new` will add the newly generated file as an attachment to the 
```