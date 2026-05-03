---
id: TASK-SVC-008
title: Rename bookbuilder → saves everywhere; add ww saves CLI
status: pending
priority: H
area: cli browser
created: 2026-04-27
---

## Goal

"Bookbuilder" is the internal tool name. The user-facing name is "saves". Rename throughout: service directory, browser section id/title/nav, keyboard shortcut, CLI command. Add `ww saves` routing in bin/ww.

## Acceptance Criteria

- [ ] `services/bookbuilder/` renamed to `services/saves/`
- [ ] Browser: section id `section-bookbuilder` → `section-saves`, title "BookBuilder" → "Saves", all JS references updated
- [ ] Keyboard shortcut: `saves` maps to `saves` section (currently routes to `bookbuilder`)
- [ ] `ww saves [status|search|add|run|inbox]` routes to saves service
- [ ] `ww saves help` shows usage
- [ ] bin/ww `show_usage` lists `saves` in the command table
- [ ] No remaining references to `bookbuilder` in browser-facing UI strings

## Write Scope

- `services/bookbuilder/` → `services/saves/` (directory rename)
- `services/browser/static/app.js`
- `services/browser/static/index.html`
- `services/browser/static/style.css`
- `bin/ww`
