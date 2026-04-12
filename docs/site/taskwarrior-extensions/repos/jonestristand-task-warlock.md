# jonestristand/task-warlock

**URL:** https://github.com/jonestristand/task-warlock  
**Stars:** 4  
**Language:** TypeScript  
**Last push:** 2026-02-21  
**Archived:** No  
**Topics:** taskwarrior, taskwarrior-web, taskwarrior3  

## Description

A modern, beautiful web interface for TaskWarrior with multiple themes and real-time task management

## Category

Sync

## Workwarrior Integration Rating

**Score:** 9  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +2: Hook-based — ww can install hooks per profile
- +2: Sync capability relevant to ww profile isolation
- +2: Urgency coefficients are a ww UDA focus area
- +1: Shell scripting — matches ww stack
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos

## README excerpt

```
# TaskWarlock 🧙‍♂️

A modern, beautiful web interface for [TaskWarrior](https://taskwarrior.org/) built with Next.js 15, React, and TypeScript. Manage your tasks with a sleek UI featuring multiple theme options, real-time filtering, and inline editing.

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)

## ✨ Features

- **Beautiful Themes** - 14+ carefully crafted themes including Catppuccin, Kanagawa, Rose Pine, Dracula, Tokyo Night, One Dark, Everforest, and Nord
- **Real-time Task Management** - Add, edit, complete, and restore tasks with instant feedback
- **Smart Filtering** - Filter by project, tags, and completion status
- **Inline Editing** - Click any task row to edit all fields in place
- **Priority & Urgency** - Visual priority indicators and urgency-based font weights
- **Tag Management** - Easy tag selection with autocomplete
- **Responsive Design** - Works seamlessly on desktop and mobile
- **Docker Support** - Pre-configured Dockerfile and docker-compose.yml for easy deployment
- **No Flicker Loading** - Theme persistence and skeleton loaders for smooth UX

## 🚀 Quick Start

### Prerequisites

- Node.js 22+ or Docker
- TaskWarrior 3.4.2+ installed locally (for development without Docker)

### Development

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/taskwarlock.git
cd taskwarlock
```

2. **Install dependencies**
```bash
npm install
```

3. **Run the development server**
```bash
npm run dev
```

4. **Open your browser**
Navigate to [http://localhost:3000](http://localhost:3000)

### Docker Deployment

1. **Build the image**
```bash
docker build -t taskwarlock:latest .
```

2. **Run with docker-compose**
```bash
docker-compose up -d
```

3. **Or run directly**
```bash
docker run -p 3000:3000 \
  -v ./taskwarrior-data:/home/nextjs/.task \
  taskwarlock:latest
```

The Docker image includes:
- TaskWarrior 3.4.2 pre-installed
- Default `.taskrc` with `data.location` and `recurrence=off`
- Automatic cron-based sync (every 5 minutes)
- Persistent data storage via volume mounts

### Persisting Settings

To persist your theme and app settings across container restarts, map the settings directory:

```bash
docker run -p 3000:3000 \
  -v ./taskwarrior-data:/home/nextjs/.task \
  -v ./taskwarlock-settings:/root/.taskwarlock \
  taskwarlock:latest
```

Or in `docker-compose.yml`:
```yaml
services:
  taskwarlock:
    volumes:
      - ./taskwarrior-data:/home/nextjs/.task
      - ./taskwarlock-settings:/root/.taskwarlock
```

This will persist:
- Selected theme preference
- UI settings and preferences
- Filter states

See `docker-compose.yml` for more configuration options.

## 🎨 Themes

TaskWarlock includes 14 beautiful themes:

**Dark Themes:**
- Catppuccin Mocha 🌙
- Dracula 🧛
- Everforest 🌲
- Kanagawa Wave 🌊
- Kanagawa Dragon 🐉
- Nord 🌌
- One Dark ⚛️
- Rose Pine 🌹
- Rose Pine Moon 🌕
- Tokyo Night 🌃

**Light Themes:**
- Catppuccin Latte ☕
- Kanagawa Lotus 🪷
- Nord Light ☀️
- Rose Pine Dawn 🌸

Th
```