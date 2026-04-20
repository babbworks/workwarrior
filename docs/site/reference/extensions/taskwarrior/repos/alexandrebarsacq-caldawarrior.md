# alexandrebarsacq/caldawarrior

**URL:** https://github.com/alexandrebarsacq/caldawarrior  
**Stars:** 0  
**Language:** Rust  
**Last push:** 2026-03-19  
**Archived:** No  
**Topics:** caldav, synchronization, taskwarrior, vtodo  

## Description

Sync CalDAV VTODO and Taskwarrior

## Category

Sync

## Workwarrior Integration Rating

**Score:** 11  
**Rating:** ★★★★★  Essential  

### Scoring notes

- +2: Sync capability relevant to ww profile isolation
- +3: UDAs — core to ww service model
- +1: Shell scripting — matches ww stack
- +1: Reporting is a ww surface area
- +1: GitHub is ww's primary issue source
- +1: CLI-first matches ww ethos
- +1: Import/export useful for profile migration
- +1: Python — tooling language used in ww

## README excerpt

```
# WARNING
THIS IS "VIBE"-CODED. USE AT YOUR OWN RISKS

# caldawarrior

Bidirectional sync between [TaskWarrior](https://taskwarrior.org/) and CalDAV VTODO calendars.

caldawarrior is a CLI tool written in Rust that keeps your TaskWarrior tasks in sync with any
CalDAV-compatible server (Nextcloud, Radicale, Fastmail, iCloud, Baikal, etc.).
Each configured calendar collection maps to a TaskWarrior project; the tool performs a
three-step pipeline — IR construction, dependency resolution, write-back — using last-write-wins
conflict resolution.

## Features

- Bidirectional sync: changes on either side are propagated
- Project-to-calendar mapping via config (one or more calendars)
- Last-write-wins conflict resolution on a per-task basis
- Dry-run mode (`--dry-run`) to preview changes without writing
- Custom `caldavuid` UDA tracks the CalDAV identity of each task
- TLS strict by default (rustls); optional insecure mode for self-signed certificates
- Password override via environment variable for CI/scripting
- Runtime warning when config file permissions exceed 0600

## Installation

### Pre-built Binary (Recommended)

Download the latest release for x86_64 Linux:

```bash
# Download binary and checksum
curl -LO https://github.com/alexandrebarsacq/caldawarrior/releases/latest/download/caldawarrior-v1.0.0-x86_64-linux
curl -LO https://github.com/alexandrebarsacq/caldawarrior/releases/latest/download/caldawarrior-v1.0.0-x86_64-linux.sha256

# Verify checksum
sha256sum -c caldawarrior-v1.0.0-x86_64-linux.sha256

# Install
chmod +x caldawarrior-v1.0.0-x86_64-linux
sudo mv caldawarrior-v1.0.0-x86_64-linux /usr/local/bin/caldawarrior
```

Check the [Releases page](https://github.com/alexandrebarsacq/caldawarrior/releases) for the latest version.

### cargo install

```bash
cargo install --git https://github.com/alexandrebarsacq/caldawarrior.git
```

### Build from Source

```bash
git clone https://github.com/alexandrebarsacq/caldawarrior.git
cd caldawarrior
cargo build --release
# binary is at target/release/caldawarrior
```

## Quick Start

**Step 1 — Configure** (with security note)

Create the config directory and file:

```bash
mkdir -p ~/.config/caldawarrior
touch ~/.config/caldawarrior/config.toml
chmod 0600 ~/.config/caldawarrior/config.toml   # IMPORTANT: restrict permissions
```

Edit `~/.config/caldawarrior/config.toml`:

```toml
server_url = "https://dav.example.com"
username   = "alice"
password   = "hunter2"

[[calendar]]
project = "default"
url     = "https://dav.example.com/alice/default/"

[[calendar]]
project = "work"
url     = "https://dav.example.com/alice/work/"
```

The tool emits a `[WARN]` to stderr at startup if the config file is more permissive than
`0600` on Unix systems. Do not store this file in version control.

**Step 2 — Register the TaskWarrior UDA**

caldawarrior uses a custom User Defined Attribute (`caldavuid`) to track which CalDAV VTODO each
task corresponds to. Register it once:

```bash
task config uda.caldavuid.type
```