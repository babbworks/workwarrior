# huantrinh1802/m_taskwarrior_d.nvim

**URL:** https://github.com/huantrinh1802/m_taskwarrior_d.nvim  
**Stars:** 92  
**Language:** Lua  
**Last push:** 2026-02-23  
**Archived:** No  
**Topics:** markdown, neovim, neovim-plugin, note-taking, taskwarrior  

## Description

Simple utility plugin for taskwarrior in Neovim

## Category

Sync

## Workwarrior Integration Rating

**Score:** 3  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: Python — tooling language used in ww
- -2: Mobile — outside ww scope

## README excerpt

```
# Mark Taskwarrior Down in Neovim

## Description

The plugin allow you to view, add, edit, and complete tasks without ever leaving the comfort of Neovim text
The goals of this plugin are:

- Be a simple tool without obstructing the view of the document
- Improve the workflow of task management in Markdown files
- Not reinvent the wheel of the way Taskwarrior manages tasks

## Screenshots

### Sync Tasks

#### Before syncing

![BeforeSync](https://github.com/huantrinh1802/m_taskwarrior_d.nvim/blob/main/demo/screenshots/BeforeSync.png)

#### After syncing

![AfterSync](https://github.com/huantrinh1802/m_taskwarrior_d.nvim/blob/main/demo/screenshots/AfterSync.png)

### Quick View

![QuickView](https://github.com/huantrinh1802/m_taskwarrior_d.nvim/blob/main/demo/screenshots/QuickViewOfTask.png)

### Edit Task

![EditTaskFloat](https://github.com/huantrinh1802/m_taskwarrior_d.nvim/blob/main/demo/screenshots/EditTask.png)

### QueryView

#### Before run TWQueryTasks

![BeforeQuery](https://github.com/huantrinh1802/m_taskwarrior_d.nvim/blob/main/demo/screenshots/BeforeQueryView.png)

#### After run TWQueryTasks

![AfterQuery](https://github.com/huantrinh1802/m_taskwarrior_d.nvim/blob/main/demo/screenshots/AfterQueryView.png)

#### Virtual Text for Due/Scheduled task

![VirtualTextDue](https://github.com/huantrinh1802/m_taskwarrior_d.nvim/blob/main/demo/screenshots/VirtualTextDue.png)

## Features

- [x] Injected and concealed Taskwarrior task
- [x] Detect task (checkbox) in Markdown or similar files and register the task into Taskwarrior
  - [x] Work with Markdown with ( - [ ])
  - [ ] Docstring in Python
  - [ ] JSDoc in JavaScript
- [x] Bidirectionally manage the task
- [>] Best effort to add contexts to the tasks:
  - [ ] Use treesitter for better capturing contexts
  - [x] Tags
  - [x] Dependencies
    - [x] Detect nested subtasks and update related tasks
    - [x] Render dependencies with query view
  - [x] Project
- [x] View individual task on hover
- [x] Edit task detail within Neovim (through nui.nvim)
- [x] `Query View` similar to `dateview` in Obsidian or `Viewport` in Taskwiki
- [x] Virtual text for due and scheduled tasks
- [x] Inline Taskwarrior attribute parsing

## Inline Taskwarrior Attributes

You can include Taskwarrior attributes directly in your markdown task text. The plugin will parse and apply them to the task in Taskwarrior, then display only the clean description in your markdown.

**Supported attributes:**
- **Projects**: `project:home`, `project:work.coding`
- **Tags**: `+urgent`, `+shopping`, `-someday`
- **Due dates**: `due:tomorrow`, `due:2024-12-31`, `due:eom`
- **Scheduled dates**: `scheduled:monday`, `scheduled:2024-12-25`
- **Priority**: `priority:H`, `priority:M`, `priority:L`
- **Any Taskwarrior attribute**: `wait:1week`, `until:eoy`, `depends:UUID`, etc.

**Example:**

Before sync:
```markdown
- [ ] Buy groceries project:home +shopping due:friday
```

After `:TWSyncTasks`:
```markdown
- [ ] Buy groceries $id{uuid-he
```