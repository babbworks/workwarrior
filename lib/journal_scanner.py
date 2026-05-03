#!/usr/bin/env python3
"""
lib/journal_scanner.py — parse and annotate jrnl-format plain text files.

Entry format (jrnl v4):
  [YYYY-MM-DD HH:MM] First line (title/body continues on next lines)
  Body text...

Annotation format appended inside an entry block:
  ---
  [YYYY-MM-DD HH:MM] annotation text

date_slug format: YYYY-MM-DD_HH-MM (colons → hyphens, space → underscore)
"""
from __future__ import annotations

import json
import re
import sys
from datetime import datetime
from typing import Any

_HEADER_RE = re.compile(r'\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\]')
# Matches annotation separator + timestamp at line-start (---\n[ts] text)
_ANN_MARKER_RE = re.compile(r'(?m)^---\n\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\] ?')
# Matches placeholder {ANN:ts} inserted by parse_file to protect annotation timestamps
_ANN_PLACEHOLDER_RE = re.compile(r'\{ANN:(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\}(.*?)(?=\n---\n|\{ANN:|\Z)', re.DOTALL)
# Metadata markers appended by journal_add / journal_annotate:
# @project:x @tags:a,b @priority:H @status:active
_META_RE = re.compile(r'@(project|tags|priority|status):(\S+)')


def parse_metadata(body: str) -> dict[str, Any]:
    """Extract @project:, @tags:, @priority:, @status: markers from body text.

    Returns {'project': str, 'tags': list[str], 'priority': str, 'status': str}.
    Markers anywhere in the body are accepted; the last value wins for scalar fields.
    """
    meta: dict[str, Any] = {"project": "", "tags": [], "priority": "", "status": ""}
    for m in _META_RE.finditer(body):
        key, val = m.group(1), m.group(2)
        if key == "tags":
            meta["tags"] = [t for t in val.split(",") if t]
        else:
            meta[key] = val
    return meta


def date_to_slug(date_hdr: str) -> str:
    return date_hdr.strip().replace(' ', '_').replace(':', '-')


def slug_to_header(slug: str) -> str:
    """YYYY-MM-DD_HH-MM → YYYY-MM-DD HH:MM"""
    if '_' not in slug:
        return slug
    date_part, time_part = slug.split('_', 1)
    return f"{date_part} {time_part.replace('-', ':', 1)}"


def parse_file(journal_path: str) -> list[dict[str, Any]]:
    """Return list of entry dicts: {date, date_slug, body, annotations}.

    Annotation blocks (---\\n[ts] text) inside entry bodies are extracted
    before the main header split so their timestamps aren't treated as new
    entry headers.
    """
    try:
        content = open(journal_path, encoding='utf-8', errors='replace').read()
    except OSError:
        return []
    # Replace annotation markers with placeholders to protect them from
    # being parsed as entry headers during the main HEADER_RE split.
    sanitized = _ANN_MARKER_RE.sub(lambda m: f'{{ANN:{m.group(1)}}}', content)
    parts = _HEADER_RE.split(sanitized)
    entries: list[dict[str, Any]] = []
    for i in range(1, len(parts) - 1, 2):
        date = parts[i]
        raw = parts[i + 1].strip() if i + 1 < len(parts) else ''
        if not raw:
            continue
        # Extract annotation placeholders from the body
        annotations: list[dict[str, str]] = []
        for am in _ANN_PLACEHOLDER_RE.finditer(raw):
            annotations.append({"date": am.group(1), "text": am.group(2).strip()})
        body = _ANN_PLACEHOLDER_RE.sub('', raw)
        # Remove leftover --- separators
        body = re.sub(r'\n---\s*$', '', body, flags=re.MULTILINE).strip()
        body = re.sub(r'^---\s*$', '', body, flags=re.MULTILINE).strip()
        # Body-level metadata, then override with most-recent annotation that
        # carries metadata markers (retroactive edit support per AC4).
        meta = parse_metadata(body)
        for ann in annotations:
            ann_meta = parse_metadata(ann["text"])
            if ann_meta["project"]:
                meta["project"] = ann_meta["project"]
            if ann_meta["tags"]:
                meta["tags"] = ann_meta["tags"]
            if ann_meta["priority"]:
                meta["priority"] = ann_meta["priority"]
            if ann_meta["status"]:
                meta["status"] = ann_meta["status"]
        entries.append({
            "date": date,
            "date_slug": date_to_slug(date),
            "body": body,
            "annotations": annotations,
            "project": meta["project"],
            "tags": meta["tags"],
            "priority": meta["priority"],
            "status": meta["status"],
        })
    entries.reverse()
    return entries


def get_entry(journal_path: str, date_slug: str) -> dict[str, Any] | None:
    """Return a single entry dict by date_slug, or None if not found."""
    target_hdr = slug_to_header(date_slug)
    for e in parse_file(journal_path):
        if e['date'] == target_hdr:
            return e
    return None


def annotate_entry(journal_path: str, date_slug: str, text: str) -> dict[str, Any]:
    """Append an annotation block to the named entry. Returns {ok, error}."""
    target_hdr = slug_to_header(date_slug)
    try:
        content = open(journal_path, encoding='utf-8', errors='replace').read()
    except OSError as exc:
        return {"ok": False, "error": f"cannot read journal: {exc}"}

    # Protect existing annotation timestamps before splitting so they are not
    # treated as entry headers (same technique as parse_file).
    sanitized = _ANN_MARKER_RE.sub(lambda m: f'{{ANN:{m.group(1)}}}', content)
    parts = _HEADER_RE.split(sanitized)
    # parts: [pre, date0, body0, date1, body1, ...]
    target_idx = None
    for i in range(1, len(parts) - 1, 2):
        if parts[i] == target_hdr:
            target_idx = i
            break
    if target_idx is None:
        return {"ok": False, "error": f"entry not found: [{target_hdr}]"}

    ts = datetime.now().strftime('%Y-%m-%d %H:%M')
    ann_block = f"\n---\n[{ts}] {text.strip()}"

    # Rebuild: insert annotation block into the body segment of target_idx
    new_parts = list(parts)
    new_parts[target_idx + 1] = new_parts[target_idx + 1].rstrip() + ann_block + '\n'

    # Reconstruct the file, restoring annotation placeholders → ---\n[ts] form
    result = parts[0]
    for i in range(1, len(new_parts) - 1, 2):
        body = new_parts[i + 1] if i + 1 < len(new_parts) else ''
        body = re.sub(r'\{ANN:(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\}', r'---\n[\1] ', body)
        result += f'[{new_parts[i]}]' + body

    try:
        with open(journal_path, 'w', encoding='utf-8') as fh:
            fh.write(result)
    except OSError as exc:
        return {"ok": False, "error": f"cannot write journal: {exc}"}

    return {"ok": True, "date": target_hdr, "annotation": text.strip(), "ts": ts}


def filter_entries(
    entries: list[dict[str, Any]],
    tag: str | None = None,
    project: str | None = None,
    priority: str | None = None,
) -> list[dict[str, Any]]:
    """Filter entries by metadata fields. All specified filters must match."""
    out = entries
    if tag:
        out = [e for e in out if tag in e.get("tags", [])]
    if project:
        out = [e for e in out if e.get("project", "") == project]
    if priority:
        out = [e for e in out if e.get("priority", "") == priority]
    return out


def main() -> int:
    import argparse
    if len(sys.argv) < 3:
        print(json.dumps({"ok": False, "error": "usage: journal_scanner.py <cmd> <journal_file> [args]"}))
        return 1
    cmd, journal_path = sys.argv[1], sys.argv[2]
    try:
        if cmd == "parse":
            # Optional filters: --tag, --project, --priority
            p = argparse.ArgumentParser(add_help=False)
            p.add_argument("--tag")
            p.add_argument("--project")
            p.add_argument("--priority")
            opts, _ = p.parse_known_args(sys.argv[3:])
            entries = parse_file(journal_path)
            entries = filter_entries(entries, tag=opts.tag, project=opts.project, priority=opts.priority)
            print(json.dumps({"ok": True, "entries": entries}))
        elif cmd == "get-entry":
            if len(sys.argv) < 4:
                print(json.dumps({"ok": False, "error": "date_slug required"}))
                return 1
            e = get_entry(journal_path, sys.argv[3])
            if e is None:
                print(json.dumps({"ok": False, "error": "entry not found"}))
                return 1
            print(json.dumps({"ok": True, "entry": e}))
        elif cmd == "parse-metadata":
            # Parse metadata markers from a body string passed as remaining args
            body = ' '.join(sys.argv[3:])
            print(json.dumps({"ok": True, "metadata": parse_metadata(body)}))
        elif cmd == "annotate":
            if len(sys.argv) < 5:
                print(json.dumps({"ok": False, "error": "date_slug and text required"}))
                return 1
            text = ' '.join(sys.argv[4:])
            out = annotate_entry(journal_path, sys.argv[3], text)
            print(json.dumps(out))
            return 0 if out.get("ok") else 1
        elif cmd == "project-stats":
            if len(sys.argv) < 4:
                print(json.dumps({"ok": False, "error": "project name required"}))
                return 1
            project_name = sys.argv[3]
            entries = parse_file(journal_path)
            matched = filter_entries(entries, project=project_name)
            last_date = matched[0]["date"] if matched else ""
            print(json.dumps({"ok": True, "count": len(matched), "last_date": last_date}))
        else:
            print(json.dumps({"ok": False, "error": f"unknown cmd: {cmd}"}))
            return 1
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
