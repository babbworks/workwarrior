#!/usr/bin/env python3
"""
SQLite access for global community.db (shared with services/community/community.sh).

source_ref: {profile}.task.{uuid} | {profile}.journal.{date_slug}
date_slug: YYYY-MM-DD_HH-MM derived from journal header [YYYY-MM-DD HH:MM]
"""
from __future__ import annotations

import json
import os
import re
import sqlite3
import sys
from typing import Any

COMMUNITY_DDL = """
CREATE TABLE IF NOT EXISTS schema_migrations (
  version INTEGER PRIMARY KEY
);
CREATE TABLE IF NOT EXISTS communities (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS community_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  community_id INTEGER NOT NULL,
  source_ref TEXT NOT NULL,
  captured_state TEXT NOT NULL DEFAULT '{}',
  added_at TEXT NOT NULL DEFAULT (datetime('now')),
  community_tags TEXT,
  community_priority TEXT,
  community_project TEXT,
  is_community_derivative INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (community_id) REFERENCES communities(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS community_comments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entry_id INTEGER NOT NULL,
  body TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  community_name_prefix INTEGER NOT NULL DEFAULT 0,
  copied_to_source INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (entry_id) REFERENCES community_entries(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS rejournal_index (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entry_id INTEGER NOT NULL,
  original_ref TEXT,
  FOREIGN KEY (entry_id) REFERENCES community_entries(id) ON DELETE CASCADE
);
"""


def db_path(ww_base: str) -> str:
    return os.path.join(ww_base, ".community", "community.db")


def connect(ww_base: str) -> sqlite3.Connection:
    path = db_path(ww_base)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.executescript(COMMUNITY_DDL)
    # Migrate: add community_project if the column doesn't exist yet
    try:
        conn.execute("ALTER TABLE community_entries ADD COLUMN community_project TEXT")
        conn.commit()
    except Exception:
        pass
    return conn


def list_communities(ww_base: str) -> dict[str, Any]:
    conn = connect(ww_base)
    try:
        rows = conn.execute(
            """
            SELECT c.name, COUNT(e.id) AS cnt FROM communities c
            LEFT JOIN community_entries e ON e.community_id = c.id
            GROUP BY c.id ORDER BY c.name
            """
        ).fetchall()
        return {"ok": True, "communities": [{"name": r["name"], "entry_count": int(r["cnt"])} for r in rows]}
    finally:
        conn.close()


def show_community(ww_base: str, name: str) -> dict[str, Any]:
    conn = connect(ww_base)
    try:
        row = conn.execute("SELECT id, name FROM communities WHERE name=?", (name,)).fetchone()
        if not row:
            return {"ok": False, "error": "community not found", "name": name, "entries": []}
        cid = row["id"]
        erows = conn.execute(
            """
            SELECT id, source_ref, captured_state, added_at, community_tags,
                   community_priority, community_project, is_community_derivative
            FROM community_entries WHERE community_id=? ORDER BY datetime(added_at) DESC
            """,
            (cid,),
        ).fetchall()
        entries = []
        for er in erows:
            crows = conn.execute(
                """
                SELECT id, body, created_at, community_name_prefix, copied_to_source
                FROM community_comments WHERE entry_id=? ORDER BY datetime(created_at)
                """,
                (er["id"],),
            ).fetchall()
            try:
                cap = json.loads(er["captured_state"] or "{}")
            except json.JSONDecodeError:
                cap = {"_raw": er["captured_state"]}
            entries.append(
                {
                    "id": er["id"],
                    "source_ref": er["source_ref"],
                    "captured_state": cap,
                    "added_at": er["added_at"],
                    "community_tags": er["community_tags"],
                    "community_priority": er["community_priority"],
                    "community_project": er["community_project"],
                    "is_community_derivative": bool(er["is_community_derivative"]),
                    "comments": [
                        {
                            "id": c["id"],
                            "body": c["body"],
                            "created_at": c["created_at"],
                            "community_name_prefix": bool(c["community_name_prefix"]),
                            "copied_to_source": bool(c["copied_to_source"]),
                        }
                        for c in crows
                    ],
                }
            )
        return {"ok": True, "name": name, "entries": entries}
    finally:
        conn.close()


def create_community(ww_base: str, name: str) -> dict[str, Any]:
    conn = connect(ww_base)
    try:
        conn.execute("INSERT INTO communities (name) VALUES (?)", (name,))
        conn.commit()
        return {"ok": True, "name": name}
    except sqlite3.IntegrityError:
        return {"ok": False, "error": "community already exists", "name": name}
    finally:
        conn.close()


def journal_date_to_slug(date_header: str) -> str:
    """[YYYY-MM-DD HH:MM] body -> slug YYYY-MM-DD_HH-MM (colons to hyphens)."""
    s = date_header.strip()
    return s.replace(" ", "_").replace(":", "-")


def parse_journal_entries(content: str) -> list[dict[str, str]]:
    parts = re.split(r"\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\]", content)
    entries: list[dict[str, str]] = []
    for i in range(1, len(parts) - 1, 2):
        date = parts[i]
        body = parts[i + 1].strip()
        if body:
            entries.append({"date": date, "body": body})
    return entries


def add_entry(
    ww_base: str,
    community_name: str,
    source_ref: str,
    captured: dict[str, Any],
    community_tags: str | None = None,
    community_priority: str | None = None,
    community_project: str | None = None,
) -> dict[str, Any]:
    conn = connect(ww_base)
    try:
        row = conn.execute("SELECT id FROM communities WHERE name=?", (community_name,)).fetchone()
        if not row:
            return {"ok": False, "error": "community not found"}
        cid = row["id"]
        dup = conn.execute(
            "SELECT id FROM community_entries WHERE community_id=? AND source_ref=?",
            (cid, source_ref),
        ).fetchone()
        if dup:
            return {"ok": False, "error": "already in community", "entry_id": int(dup["id"])}
        payload = json.dumps(captured, ensure_ascii=False)
        cur = conn.execute(
            """INSERT INTO community_entries
               (community_id, source_ref, captured_state, community_tags, community_priority, community_project)
               VALUES (?,?,?,?,?,?)""",
            (cid, source_ref, payload, community_tags or None, community_priority or None, community_project or None),
        )
        conn.commit()
        return {"ok": True, "entry_id": cur.lastrowid, "source_ref": source_ref}
    finally:
        conn.close()


def get_entry_meta(ww_base: str, entry_id: int) -> dict[str, Any]:
    """Return source_ref and captured_state for a single community entry (for backlinks)."""
    conn = connect(ww_base)
    try:
        row = conn.execute(
            "SELECT source_ref, captured_state FROM community_entries WHERE id=?", (entry_id,)
        ).fetchone()
        if not row:
            return {}
        try:
            cap = json.loads(row["captured_state"] or "{}")
        except Exception:
            cap = {}
        return {"source_ref": row["source_ref"], "captured_state": cap}
    finally:
        conn.close()


def add_comment(ww_base: str, entry_id: int, body: str) -> dict[str, Any]:
    """Insert a comment row on a community entry and return ok/id."""
    conn = connect(ww_base)
    try:
        row = conn.execute("SELECT id FROM community_entries WHERE id=?", (entry_id,)).fetchone()
        if not row:
            return {"ok": False, "error": "community entry not found"}
        cur = conn.execute(
            "INSERT INTO community_comments (entry_id, body) VALUES (?,?)",
            (entry_id, body.strip()),
        )
        conn.commit()
        return {"ok": True, "comment_id": cur.lastrowid, "entry_id": entry_id}
    finally:
        conn.close()


def add_journal_from_file(
    ww_base: str,
    community_name: str,
    profile_name: str,
    journal_file: str,
    date_header: str,
    journal_notebook: str = "default",
    community_tags: str | None = None,
    community_priority: str | None = None,
    community_project: str | None = None,
) -> dict[str, Any]:
    try:
        content = open(journal_file, "r", encoding="utf-8", errors="replace").read()
    except OSError as exc:
        return {"ok": False, "error": f"journal read failed: {exc}"}
    for ent in parse_journal_entries(content):
        if ent["date"] == date_header.strip():
            slug = journal_date_to_slug(ent["date"])
            source_ref = f"{profile_name}.journal.{slug}"
            captured = {
                "date": ent["date"],
                "body": ent["body"],
                "journal": journal_notebook,
            }
            return add_entry(
                ww_base, community_name, source_ref, captured,
                community_tags=community_tags,
                community_priority=community_priority,
                community_project=community_project,
            )
    return {"ok": False, "error": f"journal entry not found for [{date_header}]"}


def main() -> int:
    if len(sys.argv) < 3:
        print(json.dumps({"ok": False, "error": "usage"}))
        return 1
    cmd = sys.argv[1]
    wb = sys.argv[2]
    try:
        if cmd == "list":
            print(json.dumps(list_communities(wb)))
        elif cmd == "show":
            if len(sys.argv) < 4:
                print(json.dumps({"ok": False, "error": "name required"}))
                return 1
            out = show_community(wb, sys.argv[3])
            print(json.dumps(out))
            return 0 if out.get("ok") else 1
        elif cmd == "create":
            if len(sys.argv) < 4:
                print(json.dumps({"ok": False, "error": "name required"}))
                return 1
            out = create_community(wb, sys.argv[3])
            print(json.dumps(out))
            return 0 if out.get("ok") else 1
        elif cmd == "add-entry":
            # add-entry <wb> <community> <source_ref> <path.json>
            if len(sys.argv) < 6:
                print(json.dumps({"ok": False, "error": "add-entry ww community source_ref jsonpath"}))
                return 1
            with open(sys.argv[5], encoding="utf-8") as fh:
                cap = json.load(fh)
            out = add_entry(wb, sys.argv[3], sys.argv[4], cap)
            print(json.dumps(out))
            return 0 if out.get("ok") else 1
        elif cmd == "add-journal":
            # add-journal <wb> <community> <profile> <journal_file> <date_header> [notebook]
            if len(sys.argv) < 7:
                print(json.dumps({"ok": False, "error": "add-journal args"}))
                return 1
            nb = sys.argv[7] if len(sys.argv) > 7 else "default"
            out = add_journal_from_file(wb, sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], nb)
            print(json.dumps(out))
            return 0 if out.get("ok") else 1
        else:
            print(json.dumps({"ok": False, "error": f"unknown cmd {cmd}"}))
            return 1
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
