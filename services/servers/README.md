# Servers Service

Multi-device synchronization and server management for Workwarrior.

## Scope

This service manages:
1. **TaskChampion sync** — TaskWarrior's built-in sync protocol for task data
2. **TimeWarrior sync** — via timew-sync-server/client (extension)
3. **Server configuration** — connection settings, credentials, sync schedules

## TaskChampion Integration

TaskWarrior 3.x uses TaskChampion as its storage backend, which supports
synchronization via a server. The sync protocol is built into TaskWarrior
itself — no external tool needed for task sync.

### User Experience Goals

- One-command setup: `ww server setup` configures sync for the active profile
- Automatic sync: `ww server enable` sets up periodic sync
- Status visibility: `ww server status` shows sync state per profile
- Conflict resolution: clear messaging when conflicts occur
- Mobile readiness: server config compatible with future mobile clients

### Architecture

```
profiles/<name>/.taskrc
  → sync.server.url=<url>
  → sync.server.client_id=<uuid>
  → sync.encryption_secret=<key>
```

TaskChampion handles the actual sync. ww provides:
- Configuration management (server URL, credentials)
- Per-profile isolation (each profile syncs independently)
- Status monitoring and error surfacing
- Browser UI panel for sync management

## CLI (Future)

```
ww server setup              Configure sync for active profile
ww server enable             Enable automatic sync
ww server disable            Disable sync
ww server status             Show sync state
ww server sync               Manual sync trigger
ww server help               Show help
```

## Browser UI

The Sync panel in the browser provides visual sync management.

## Task Card

TASK-TC-001 (parked — requires design review)
