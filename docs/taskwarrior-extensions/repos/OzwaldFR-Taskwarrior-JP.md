# OzwaldFR/Taskwarrior-JP

**URL:** https://github.com/OzwaldFR/Taskwarrior-JP  
**Stars:** 2  
**Language:** Python  
**Last push:** 2025-09-10  
**Archived:** No  
**Topics:** joplin, taskwarrior, todolist  

## Description

A taskwarrior inspired script that provides a CLI for manipulating todo-notes stored in Joplin.

## Category

Sync

## Workwarrior Integration Rating

**Score:** 7  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +1: Shell integration — ww is shell-first
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration
- +1: Python — tooling language used in ww

## README excerpt

```
# What is Taskwarrior-JP ?

Taskwarrior-JP (short: "TJP") is a python script that gives a CLI interface to Joplin's todo-notes in an efficient manner.

Taskwarrior-JP will allow you to see your todo-notes, to search them (thanks to filtering), to mark them as "done", and to create some.

TJP is very much inspired by [Taskwarrior](https://taskwarrior.org/).

# Quickstart

## Prerequisites

First, git clone (or download) this repository.

Then install the requirements `pip install -r requirements` (or manually download `prettytable.py` and save it in the same folder as `tjp.py`).

Start your Joplin App and enable the "WebClipper" option (if you haven't already :)).
You also want to take note of the Web Clipper token.
That's in the "Tools > Options" menu within Joplin, then "Web Clipper" in the left taskbar.

Copy `tjp.ini.sample` as `tjp.ini` in the same folder as `tjp.py` then open it and replace `Enter_your_joplin_token_here` with your Web Clipper token.
Note : this step is optionnal ; if you prefer, you can pass the token as a command-line argument to `tjp.py` each time you call it : `tjp.py --token=your_WebClipper_token ...`.

## Basic usage : list, create, search, mark as done

![Recording of shell : basic examples](https://github.com/OzwaldFR/Taskwarrior-JP/raw/refs/heads/main/doc/video1_list_add_search_done.gif)

### Listing todo-notes

If you execute `./tjp.py`, you should see a list of all the todo-notes that are currently not tagged as "done" within your Joplin App.

### Creating todo-notes

If you execute `./tjp.py add "This is the title of my new todo"`, Taskwarrior-JP will create a new todo-note in your Joplin App (in the root notebook).
The title of this new note will be "This is the title of my new todo".

### Search todo-notes

If you execute `./tjp.py lorem`, you should see a list of all the todo-notes which have the string "lorem" in their title (obviously, you should change the word "lorem" for something that's relevant to what you are searching for : `./tjp.py buy`, `./tjp.py john`, etc.).
That's a very simple search feature but it should be enough for most beginners.
You'll learn more advanced search methods (using tags, projects, and metadata) later in this README.

### Marking a todo-note as "done"

When you list todo-notes, you should see the first column named "ID". 
These IDs are used to reference your todo-notes.
Therefore, if your newly created task has ID "b42", this is how you tell Taskwarrior-JP that you want to deal with it : `./tjp.py b42`.

Knowing all this, this is how you mark the task with ID "b42" as "done" : `./tjp.py b42 done`.

### Summary

 * `./tjp.py` will list your tasks (in a "smart" order)
 * `./tjp.py add "Clean my messy code"` will add a task (with title "Clean my messy code")
 * `./tjp.py 123 done` will mark task of ID "123" as done.

## Common usage : modifying todo, using tags and metadata

![Recording of shell : common examples](https://github.com/OzwaldFR/Taskwarrior-JP/raw/refs/heads/main/doc/v
```