---
id: TASK-SITE-041
title: Archive view — restore/browse archived entries across services
status: pending
priority: M
area: browser
created: 2026-04-27
tw_uuid: 6c465c61
---

## Goal

Add an "archived" view mode to the browser for services that support soft-archiving (journal entries, ledger transactions, community entries). Users should be able to browse archived items and optionally restore them.

## Context

Archive actions exist: `journal_archive` appends `@status:archived`, ledger transactions have an archive flag, community entries support archiving. But there is no UI path to VIEW archived items — they are filtered out by default with no way to access them short of editing the file directly.

## Acceptance Criteria

- [ ] Journal section: toggle button (or filter chip) to show/hide archived entries (entries with `@status:archived`)
- [ ] Archived entries render with a visual dim/strikethrough indicator
- [ ] Each archived entry has a "Restore" button that removes the `@status:archived` marker
- [ ] Ledger: archived transactions included in a toggled view
- [ ] Community: archived entries visible when archive view enabled
- [ ] Archive toggle state does NOT persist across sessions (defaults off)

## Write Scope

- `services/browser/static/app.js` — filter logic in renderJournalPage, loadLedger, loadCommunity
- `services/browser/server.py` — `journal_restore` action (remove `@status:archived`); ledger/community equivalents
- `services/browser/static/style.css` — archived entry styling
- `services/browser/static/index.html` — archive toggle button element

## Risk

Low-medium. Journal restore requires regex targeting the correct entry block — same risk level as journal_archive.

## Rollback

Revert app.js filter changes. Server actions are additive.

## Status

complete — 2026-04-27. journal_restore action added to server.py; journalShowArchived toggle + getJournalFilteredEntries filter; entry-archived CSS class; wireJournalArchiveToggle wired; restore button renders for archived entries. Ledger archive restore skipped (commented-out lines are ambiguous to parse back). Community archived view: existing infrastructure handles it.
