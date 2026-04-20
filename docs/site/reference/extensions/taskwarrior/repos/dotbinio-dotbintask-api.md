# dotbinio/dotbintask-api

**URL:** https://github.com/dotbinio/dotbintask-api  
**Stars:** 0  
**Language:** Go  
**Last push:** 2026-01-09  
**Archived:** No  
**Topics:** taskwarrior, taskwarrior3  

## Description

HTTP Apiserver for taskwarrior. Use this to build your own UI for taskwarrior

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
# Taskwarrior API Server

> **⚠️ UNDER CONSTRUCTION**: This project is currently in active development and is **not ready for production use**. APIs may change without notice. Use at your own risk.

A headless REST API server for [Taskwarrior](https://taskwarrior.org/), providing a clean HTTP interface to interact with your tasks programmatically.

## Overview

This server acts as a bridge between Taskwarrior's powerful CLI and modern applications, allowing you to:

- Build web, mobile, or desktop UIs for Taskwarrior
- Integrate Taskwarrior with other tools and services
- Access your tasks from anywhere via HTTP
- Keep Taskwarrior as the single source of truth (no database duplication)

### Key Features

- **CLI-Only Integration**: Uses Taskwarrior CLI exclusively - no direct file manipulation
- **RESTful API**: Clean, predictable HTTP endpoints
- **Token Authentication**: Simple bearer token authentication
- **Sync-Friendly**: Compatible with Taskwarrior sync or file syncing (Syncthing, etc.)
- **No State Duplication**: All data lives in Taskwarrior

## Installation

### Prerequisites

- Go 1.21 or higher
- Taskwarrior installed and configured (`task` command available)

### Quick Start

```bash
# Clone the repository
git clone https://github.com/dotbinio/taskwarrior-api.git
cd taskwarrior-api

# Install dependencies
make install

# Set required environment variable
export TW_API_TOKENS="your-secret-token"

# Build and run
make build
./bin/taskwarrior-api
```

The server will start on `http://localhost:8080`

**Access Swagger UI**: Open `http://localhost:8080/swagger/index.html` in your browser

## Embedded Example UI

A read-only web UI is available for viewing tasks and reports. This is intended as an example/development tool and is **enabled by default**.

### Accessing the UI

Simply start the server and open `http://localhost:8080/` in your browser.

### Disabling the UI

If you want to disable the UI (e.g., for production):

```bash
export TW_API_ENABLE_UI=false
./bin/taskwarrior-api
```

### Features

- Read-only interface for viewing tasks
- Dynamic report viewer using Taskwarrior's report configurations
- Displays tasks using each report's configured columns and labels
- Clean, minimal styling with Pico CSS
- No build step required (all dependencies via CDN)

### Security Notes

- **Enabled by default** - Can be disabled via `TW_API_ENABLE_UI=false`
- Requires valid API token (stored in browser session only)
- Read-only - cannot create, modify, or delete tasks
- Recommended for development and internal use
- Consider using a reverse proxy with additional authentication for external access

### Building from Source

```bash
# Clone the repository
git clone https://github.com/dotbinio/taskwarrior-api.git
cd taskwarrior-api

# Install dependencies
make install

# Build the binary
make build

# The binary will be available at ./bin/taskwarrior-api
```

### Running

```bash
# Run directly with Go
make run

# Or run the built binary
./bin/tas
```