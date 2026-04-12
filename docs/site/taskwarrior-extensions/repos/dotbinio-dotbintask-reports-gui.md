# dotbinio/dotbintask-reports-gui

**URL:** https://github.com/dotbinio/dotbintask-reports-gui  
**Stars:** 0  
**Language:** TypeScript  
**Last push:** 2026-01-10  
**Archived:** No  
**Topics:** taskwarrior, taskwarrior3  

## Description

GUI for taskwarrior

## Category

TUI / Interactive

## Workwarrior Integration Rating

**Score:** 2  
**Rating:** ★★★☆☆  Medium  

### Scoring notes

- +1: Shell scripting — matches ww stack
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- -2: GUI/browser — not ww-native

## README excerpt

```
# DotbinTask

> **⚠️ UNDER CONSTRUCTION**: This project is currently in active development and is **not ready for production use**. Features may change without notice. Use at your own risk.

A modern, lightweight Progressive Web App (PWA) for accessing your Taskwarrior tasks from anywhere.

![DotbinTask Screenshot](docs/screenshot.png)
<!-- TODO: Add screenshot -->

## About

[Taskwarrior](https://taskwarrior.org/) is a powerful CLI-based task management tool that follows the Unix philosophy - do one thing and do it well. It excels at managing tasks through the command line with extensive features and customization.

**DotbinTask** extends Taskwarrior to the web while maintaining the same philosophy. It doesn't replace the CLI or duplicate functionality - instead, it provides web-based access to your existing Taskwarrior setup, respecting your configurations and workflow.

### Architecture

DotbinTask consists of two independent components, each focused on doing one thing well:

**1. [DotbinTask API](https://github.com/dotbinio/dotbintask-api)** - A headless REST API that wraps Taskwarrior CLI. Provides programmatic access for building UIs, mobile apps, or integrations.

**2. DotbinTask GUI (This Project)** - A web-based PWA frontend. Report-centric interface that reads configurations directly from your `.taskrc` and displays tasks exactly as Taskwarrior would.

## Quick Start


### Full Stack Setup (API + Frontend)

Create a `docker-compose.yml`:

```yaml
services:
  # Backend API
  api:
    image: ghcr.io/dotbinio/dotbintask-api:latest
    environment:
      - TW_API_TOKENS=your-secret-token-here
    volumes:
      - ~/.task:/root/.task

  # Frontend GUI
  frontend:
    image: ghcr.io/dotbinio/dotbintask-reports-gui:latest

  # Nginx proxy - routes /api to backend, / to frontend
  proxy:
    image: nginx:alpine
    ports:
      - "3000:80"
    volumes:
      - ./nginx-proxy.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - api
      - frontend
```

Create `nginx-proxy.conf`:

```nginx
server {
    listen 80;

    # API routes
    location /api/ {
        proxy_pass http://api:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /health {
        proxy_pass http://api:8080;
    }

    # Frontend routes
    location / {
        proxy_pass http://frontend:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Start everything:

```bash
docker-compose up -d
```

Access at: **http://localhost:3000**

Enter your API token: `your-secret-token-here`

### Run UI Only with Docker

For standalone frontend (requires API running elsewhere):

```bash
docker run -d \
  -p 3000:80 \
  --name dotbintask-gui \
  ghcr.io/dotbinio/dotbintask-reports-gui:latest
```

**Note**: Configure API URL in your browser when prompted, or see Full Stack Setup above for a complete solution.

## Features

- 📊 **Report-based** - View all your Taskwarrior reports
```