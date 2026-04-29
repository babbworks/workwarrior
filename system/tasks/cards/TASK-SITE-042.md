---
id: TASK-SITE-042
title: CMD log UI — control panel, collapse, and clear past entries
status: pending
priority: L
area: browser
created: 2026-04-27
tw_uuid: 500f3268
---

## Goal

The CMD section accumulates log entries indefinitely with no way to manage them. Add controls to collapse/expand individual command log entries, clear the session log, and optionally pin or dismiss entries.

## Context

`services/browser/server.py` writes command output to `cmd.log` via the `_handle_data_cmd_log` endpoint. The CMD section in app.js (`loadCmdLog`) renders all lines as a flat stream. On long sessions this becomes unusable — hundreds of entries with no hierarchy or control.

## Acceptance Criteria

- [ ] Each command log entry group has a collapse/expand toggle (default expanded for most-recent, collapsed for older)
- [ ] "Clear session log" button wipes the in-memory/file cmd log (not a destructive disk operation — session only)
- [ ] Individual entries can be dismissed (hidden from view without clearing the log)
- [ ] Most-recent entry always auto-scrolls into view on new output
- [ ] Empty state shows "No commands yet this session"
- [ ] Controls don't affect CMD input behavior

## Write Scope

- `services/browser/static/app.js` — loadCmdLog renderer, entry DOM structure
- `services/browser/server.py` — optional: cmd log clear endpoint
- `services/browser/static/style.css` — collapsed state, control buttons
- `services/browser/static/index.html` — clear button element

## Risk

Low. Purely UI enhancement; no data mutation.

## Rollback

Revert app.js loadCmdLog. No server-side changes required for MVP.

## Status

complete — 2026-04-27. _dismissedCmdLog Set for session-only dismiss; collapse/expand per entry (most-recent expanded, rest collapsed); dismiss × button per entry; clear button wipes all visible entries from view; empty state "No commands yet this session". No server changes needed.
