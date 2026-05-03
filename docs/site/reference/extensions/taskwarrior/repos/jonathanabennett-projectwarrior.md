# jonathanabennett/projectwarrior

**URL:** https://github.com/jonathanabennett/projectwarrior  
**Stars:** 16  
**Language:** Common Lisp  
**Last push:** 2023-05-03  
**Archived:** No  
**Topics:** common-lisp, gtd, taskwarrior  

## Description

A suite of tools to guide a user through a thorough weekly review in the GTD format.

## Category

Sync

## Workwarrior Integration Rating

**Score:** 5  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +2: Sync capability relevant to ww profile isolation
- +1: Shell integration — ww is shell-first
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- -2: GUI/browser — not ww-native

## README excerpt

```
# Projectwarrior

**0.3.0 BREAKING CHANGE:** Because I am not sure exactly how to add a project from just the slug present in taskwarrior, the task-hook is currently depreciated. Leaving it running will not overwrite anything (It targets a different file), but any projects that it pulls from taskwarrior won't get added to projectwarrior.

### _Jonathan A. Bennett <doulos05@gmail.com>_

This is a simple command line project management tool. Users can enter the projects along with metadata about the projects and track them through to completion. It integrates with taskwarrior for tracking the tasks within those projects, but could be integrated manually with another tool if you wanted.

See our [wiki](https://github.com/jonathanabennett/projectwarrior/wiki) for more details!

## License

MIT

## Installation

### [Prerequisites](https://github.com/jonathanabennett/projectwarrior/wiki/prerequisites)

Projectwarrior is written in Common Lisp and requires a basic Common Lisp setup in order to run. Ensure that the following are correctly configured on your system:

1. [sbcl](http://www.sbcl.org/index.html) Steel Bank Common Lisp (Projectwarrior should work with other Common Lisps, but has not been tested).
2. [Quicklisp](https://www.quicklisp.org/beta/), the package manager for Common Lisp. This is used to download and install any 3rd party Common Lisp systems needed for Projectwarrior to run.

### [Installation](https://github.com/jonathanabennett/projectwarrior/wiki/install)
Once you have SBCL and Quicklisp setup according to the instructions on their website, follow the steps below to install Projectwarrior.

1. Clone the repository into your local-projects folder (typically `~/quicklisp/local-projects`).
2. `make build` to create the projectwarrior executable.
3. `make install` to copy the `projectwarrior` executable to `~/.bin`. If you need it to be elsewhere to be on your path, please skip this step and manually copy it.

## Usage

Below is a quick summary with examples for every command. More details can be found in the wiki, particularly the [philosophy](https://github.com/jonathanabennett/projectwarrior/wiki/philosophy) and [examples](https://github.com/jonathanabennett/projectwarrior/wiki/examples) pages, which get updated regularly.

### Add

`project add <details>` adds a project. Projects are stored as JSON objects in an array stored in `~/.projects/active.json`. Each object can have the following properties.

- UUID: The UUID is set programmatically by projectwarrior and can be used to identify projects uniquely. The user should never need to change this.
- ID: The project's position within the JSON array it is stored in. This updates every time the JSON file is saved and can be used to refer to projects.
- Slug: The slug is a short title suitable for use as a taskwarrior `project`. It is used by Projectwarrior when adding tasks to taskwarrior. Slugs are identified by `slug:<string>`. For example: `slug:product-launch` or `slug:springClea
```