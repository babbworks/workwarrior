# jschlatow/taskopen

**URL:** https://github.com/jschlatow/taskopen  
**Stars:** 431  
**Language:** Nim  
**Last push:** 2026-01-13  
**Archived:** No  
**Topics:** nim, taskwarrior  

## Description

Tool for taking notes and open urls with taskwarrior (mirror of https://codeberg.org/jschlatow/taskopen)

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 5  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos

## README excerpt

```
Taskopen was original developed as a simple wrapper script for taskwarrior that enables interaction with annotations (e.g. open, edit, execute files).
The current version is a pretty powerful customisable tool that supports a variety of use cases.
This README serves as a basic getting-started guide including install instructions and examples.
If your are interested in more details, please have a look at the [wiki] or the [man page].

[wiki]: https://github.com/jschlatow/taskopen/wiki/2.0
[man page]: doc/man/taskopen.1.md

# Dependencies

This tool is an enhancement to taskwarrior, i.e. it depends on the task binary. See http://www.taskwarrior.org

Taskopen is implemented in nim (requires at least version 1.4). Taskopen also requires make, xdg-open, and when run on the Windows Subsystem for Linux, wslu.

The helper scripts are usually run by bash. Some of the scripts also depend on (g)awk.

# What does it do?

It allows you to link almost any file, webpage or command to a taskwarrior task by adding a filepath, web-link or uri as an annotation. Text notes, images, PDF files, web addresses, spreadsheets and many other types of links can then be filtered, listed and opened by using taskopen.

Arbitrary actions can be configured with taskopen to filter and act on the annotations or other task attributes.

Run `taskopen -h` or `man taskopen` for further details.
The following sections show some (very) basic usage examples.


## Basic usage

Add a task:

	$ task add Example

Add an annotation which links to a file:

	$ task 1 annotate -- ~/checklist.txt

(Note that the "--" instructs taskwarrior to take the following arguments as the description part
without doing any parser magic.)

Open the linked file by using the task's ID:

	$ taskopen 1

Or by a filter expression:

	$ taskopen Example

## Add default notes

Inspired by Alan Bowens 'tasknote' you can add a default notes file to a task. These files will be
automatically created by the task's UUID and don't require to annotate the task with a specific file path.

As soon as you annotate a task with 'Notes':

	$ task 1 annotate Notes

...you can open and edit this file by:

	$ taskopen 1

...which, by default, opens a file like "~/tasknotes/5727f1c7-2efe-fb6b-2bac-6ce073ba95ee".

**Note:** You have to create the folder "~/tasknotes" before this works with the default folder.

Automatically annotating tasks with 'Notes' can be achieved with 'NO_ANNOTATION_HOOK' as described in
the manpage taskopenrc(5).

Optionally, you may add any file extension to the annotation (e.g. 'Notes.txt'), which will instruct
taskopen to add the same extension to the created file.

## Multiple annotations

You can also add weblinks to a task and even mix all kinds of annotations:

	$ task 1 annotate www.taskwarrior.org
	$ task 1 annotate I want to consider this
	$ task 1 annotate -- ~/Documents/manual.pdf
	$ taskopen 1

Taskopen will determine the actionable annotations and will show a menu to let the user choose what to do:
```