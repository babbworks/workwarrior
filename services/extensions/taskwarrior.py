#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
import time
from datetime import datetime, timezone, timedelta
from pathlib import Path
from urllib import request, parse


WW_BASE = Path(os.environ.get("WW_BASE", Path.home() / "ww"))
REGISTRY = WW_BASE / "config" / "extensions.taskwarrior.yaml"
GITHUB_API = "https://api.github.com"


def _http_get(url, token=None):
    req = request.Request(url)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("User-Agent", "workwarrior-extensions")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with request.urlopen(req, timeout=30) as resp:
        return resp.read().decode("utf-8")


def _search_repos(topic, token=None):
    repos = []
    page = 1
    while True:
        q = parse.quote(f"topic:{topic}")
        url = f"{GITHUB_API}/search/repositories?q={q}&per_page=100&page={page}"
        data = json.loads(_http_get(url, token=token))
        items = data.get("items", [])
        repos.extend(items)
        if len(items) < 100:
            break
        page += 1
        time.sleep(0.1)
    return repos


def _status_from_updated(updated_at):
    if not updated_at:
        return "unknown"
    dt = datetime.fromisoformat(updated_at.replace("Z", "+00:00"))
    age = datetime.now(timezone.utc) - dt
    if age <= timedelta(days=365):
        return "active"
    if age <= timedelta(days=365 * 3):
        return "stale"
    return "dormant"


def _categorize(desc, topics):
    text = (desc or "").lower() + " " + " ".join(topics or []).lower()
    cats = set()
    if re.search(r"vim|nvim|emacs|editor", text):
        cats.add("editor")
    if re.search(r"ui|tui|gui|web|dashboard|frontend", text):
        cats.add("ui")
    if re.search(r"hook|automation|script", text):
        cats.add("hook")
    if re.search(r"report|analytics|chart|graph", text):
        cats.add("report")
    if re.search(r"export|import|convert|sync", text):
        cats.add("sync")
    if re.search(r"calendar|caldav|ical", text):
        cats.add("calendar")
    if re.search(r"notify|notification|email|slack|telegram", text):
        cats.add("notify")
    if re.search(r"server|taskserver|sync", text):
        cats.add("server")
    if not cats:
        cats.add("misc")
    return sorted(cats)


def _yaml_escape(val):
    if val is None:
        return '""'
    s = str(val)
    s = s.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{s}"'


def refresh_registry():
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    repos = {}
    for topic in ("taskwarrior", "taskserver"):
        for r in _search_repos(topic, token=token):
            repos[r["full_name"]] = r

    entries = []
    for full_name, r in repos.items():
        topics = r.get("topics", [])
        updated_at = r.get("pushed_at") or r.get("updated_at")
        entry = {
            "name": r.get("name"),
            "full_name": full_name,
            "url": r.get("html_url"),
            "description": r.get("description") or "",
            "topics": topics,
            "language": r.get("language") or "",
            "license": (r.get("license") or {}).get("spdx_id") or "",
            "archived": bool(r.get("archived")),
            "updated_at": updated_at or "",
            "status": _status_from_updated(updated_at),
            "stars": r.get("stargazers_count", 0),
            "categories": _categorize(r.get("description"), topics),
            "synopsis": "",
        }
        entries.append(entry)

    entries.sort(key=lambda e: (-e["stars"], e["full_name"]))

    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    for e in entries:
        try:
            url = f"{GITHUB_API}/repos/{e['full_name']}/readme"
            data = json.loads(_http_get(url, token=token))
            if "content" in data:
                import base64
                raw = base64.b64decode(data["content"]).decode("utf-8", errors="ignore")
                lines = [l.strip() for l in raw.splitlines() if l.strip()]
                synopsis = " ".join(lines[:3])
                e["synopsis"] = synopsis[:500]
        except Exception:
            pass
        time.sleep(0.05)
    REGISTRY.parent.mkdir(parents=True, exist_ok=True)
    lines = ["extensions:"]
    for e in entries:
        lines.append("  - name: " + _yaml_escape(e["name"]))
        lines.append("    full_name: " + _yaml_escape(e["full_name"]))
        lines.append("    url: " + _yaml_escape(e["url"]))
        lines.append("    description: " + _yaml_escape(e["description"]))
        lines.append("    topics: [" + ", ".join(_yaml_escape(t) for t in e["topics"]) + "]")
        lines.append("    language: " + _yaml_escape(e["language"]))
        lines.append("    license: " + _yaml_escape(e["license"]))
        lines.append("    archived: " + ("true" if e["archived"] else "false"))
        lines.append("    updated_at: " + _yaml_escape(e["updated_at"]))
        lines.append("    status: " + _yaml_escape(e["status"]))
        lines.append("    stars: " + str(e["stars"]))
        lines.append("    categories: [" + ", ".join(_yaml_escape(c) for c in e["categories"]) + "]")
        lines.append("    synopsis: " + _yaml_escape(e["synopsis"]))
    REGISTRY.write_text("\n".join(lines) + "\n")
    print(f"Updated registry: {REGISTRY}")


def _load_registry():
    if not REGISTRY.exists():
        return []
    items = []
    current = None
    for line in REGISTRY.read_text().splitlines():
        if line.startswith("  - "):
            if current:
                items.append(current)
            current = {}
            key, _, val = line.strip()[3:].partition(": ")
            current[key] = val.strip('"')
        elif line.startswith("    ") and current is not None:
            key, _, val = line.strip().partition(": ")
            if val.startswith("[") and val.endswith("]"):
                parts = [p.strip().strip('"') for p in val[1:-1].split(",") if p.strip()]
                current[key] = parts
            elif val in ("true", "false"):
                current[key] = (val == "true")
        elif key == "stars":
            current[key] = int(val)
        else:
            current[key] = val.strip('"')
    if current:
        items.append(current)
    return items


def _filter_items(items, args):
    out = []
    for e in items:
        if args.category and args.category not in (e.get("categories") or []):
            continue
        if args.status and e.get("status") != args.status:
            continue
        if args.language and (e.get("language") or "").lower() != args.language.lower():
            continue
        if args.owner and not (e.get("full_name") or "").lower().startswith(args.owner.lower() + "/"):
            continue
        if args.search:
            hay = " ".join([
                e.get("name", ""),
                e.get("description", ""),
                " ".join(e.get("topics") or []),
            ]).lower()
            if args.search.lower() not in hay:
                continue
        out.append(e)
    return out


def list_items(args):
    items = _filter_items(_load_registry(), args)
    if args.limit:
        items = items[: args.limit]
    if args.format == "json":
        print(json.dumps(items, indent=2))
        return
    if not items:
        print("No extensions found")
        return
    for e in items:
        cats = ",".join(e.get("categories") or [])
        print(f"{e.get('full_name')}  [{e.get('status')}]  {cats}  ★{e.get('stars')}")


def info_item(name):
    for e in _load_registry():
        if e.get("name") == name or e.get("full_name") == name:
            print(json.dumps(e, indent=2))
            return
    print(f"Not found: {name}", file=sys.stderr)
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(add_help=False)
    sub = parser.add_subparsers(dest="cmd")

    p_list = sub.add_parser("list")
    p_list.add_argument("--category")
    p_list.add_argument("--status")
    p_list.add_argument("--language")
    p_list.add_argument("--owner")
    p_list.add_argument("--limit", type=int, default=0)
    p_list.add_argument("--format", choices=["text", "json"], default="text")
    p_list.add_argument("--search")

    p_search = sub.add_parser("search")
    p_search.add_argument("term")
    p_search.add_argument("--category")
    p_search.add_argument("--status")
    p_search.add_argument("--language")
    p_search.add_argument("--owner")
    p_search.add_argument("--limit", type=int, default=0)

    p_info = sub.add_parser("info")
    p_info.add_argument("name")

    sub.add_parser("cards")
    sub.add_parser("refresh")

    if len(sys.argv) == 1:
        print("Usage: ww extensions taskwarrior <list|search|info|refresh>")
        sys.exit(1)
    args = parser.parse_args()

    if args.cmd == "refresh":
        refresh_registry()
    elif args.cmd == "list":
        list_items(args)
    elif args.cmd == "search":
        args.search = args.term
        list_items(args)
    elif args.cmd == "info":
        info_item(args.name)
    elif args.cmd == "cards":
        items = _load_registry()
        if not items:
            print("No extensions found")
            return
        for e in items:
            print(f"{e.get('full_name')}  ★{e.get('stars')}")
            print(f"  {e.get('description')}")
            syn = e.get("synopsis") or ""
            if syn:
                print(f"  {syn}")
            print(f"  {e.get('url')}")
            print("")
    else:
        print("Usage: ww extensions taskwarrior <list|search|info|refresh>")
        sys.exit(1)


if __name__ == "__main__":
    main()
