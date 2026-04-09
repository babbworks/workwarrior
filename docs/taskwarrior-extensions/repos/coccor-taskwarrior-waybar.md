# coccor/taskwarrior-waybar

**URL:** https://github.com/coccor/taskwarrior-waybar  
**Stars:** 4  
**Language:** Shell  
**Last push:** 2025-10-26  
**Archived:** No  
**Topics:** arch, omarchy, taskwarrior, waybar  

## Description

A beautiful, modern integration between Taskwarrior and Waybar for managing tasks directly from your status bar.

## Category

Hooks

## Workwarrior Integration Rating

**Score:** 12  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +3: Uses TimeWarrior — already integrated in ww
- +2: Urgency coefficients are a ww UDA focus area
- +1: Shell integration — ww is shell-first
- +1: Shell scripting — matches ww stack
- +2: JRNL is part of ww toolchain
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration

## README excerpt

```
# Taskwarrior Waybar Integration

A beautiful, modern integration between [Taskwarrior](https://taskwarrior.org/) and [Waybar](https://github.com/Alexays/Waybar) for managing tasks directly from your status bar.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Shell](https://img.shields.io/badge/shell-bash-green.svg)

## Features

- 📋 **Status Display** - View up to 10 upcoming tasks sorted by due date
- 🎨 **Modern Styling** - Color-coded by urgency with priority indicators
- ➕ **Quick Add** - Add tasks with natural language due dates (5min, 1h, tomorrow)
- ✅ **Easy Completion** - Mark tasks as done with a simple interface
- 🔔 **Smart Notifications** - Get alerted 5 minutes before tasks are due
- 🕐 **Human-Friendly Times** - "today in 2h", "tomorrow at 14:30", "3d ago"
- 🌍 **Timezone Aware** - Correctly handles UTC timestamps from Taskwarrior

## Screenshots
![screenshot1](/assets/image.png)

### Tooltip Display
```
📋 Tasks (4 pending, 1 overdue)

● Project review     ⏰ today 30m ago     [overdue, high priority]
● Team meeting       📅 today in 2h15m    [due today]
  Code deployment    📅 tomorrow at 09:00
  Write documentation  in 3d
```

### Notifications
- Proactive alerts 5 minutes before tasks are due
- Shows overdue count and upcoming tasks
- Formatted list with humanized times

## Installation

### Prerequisites

- [Taskwarrior](https://taskwarrior.org/) - Task management tool
- [Waybar](https://github.com/Alexays/Waybar) - Status bar for Wayland
- `jq` - JSON processor
- `libnotify` - Desktop notifications
- A terminal emulator (default: `alacritty`)

On Arch Linux:
```bash
sudo pacman -S task waybar jq libnotify alacritty
```

### Quick Install

```bash
git clone https://github.com/coccor/taskwarrior-waybar.git ~/Work/taskwarrior-waybar
cd ~/Work/taskwarrior-waybar
./install.sh
```

The installer will:
1. Check for required dependencies
2. Install scripts to `~/.config/waybar/scripts/`
3. Install systemd units for notifications
4. Enable and start the notification timer

### Manual Installation

1. **Copy scripts:**
   ```bash
   cp scripts/* ~/.config/waybar/scripts/
   chmod +x ~/.config/waybar/scripts/taskwarrior-*.sh
   chmod +x ~/.config/waybar/scripts/humanize-date.sh
   ```

2. **Install systemd units:**
   ```bash
   cp systemd/* ~/.config/systemd/user/
   systemctl --user daemon-reload
   systemctl --user enable --now taskwarrior-notify.timer
   ```

3. **Configure Waybar** - Add to your `~/.config/waybar/config.jsonc`:

   Add to `modules-center`, `modules-left`, or `modules-right`:
   ```json
   "custom/taskwarrior-status"
   ```

   Add the module configuration:
   ```json
   "custom/taskwarrior-status": {
     "format": "{icon}",
     "format-icons": {
        "default": "  ",
        "due": "  !"
     },
     "return-type": "json",
     "exec": "$HOME/.config/waybar/scripts/taskwarrior-status.sh",
     "interval": 60,
     "tooltip": true,
     "on-click": "alacritty -e bash -c '$HOME/.config/waybar/scripts/
```