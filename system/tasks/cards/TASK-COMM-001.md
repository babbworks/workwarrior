## TASK-COMM-001: Community service storage layer — community.db schema + migrations

Goal:                 Create the SQLite database schema for the community service.
                      community.db lives at $WW_BASE/.community/community.db (global,
                      not per-profile). This is the foundational dependency for all
                      other COMM tasks.

Acceptance criteria:  (pending Gate A sign-off before dispatch)
                      1. community.db created at $WW_BASE/.community/community.db on
                         first community service invocation
                      2. Schema includes tables: communities, community_entries,
                         community_comments, rejournal_index
                      3. community_entries has fields: id, community_id, source_ref
                         (format: {profile}.task.{uuid} or {profile}.journal.{date-slug}),
                         captured_state (JSON blob), added_at, community_tags,
                         community_priority, is_community_derivative (bool)
                      4. community_comments has fields: id, entry_id, body, created_at,
                         community_name_prefix (bool), copied_to_source (bool)
                      5. Schema versioned with migrations table; migration runs idempotently
                      6. lib/community-db.sh provides open_community_db(), run_migration()
                         helpers following existing lib conventions

Write scope:          (pending Gate A)
                      lib/community-db.sh (new)
                      $WW_BASE/.community/ directory creation logic

Tests required:       (pending Gate A)
                      bats tests/test-community-storage.bats (new)

Rollback:             rm -rf $WW_BASE/.community/
                      git rm lib/community-db.sh

Fragility:            Low — new files only, no existing lib or bin/ww changes

Risk notes:           (Orchestrator) Global storage path must not collide with any
                      profile path. $WW_BASE/.community/ is clear of all existing paths.

Status:               complete — 2026-04-27 (services/community/community_store.py + lib/community-db.sh; full schema with communities/community_entries/community_comments/rejournal_index + migration runner; confirmed by COMM-002..007 all marked complete)
Taskwarrior:          wwdev task 8 (c5a14e24-4705-46ae-aab4-c1fdafe8c9f6) status:completed
