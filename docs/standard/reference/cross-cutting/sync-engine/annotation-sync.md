# lib/annotation-sync.sh

**Type:** Sourced bash library
**Part of:** GitHub Sync Engine — see `cross-cutting/sync-engine/overview.md`
**Fragility:** HIGH — duplicate comment risk on repeated runs

---

## Role

Bidirectional sync of TaskWarrior annotations and GitHub issue comments. Annotations are the TW side; comments are the GitHub side. Each sync run must detect only *new* annotations/comments since the last sync to avoid duplicating existing ones.

---

## Functions

**`sync_annotations_to_comments(task_uuid, issue_number, repo)`**
Called during push. Detects annotations added since last sync (via `detect_new_annotations()` in `sync-detector.sh`). For each new annotation, calls `github_add_comment()`. Stores the returned comment ID in sync state to prevent re-posting.

**`sync_comments_to_annotations(task_uuid, issue_number, repo)`**
Called during pull. Detects comments added since last sync (via `detect_new_comments()`). For each new comment, calls `tw_add_annotation()` with the comment body prefixed with `[GitHub @author]:`.

**`sync_annotations_bidirectional(task_uuid, issue_number, repo)`**
Calls both directions. Used by `sync_task_bidirectional()` in `sync-bidirectional.sh`.

---

## Deduplication

The sync state JSON stores a list of already-synced annotation IDs and comment IDs. Before posting, each item is checked against this list. This prevents the most common failure mode: re-running sync after a partial failure re-posts all annotations as new comments.

---

## Format

Annotations synced to GitHub comments are prefixed with `[TaskWarrior]:` to distinguish them from human comments. Comments synced to TW annotations are prefixed with `[GitHub @<author>]:`.

## Changelog

- 2026-04-10 — Initial version
