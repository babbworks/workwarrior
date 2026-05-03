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
    for migration in [
        "ALTER TABLE community_entries ADD COLUMN community_project TEXT",
        "ALTER TABLE communities ADD COLUMN archived_at TEXT",
        "ALTER TABLE communities ADD COLUMN description TEXT",
    ]:
        try:
            conn.execute(migration)
            conn.commit()
        except Exception:
            pass
    return conn


def list_communities(ww_base: str, include_archived: bool = False) -> dict[str, Any]:
    conn = connect(ww_base)
    try:
        where = "" if include_archived else "WHERE c.archived_at IS NULL"
        rows = conn.execute(
            f"""
            SELECT c.name, c.description, c.archived_at, COUNT(e.id) AS cnt
            FROM communities c
            LEFT JOIN community_entries e ON e.community_id = c.id
            {where}
            GROUP BY c.id ORDER BY c.name
            """
        ).fetchall()
        return {"ok": True, "communities": [
            {
                "name": r["name"],
                "description": r["description"],
                "entry_count": int(r["cnt"]),
                "archived": r["archived_at"] is not None,
                "archived_at": r["archived_at"],
            }
            for r in rows
        ]}
    finally:
        conn.close()


def show_community(ww_base: str, name: str) -> dict[str, Any]:
    conn = connect(ww_base)
    try:
        row = conn.execute(
            "SELECT id, name, description, archived_at FROM communities WHERE name=?", (name,)
        ).fetchone()
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
        return {
            "ok": True,
            "name": name,
            "description": row["description"],
            "archived": row["archived_at"] is not None,
            "archived_at": row["archived_at"],
            "entries": entries,
        }
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


def remove_entry(ww_base: str, community_name: str, entry_id: int) -> dict[str, Any]:
    """Remove an entry (and its comments) from a community."""
    conn = connect(ww_base)
    try:
        row = conn.execute(
            "SELECT e.id FROM community_entries e JOIN communities c ON e.community_id=c.id WHERE e.id=? AND c.name=?",
            (entry_id, community_name),
        ).fetchone()
        if not row:
            return {"ok": False, "error": "entry not found in community"}
        conn.execute("DELETE FROM community_entries WHERE id=?", (entry_id,))
        conn.commit()
        return {"ok": True, "entry_id": entry_id}
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


def archive_community(ww_base: str, name: str) -> dict[str, Any]:
    conn = connect(ww_base)
    try:
        row = conn.execute("SELECT id FROM communities WHERE name=?", (name,)).fetchone()
        if not row:
            return {"ok": False, "error": "community not found"}
        conn.execute("UPDATE communities SET archived_at=datetime('now') WHERE name=?", (name,))
        conn.commit()
        return {"ok": True, "name": name, "archived": True}
    finally:
        conn.close()


def unarchive_community(ww_base: str, name: str) -> dict[str, Any]:
    conn = connect(ww_base)
    try:
        row = conn.execute("SELECT id FROM communities WHERE name=?", (name,)).fetchone()
        if not row:
            return {"ok": False, "error": "community not found"}
        conn.execute("UPDATE communities SET archived_at=NULL WHERE name=?", (name,))
        conn.commit()
        return {"ok": True, "name": name, "archived": False}
    finally:
        conn.close()


def set_community_description(ww_base: str, name: str, description: str) -> dict[str, Any]:
    conn = connect(ww_base)
    try:
        row = conn.execute("SELECT id FROM communities WHERE name=?", (name,)).fetchone()
        if not row:
            return {"ok": False, "error": "community not found"}
        conn.execute("UPDATE communities SET description=? WHERE name=?", (description.strip() or None, name))
        conn.commit()
        return {"ok": True, "name": name, "description": description.strip() or None}
    finally:
        conn.close()


def rename_community(ww_base: str, old_name: str, new_name: str) -> dict[str, Any]:
    conn = connect(ww_base)
    try:
        row = conn.execute("SELECT id FROM communities WHERE name=?", (old_name,)).fetchone()
        if not row:
            return {"ok": False, "error": "community not found"}
        clash = conn.execute("SELECT id FROM communities WHERE name=?", (new_name,)).fetchone()
        if clash:
            return {"ok": False, "error": "name already taken"}
        conn.execute("UPDATE communities SET name=? WHERE name=?", (new_name, old_name))
        conn.commit()
        return {"ok": True, "old_name": old_name, "name": new_name}
    except sqlite3.IntegrityError:
        return {"ok": False, "error": "name already taken"}
    finally:
        conn.close()


def modify_entry(
    ww_base: str,
    entry_id: int,
    community_tags: str | None = None,
    community_priority: str | None = None,
    community_project: str | None = None,
    is_community_derivative: bool | None = None,
) -> dict[str, Any]:
    conn = connect(ww_base)
    try:
        row = conn.execute("SELECT id FROM community_entries WHERE id=?", (entry_id,)).fetchone()
        if not row:
            return {"ok": False, "error": "entry not found"}
        fields, vals = [], []
        if community_tags is not None:
            fields.append("community_tags=?"); vals.append(community_tags or None)
        if community_priority is not None:
            fields.append("community_priority=?"); vals.append(community_priority or None)
        if community_project is not None:
            fields.append("community_project=?"); vals.append(community_project or None)
        if is_community_derivative is not None:
            fields.append("is_community_derivative=?"); vals.append(1 if is_community_derivative else 0)
        if not fields:
            return {"ok": False, "error": "no fields to update"}
        vals.append(entry_id)
        conn.execute(f"UPDATE community_entries SET {', '.join(fields)} WHERE id=?", vals)
        conn.commit()
        return {"ok": True, "entry_id": entry_id}
    finally:
        conn.close()


def refresh_entry(ww_base: str, community_name: str, entry_id: int, captured: dict[str, Any]) -> dict[str, Any]:
    """Overwrite the captured_state snapshot for an entry (e.g. after task status change)."""
    conn = connect(ww_base)
    try:
        row = conn.execute(
            "SELECT e.id FROM community_entries e JOIN communities c ON e.community_id=c.id WHERE e.id=? AND c.name=?",
            (entry_id, community_name),
        ).fetchone()
        if not row:
            return {"ok": False, "error": "entry not found in community"}
        conn.execute(
            "UPDATE community_entries SET captured_state=? WHERE id=?",
            (json.dumps(captured, ensure_ascii=False), entry_id),
        )
        conn.commit()
        return {"ok": True, "entry_id": entry_id}
    finally:
        conn.close()


def move_entry(ww_base: str, entry_id: int, from_community: str, to_community: str) -> dict[str, Any]:
    """Move an entry from one community to another."""
    conn = connect(ww_base)
    try:
        from_row = conn.execute(
            "SELECT e.id, e.source_ref FROM community_entries e JOIN communities c ON e.community_id=c.id WHERE e.id=? AND c.name=?",
            (entry_id, from_community),
        ).fetchone()
        if not from_row:
            return {"ok": False, "error": "entry not found in source community"}
        to_row = conn.execute("SELECT id FROM communities WHERE name=?", (to_community,)).fetchone()
        if not to_row:
            return {"ok": False, "error": "destination community not found"}
        # Check for duplicate source_ref in destination
        dup = conn.execute(
            "SELECT id FROM community_entries WHERE community_id=? AND source_ref=?",
            (to_row["id"], from_row["source_ref"]),
        ).fetchone()
        if dup:
            return {"ok": False, "error": "entry already exists in destination community"}
        conn.execute(
            "UPDATE community_entries SET community_id=? WHERE id=?",
            (to_row["id"], entry_id),
        )
        conn.commit()
        return {"ok": True, "entry_id": entry_id, "from": from_community, "to": to_community}
    finally:
        conn.close()


def recent_entries(ww_base: str, n: int = 10) -> dict[str, Any]:
    """Return the N most recently added entries across all non-archived communities."""
    conn = connect(ww_base)
    try:
        rows = conn.execute(
            """
            SELECT e.id, e.source_ref, e.added_at, e.community_tags, e.community_priority,
                   e.community_project, e.is_community_derivative, c.name AS community_name
            FROM community_entries e
            JOIN communities c ON e.community_id = c.id
            WHERE c.archived_at IS NULL
            ORDER BY datetime(e.added_at) DESC, e.id DESC
            LIMIT ?
            """,
            (max(1, n),),
        ).fetchall()
        return {"ok": True, "entries": [
            {
                "id": r["id"],
                "community_name": r["community_name"],
                "source_ref": r["source_ref"],
                "added_at": r["added_at"],
                "community_tags": r["community_tags"],
                "community_priority": r["community_priority"],
                "community_project": r["community_project"],
                "is_community_derivative": bool(r["is_community_derivative"]),
            }
            for r in rows
        ]}
    finally:
        conn.close()


def mark_comment_copied(ww_base: str, comment_id: int) -> dict[str, Any]:
    """Mark a comment as copied back to its source task."""
    conn = connect(ww_base)
    try:
        row = conn.execute("SELECT id FROM community_comments WHERE id=?", (comment_id,)).fetchone()
        if not row:
            return {"ok": False, "error": "comment not found"}
        conn.execute("UPDATE community_comments SET copied_to_source=1 WHERE id=?", (comment_id,))
        conn.commit()
        return {"ok": True, "comment_id": comment_id}
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
            include_archived = "--all" in sys.argv
            print(json.dumps(list_communities(wb, include_archived=include_archived)))
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
        elif cmd == "remove-entry":
            # remove-entry <wb> <community> <entry_id>
            if len(sys.argv) < 5:
                print(json.dumps({"ok": False, "error": "remove-entry ww community entry_id"}))
                return 1
            try:
                eid = int(sys.argv[4])
            except ValueError:
                print(json.dumps({"ok": False, "error": "entry_id must be an integer"}))
                return 1
            out = remove_entry(wb, sys.argv[3], eid)
            print(json.dumps(out))
            return 0 if out.get("ok") else 1
        elif cmd == "add-comment":
            # add-comment <wb> <entry_id> <body>
            if len(sys.argv) < 5:
                print(json.dumps({"ok": False, "error": "add-comment ww entry_id body"}))
                return 1
            try:
                eid = int(sys.argv[3])
            except ValueError:
                print(json.dumps({"ok": False, "error": "entry_id must be an integer"}))
                return 1
            out = add_comment(wb, eid, sys.argv[4])
            print(json.dumps(out))
            return 0 if out.get("ok") else 1
        elif cmd == "entry-meta":
            # entry-meta <wb> <entry_id>
            if len(sys.argv) < 4:
                print(json.dumps({"ok": False, "error": "entry-meta ww entry_id"}))
                return 1
            try:
                eid = int(sys.argv[3])
            except ValueError:
                print(json.dumps({"ok": False, "error": "entry_id must be an integer"}))
                return 1
            out = get_entry_meta(wb, eid)
            if not out:
                print(json.dumps({"ok": False, "error": "entry not found"}))
                return 1
            out["ok"] = True
            print(json.dumps(out))
            return 0
        elif cmd == "archive":
            # archive <wb> <name>
            if len(sys.argv) < 4:
                print(json.dumps({"ok": False, "error": "archive ww name"})); return 1
            out = archive_community(wb, sys.argv[3])
            print(json.dumps(out)); return 0 if out.get("ok") else 1
        elif cmd == "unarchive":
            if len(sys.argv) < 4:
                print(json.dumps({"ok": False, "error": "unarchive ww name"})); return 1
            out = unarchive_community(wb, sys.argv[3])
            print(json.dumps(out)); return 0 if out.get("ok") else 1
        elif cmd == "describe":
            # describe <wb> <name> <description>
            if len(sys.argv) < 5:
                print(json.dumps({"ok": False, "error": "describe ww name description"})); return 1
            out = set_community_description(wb, sys.argv[3], sys.argv[4])
            print(json.dumps(out)); return 0 if out.get("ok") else 1
        elif cmd == "rename":
            # rename <wb> <old> <new>
            if len(sys.argv) < 5:
                print(json.dumps({"ok": False, "error": "rename ww old new"})); return 1
            out = rename_community(wb, sys.argv[3], sys.argv[4])
            print(json.dumps(out)); return 0 if out.get("ok") else 1
        elif cmd == "modify-entry":
            # modify-entry <wb> <entry_id> [--tags x] [--priority H] [--project p] [--derivative 0|1]
            if len(sys.argv) < 4:
                print(json.dumps({"ok": False, "error": "modify-entry ww entry_id [opts]"})); return 1
            try:
                eid = int(sys.argv[3])
            except ValueError:
                print(json.dumps({"ok": False, "error": "entry_id must be integer"})); return 1
            args = sys.argv[4:]
            def _flag(flag):
                try: return args[args.index(flag) + 1]
                except (ValueError, IndexError): return None
            out = modify_entry(
                wb, eid,
                community_tags=_flag("--tags"),
                community_priority=_flag("--priority"),
                community_project=_flag("--project"),
                is_community_derivative=(
                    {"1": True, "0": False}.get(_flag("--derivative") or "", None)
                ),
            )
            print(json.dumps(out)); return 0 if out.get("ok") else 1
        elif cmd == "refresh-entry":
            # refresh-entry <wb> <community> <entry_id> <path.json>
            if len(sys.argv) < 6:
                print(json.dumps({"ok": False, "error": "refresh-entry ww community entry_id jsonpath"})); return 1
            try:
                eid = int(sys.argv[4])
            except ValueError:
                print(json.dumps({"ok": False, "error": "entry_id must be integer"})); return 1
            with open(sys.argv[5], encoding="utf-8") as fh:
                cap = json.load(fh)
            out = refresh_entry(wb, sys.argv[3], eid, cap)
            print(json.dumps(out)); return 0 if out.get("ok") else 1
        elif cmd == "move-entry":
            # move-entry <wb> <entry_id> <from_community> <to_community>
            if len(sys.argv) < 6:
                print(json.dumps({"ok": False, "error": "move-entry ww entry_id from to"})); return 1
            try:
                eid = int(sys.argv[3])
            except ValueError:
                print(json.dumps({"ok": False, "error": "entry_id must be integer"})); return 1
            out = move_entry(wb, eid, sys.argv[4], sys.argv[5])
            print(json.dumps(out)); return 0 if out.get("ok") else 1
        elif cmd == "recent":
            # recent <wb> [n]
            n = 10
            if len(sys.argv) >= 4:
                try: n = int(sys.argv[3])
                except ValueError: pass
            out = recent_entries(wb, n)
            print(json.dumps(out)); return 0 if out.get("ok") else 1
        elif cmd == "mark-copied":
            # mark-copied <wb> <comment_id>
            if len(sys.argv) < 4:
                print(json.dumps({"ok": False, "error": "mark-copied ww comment_id"})); return 1
            try:
                cid = int(sys.argv[3])
            except ValueError:
                print(json.dumps({"ok": False, "error": "comment_id must be integer"})); return 1
            out = mark_comment_copied(wb, cid)
            print(json.dumps(out)); return 0 if out.get("ok") else 1
        else:
            print(json.dumps({"ok": False, "error": f"unknown cmd {cmd}"}))
            return 1
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
