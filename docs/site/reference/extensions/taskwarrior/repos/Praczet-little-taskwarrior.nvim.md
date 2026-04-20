# Praczet/little-taskwarrior.nvim

**URL:** https://github.com/Praczet/little-taskwarrior.nvim  
**Stars:** 3  
**Language:** Lua  
**Last push:** 2024-12-09  
**Archived:** No  
**Topics:** dashboard, dashboard-nvim, taskwarrior  

## Description

A little helper for displaying tasks from TaskWarrior in NeoVim Dashboard

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 5  
**Rating:** ★★★★☆  High  

### Scoring notes

- +2: Urgency coefficients are a ww UDA focus area
- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source
- +1: Import/export useful for profile migration

## README excerpt

```
# little-taskwarrior.nvim

A little helper for displaying TaskWarrior's tasks.

## Table of Contents

<!-- mtoc-start -->

* [Features](#features)
* [Screens](#screens)
  * [Tasks list without project file](#tasks-list-without-project-file)
  * [Tasks list with a project file](#tasks-list-with-a-project-file)
  * [Task list with my plugin next-birthday](#task-list-with-my-plugin-next-birthday)
* [Installation](#installation)
* [Dependency](#dependency)
* [Configuration](#configuration)
  * [Dashboard](#dashboard)
    * [Limit and Non_Project_Limit](#limit-and-non_project_limit)
  * [Project file or not](#project-file-or-not)
  * [project_replacements and shorten_sections](#project_replacements-and-shorten_sections)
    * [`project_replacements` example](#project_replacements-example)
    * ['shorten_sections' example](#shorten_sections-example)
  * [`urgency_threshold` and `highlight_groups`](#urgency_threshold-and-highlight_groups)
* [Usage](#usage)
  * [Integration with Dashboard-nvim](#integration-with-dashboard-nvim)
    * [Static](#static)
    * [Dynamic](#dynamic)
      * [Workaround - a kind of solution](#workaround---a-kind-of-solution)
* [TODO](#todo)

<!-- mtoc-end -->

## Features

For now this plugin offers the following features:

- List of task as list of string to use in the Dashboard
- For current project and others
- Just a few most urgent tasks

## Screens

### Tasks list without project file

![Tasks list without project file](assets/scr-all.png)

### Tasks list with a project file

![Tasks list with project file](assets/scr-project.png)

### Task list with my plugin next-birthday

![Task list with my plugin NextBirthday](assets/scr-bd.png)

## Installation

You can install `little-taskwarrior.nvim` using your favorite package manager.
For example with `Lazy`:

```lua
 {
  "praczet/little-taskwarrior.nvim",
  config = function()
    require("little-taskwarrior").setup({ })
  end,
}
```

## Dependency

- **[TaskWarrior](https://taskwarrior.org/)** - it uses standard export command form it
- **[Dashboard-nvim](https://github.com/nvimdev/dashboard-nvim)** - if you want to use it in a dashboard

## Configuration

```lua
--- Default configuration
M.config = {
 --- configuration for the Dashboard
 dashboard = {
  --- task limit
  limit = 5,
  --- max number of columns
  max_width = 50,
  --- if > 0 then  additional task (besides current project ones) will be added
  non_project_limit = 5,
  --- List of columns to be displayed
  columns = {
   "id",
   "project",
   "description",
   "due",
   "urgency",
  },
  --- List of replacements when getting lines for dashboard
  project_replacements = {
   ["work."] = "w.",
   ["personal."] = "p.",
  },
  --- Section separator
  sec_sep = ".",
  --- Enable or disable section shortening
  shorten_sections = true,
 },
 --- function to reload dashboard config
 get_dashboard_config = nil,
 --- toggle the logging
 debug = true,
 --- where information about taskwarrior project can be found
 project_
```