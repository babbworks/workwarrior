# OsamaMahmood/lazytask

**URL:** https://github.com/OsamaMahmood/lazytask  
**Stars:** 8  
**Language:** Rust  
**Last push:** 2026-02-09  
**Archived:** No  
**Topics:** lazytask, taskwarrior, taskwarrior3  

## Description

Simple terminal UI for taskwarrior : lazytask inspired by lazygit

## Category

Sync

## Workwarrior Integration Rating

**Score:** 9  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +2: Urgency coefficients are a ww UDA focus area
- +1: Shell scripting — matches ww stack
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration

## README excerpt

```
# LazyTask - Modern Terminal UI for Taskwarrior

A modern, responsive Terminal User Interface (TUI) for Taskwarrior, built with Rust and Ratatui. LazyTask provides an intuitive, keyboard-driven interface similar to popular TUIs like Lazygit and Yazi.

<img width="1561" height="977" alt="image" src="https://github.com/user-attachments/assets/0441da8f-e2ea-483d-ba4f-2ec61ad75fd9" />
<img width="1561" height="977" alt="image" src="https://github.com/user-attachments/assets/761e174a-fe67-4987-aab4-3d5821b42b73" />

## Features

LazyTask is now a complete, modern Terminal User Interface for Taskwarrior with professional-grade features and polish.

### ✅ **Core Task Management**

- **Complete CRUD Operations**: Add, edit, delete, and complete tasks with full Taskwarrior sync
- **Advanced Task Forms**: Modal dialogs with project, priority, due date, tags, and description fields
- **Smart Selection**: UUID-based task selection that persists across operations
- **Tag Management**: Full tag editing with proper add/remove functionality
- **Task Details**: Comprehensive task information display in dedicated detail panel

### ✅ **Modern User Interface**

- **Responsive Design**: Automatic layout adaptation for different terminal sizes
- **Task List with Integrated Filters**: Main view with task list and inline filter panel
- **Professional Theming**: Catppuccin color scheme with priority-based color coding
- **Auto-Resize**: Seamless UI updates when terminal window is resized
- **Modal System**: Clean, professional forms and dialogs

### ✅ **Advanced Filtering System**

- **Interactive Filter Bar**: Real-time filtering with immediate preview
- **Status Filters**: All, Pending, Active, Overdue, Completed, Waiting, Deleted
- **Computed Filters**: Smart Active (started tasks) and Overdue (past due) detection
- **Multi-Criteria**: Filter by project, priority, tags, and description simultaneously
- **Keyboard Navigation**: Full keyboard control with intuitive shortcuts

### ✅ **Professional Reports Dashboard**

- **Dual Mode Interface**: Toggle between Dashboard and Calendar views
- **Dashboard Mode**:
  - Modern 4-panel layout: Summary, Burndown, Project Analytics, Recent Activity
  - Real-time statistics: task counts, completion rates, priority breakdown
  - Project analytics: detailed per-project stats with progress tracking
  - Activity timeline: recent task changes with detailed activity types
- **Calendar Mode**:
  - 3-month horizontal calendar view (previous, current, next month)
  - Task indicators on dates: ⚠ overdue, • pending, ✓ completed, ○ other
  - Daily task details with status breakdown including deleted tasks
  - Full keyboard navigation: arrows for days/weeks, <>for months, 't' for today
- **Performance Optimized**: Smart caching system eliminates flickering
- **Responsive Layout**: Adaptive charts and panels based on terminal size

### ✅ **Complete Taskwarrior Integration**

- **Full JSON Parsing**: Complete support for all Taskwarrior datetime 
```