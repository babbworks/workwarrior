# duckdm/neowarrior.nvim

**URL:** https://github.com/duckdm/neowarrior.nvim  
**Stars:** 44  
**Language:** Lua  
**Last push:** 2025-04-03  
**Archived:** No  
**Topics:** neovim, neovim-plugin, nvim, nvim-plugin, task, task-manager, tasks, taskwarrior  

## Description

A neovim wrapper/plugin to use taskwarrior inside neovim

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 4  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +2: Urgency coefficients are a ww UDA focus area
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source

## README excerpt

```
A simple taskwarrior plugin for NeoVim. Made this mostly for my self to have as a sidebar with my tasks inside neovim. 

![gif example v0.1.4 1](./docs/gif/neowarrior-0.1.4_1.gif)
![gif example v0.1.4 2](./docs/gif/neowarrior-0.1.4_2.gif)

# Requirements

- [Neovim >=0.10.0](https://github.com/neovim/neovim/releases/tag/v0.10.0)
- [Taskwarrior](https://taskwarrior.org/)

## Optional

- A nerd font is highly recommended for the icons. Se config for setting custom icons.
- [folke/noice.nvim](https://github.com/folke/noice.nvim) for a nice cmdline UI.

# Features

- Add, start, modify and mark tasks done
- Filter tasks
  - Select from common filter
  - Custom filter input
- Select report
- Select dependency/parent task
- Show task details
- Task detail float (enabled on active line)
- Grouped and tree views (based on task project)
- Customizable keymaps
- Customizable reports and filters
- Customize config per directory


# Installation

## Simple setup with lazy.nvim

```lua
return {
  'duckdm/neowarrior.nvim',
  dependencies = {
    'nvim-telescope/telescope.nvim',
    --- Optional but recommended for nicer inputs
    --- 'folke/noice.nvim',
  },
  --- See config example below
  opts = {}
}
```

## Example setup with dir specific configs

```lua
{
  'duckdm/neowarrior.nvim',
  event = 'VeryLazy',
  dependencies = {
    'nvim-telescope/telescope.nvim',
    --- Optional but recommended for nicer inputs
    --- 'folke/noice.nvim',
  },
  config = function()

    local nw = require('neowarrior')
    local home = vim.env.HOME
    nw.setup({
      report = "next",
      filter = "\\(due.before:2d or due: \\)",
      dir_setup = {
        {
          dir = home .. "/dev/nvim/neowarrior.nvim",
          filter = "project:neowarrior",
          mode = "tree",
          expanded = true,
        },
      }
    })
    vim.keymap.set("n", "<leader>nl", function() nw.open_left() end, { desc = "Open nwarrior on the left side" })
    vim.keymap.set("n", "<leader>nc", function() nw.open_current() end, { desc = "Open nwarrior below current buffer" })
    vim.keymap.set("n", "<leader>nb", function() nw.open_below() end, { desc = "Open nwarrior below current buffer" })
    vim.keymap.set("n", "<leader>na", function() nw.open_above() end, { desc = "Open nwarrior above current buffer" })
    vim.keymap.set("n", "<leader>nr", function() nw.open_right() end, { desc = "Open nwarrior on the right side" })
    vim.keymap.set("n", "<leader>nt", function() nw.focus() end, { desc = "Focus nwarrior" })
  end
}
```

# Available commands

| Command | Description |
| ------- | ----------- |
| `:NeoWarriorOpen` | Open NeoWarrior (default to below current buffer) |
| `:NeoWarriorOpen float` | Open NeoWarrior in a floating window |
| `:NeoWarriorOpen current` | Open NeoWarrior in current buffer |
| `:NeoWarriorOpen left` | Open NeoWarrior to the left of current window |
| `:NeoWarriorOpen right` | Open NeoWarrior to the right of current window |
| `:NeoWarriorOpen above` | Open NeoWa
```