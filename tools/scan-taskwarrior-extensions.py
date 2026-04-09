#!/usr/bin/env python3
"""
scan-taskwarrior-extensions.py

Queries the GitHub API for repos tagged with the 'taskwarrior' topic,
fetches each README, categorises the extension, and rates its integration
potential for Workwarrior.

Usage:
    python3 scan-taskwarrior-extensions.py [--token TOKEN] [--out DIR]

    TOKEN defaults to `gh auth token` output.
    DIR   defaults to docs/taskwarrior-extensions/
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
from base64 import b64decode

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

GITHUB_API = "https://api.github.com"
TOPICS = ["taskwarrior"]
PER_PAGE = 100
MAX_PAGES = 10          # cap at 1 000 repos
README_MAX_BYTES = 64_000

# --- Category taxonomy (keyword → category) --------------------------------
CATEGORY_RULES = [
    ("sync",                      "sync"),
    ("synchroni",                 "sync"),
    ("two-way",                   "sync"),
    ("caldav",                    "sync"),
    ("hook",                      "hooks"),
    ("on-modify",                 "hooks"),
    ("on-add",                    "hooks"),
    ("urgency",                   "hooks"),
    ("recur",                     "hooks"),
    ("tui",                       "tui"),
    ("terminal ui",               "tui"),
    ("curses",                    "tui"),
    ("ncurses",                   "tui"),
    ("interface",                 "tui"),
    ("dashboard",                 "tui"),
    ("report",                    "reports"),
    ("burndown",                  "reports"),
    ("chart",                     "reports"),
    ("visual",                    "reports"),
    ("statistic",                 "reports"),
    ("import",                    "import-export"),
    ("export",                    "import-export"),
    ("convert",                   "import-export"),
    ("migration",                 "import-export"),
    ("jira",                      "issue-trackers"),
    ("github issue",              "issue-trackers"),
    ("gitlab",                    "issue-trackers"),
    ("trello",                    "issue-trackers"),
    ("linear",                    "issue-trackers"),
    ("asana",                     "issue-trackers"),
    ("bugwarrior",                "issue-trackers"),
    ("timewarrior",               "time-tracking"),
    ("time track",                "time-tracking"),
    ("time log",                  "time-tracking"),
    ("pomodoro",                  "time-tracking"),
    ("mobile",                    "mobile"),
    ("android",                   "mobile"),
    ("ios",                       "mobile"),
    ("flutter",                   "mobile"),
    ("react native",              "mobile"),
    ("widget",                    "widgets-integrations"),
    ("polybar",                   "widgets-integrations"),
    ("waybar",                    "widgets-integrations"),
    ("i3",                        "widgets-integrations"),
    ("tmux",                      "widgets-integrations"),
    ("neovim",                    "widgets-integrations"),
    ("vim",                       "widgets-integrations"),
    ("emacs",                     "widgets-integrations"),
    ("vscode",                    "widgets-integrations"),
    ("obsidian",                  "widgets-integrations"),
    ("api",                       "api-libraries"),
    ("library",                   "api-libraries"),
    ("binding",                   "api-libraries"),
    ("wrapper",                   "api-libraries"),
    ("sdk",                       "api-libraries"),
    ("cli",                       "cli-tools"),
    ("shell",                     "cli-tools"),
    ("bash",                      "cli-tools"),
    ("zsh",                       "cli-tools"),
    ("completion",                "cli-tools"),
    ("alfred",                    "launchers"),
    ("raycast",                   "launchers"),
    ("rofi",                      "launchers"),
    ("dmenu",                     "launchers"),
    ("natural language",          "nlp"),
    ("nlp",                       "nlp"),
    ("parse",                     "nlp"),
    ("ai",                        "nlp"),
    ("gpt",                       "nlp"),
    ("llm",                       "nlp"),
    ("taskserver",                "taskserver"),
    ("inthe.am",                  "taskserver"),
    ("freecinc",                  "taskserver"),
]

CATEGORY_LABELS = {
    "sync":                 "Sync",
    "hooks":                "Hooks",
    "tui":                  "TUI / Interactive",
    "reports":              "Reports & Visualisation",
    "import-export":        "Import / Export",
    "issue-trackers":       "Issue Tracker Bridges",
    "time-tracking":        "Time Tracking",
    "mobile":               "Mobile",
    "widgets-integrations": "Widgets & Editor Integrations",
    "api-libraries":        "API Libraries",
    "cli-tools":            "CLI Tools",
    "launchers":            "Launchers",
    "nlp":                  "NLP / AI",
    "taskserver":           "Taskserver",
    "other":                "Other",
}

# --- Workwarrior integration fit scoring -----------------------------------
# Each rule: (regex on combined text, score_delta, note)
WW_RULES = [
    # Positive signals
    (r"timewarrior",       +3, "Uses TimeWarrior — already integrated in ww"),
    (r"bugwarrior",        +3, "Bugwarrior is in ww issues pipeline"),
    (r"hook",              +2, "Hook-based — ww can install hooks per profile"),
    (r"sync",              +2, "Sync capability relevant to ww profile isolation"),
    (r"urgency",           +2, "Urgency coefficients are a ww UDA focus area"),
    (r"uda",               +3, "UDAs — core to ww service model"),
    (r"profile",           +2, "Profile concept maps directly to ww"),
    (r"shell",             +1, "Shell integration — ww is shell-first"),
    (r"bash|zsh",          +1, "Shell scripting — matches ww stack"),
    (r"jrnl|journal",      +2, "JRNL is part of ww toolchain"),
    (r"hledger|ledger",    +2, "Hledger is part of ww toolchain"),
    (r"report",            +1, "Reporting is a ww surface area"),
    (r"github",            +1, "GitHub is ww's primary issue source"),
    (r"cli",               +1, "CLI-first matches ww ethos"),
    (r"import|export",     +1, "Import/export useful for profile migration"),
    (r"python",            +1, "Python — tooling language used in ww"),
    # Negative signals
    (r"electron|web app|browser extension", -2, "GUI/browser — not ww-native"),
    (r"android|ios|flutter|react native",   -2, "Mobile — outside ww scope"),
    (r"archived|deprecated|unmaintained",   -2, "Dormant project"),
    (r"taskserver|inthe\.am|freecinc",      -1, "Taskserver — ww doesn't use sync server"),
]

# ---------------------------------------------------------------------------
# GitHub helpers
# ---------------------------------------------------------------------------

def gh_token() -> str:
    try:
        tok = subprocess.check_output(["gh", "auth", "token"], text=True).strip()
        if tok:
            return tok
    except Exception:
        pass
    return os.environ.get("GITHUB_TOKEN", "")


def gh_get(url: str, token: str) -> dict | list:
    req = Request(url)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urlopen(req, timeout=20) as resp:
            return json.loads(resp.read())
    except HTTPError as e:
        if e.code == 403:
            reset = e.headers.get("X-RateLimit-Reset", "?")
            print(f"  [rate-limit] reset at epoch {reset}, sleeping 10s …", file=sys.stderr)
            time.sleep(10)
            return {}
        if e.code == 404:
            return {}
        raise
    except URLError:
        return {}


def fetch_readme(owner: str, repo: str, token: str) -> str:
    data = gh_get(f"{GITHUB_API}/repos/{owner}/{repo}/readme", token)
    if not data or "content" not in data:
        return ""
    raw = b64decode(data["content"]).decode("utf-8", errors="replace")
    return raw[:README_MAX_BYTES]


def search_repos(topic: str, token: str) -> list[dict]:
    repos = []
    page = 1
    while page <= MAX_PAGES:
        url = (
            f"{GITHUB_API}/search/repositories"
            f"?q=topic:{topic}&per_page={PER_PAGE}&page={page}&sort=stars"
        )
        data = gh_get(url, token)
        items = data.get("items", [])
        if not items:
            break
        repos.extend(items)
        if len(items) < PER_PAGE:
            break
        page += 1
        time.sleep(0.5)   # be polite
    return repos


# ---------------------------------------------------------------------------
# Categorisation & scoring
# ---------------------------------------------------------------------------

def categorise(text: str) -> str:
    lower = text.lower()
    for keyword, cat in CATEGORY_RULES:
        if keyword in lower:
            return cat
    return "other"


def score_ww(text: str) -> tuple[int, list[str]]:
    lower = text.lower()
    total = 0
    notes = []
    for pattern, delta, note in WW_RULES:
        if re.search(pattern, lower):
            total += delta
            notes.append(f"{'+'if delta>0 else ''}{delta}: {note}")
    return total, notes


def rating_label(score: int) -> str:
    if score >= 8:  return "★★★★★  Essential"
    if score >= 5:  return "★★★★☆  High"
    if score >= 2:  return "★★★☆☆  Medium"
    if score >= 0:  return "★★☆☆☆  Low"
    return          "★☆☆☆☆  Unlikely"


# ---------------------------------------------------------------------------
# Document generation
# ---------------------------------------------------------------------------

def repo_md(r: dict, readme: str) -> str:
    name        = r["full_name"]
    url         = r["html_url"]
    desc        = r.get("description") or ""
    stars       = r.get("stargazers_count", 0)
    lang        = r.get("language") or "—"
    archived    = r.get("archived", False)
    pushed      = (r.get("pushed_at") or "")[:10]
    topics_list = r.get("topics", [])

    combined    = f"{desc} {readme}"
    category    = categorise(combined)
    score, notes = score_ww(combined)
    rating      = rating_label(score)

    lines = [
        f"# {name}",
        "",
        f"**URL:** {url}  ",
        f"**Stars:** {stars}  ",
        f"**Language:** {lang}  ",
        f"**Last push:** {pushed}  ",
        f"**Archived:** {'Yes' if archived else 'No'}  ",
        f"**Topics:** {', '.join(topics_list) if topics_list else '—'}  ",
        "",
        f"## Description",
        "",
        desc or "_No description provided._",
        "",
        f"## Category",
        "",
        CATEGORY_LABELS.get(category, category),
        "",
        f"## Workwarrior Integration Rating",
        "",
        f"**Score:** {score}  ",
        f"**Rating:** {rating}  ",
        "",
        "### Scoring notes",
        "",
        *(([f"- {n}" for n in notes]) if notes else ["- (no matching signals)"]),
        "",
        "## README excerpt",
        "",
        "```",
        (readme[:3000] if readme else "_No README found._"),
        "```",
    ]
    return "\n".join(lines)


def index_md(categorised: dict[str, list[dict]], all_repos: list[dict]) -> str:
    lines = [
        "# Taskwarrior Extensions — Survey",
        "",
        f"_Generated from GitHub topic search. {len(all_repos)} repos scanned._",
        "",
        "## Table of Contents",
        "",
    ]

    for cat_key in sorted(categorised.keys()):
        label = CATEGORY_LABELS.get(cat_key, cat_key)
        lines.append(f"- [{label}](#{cat_key})")

    lines += ["", "---", ""]

    for cat_key in sorted(categorised.keys()):
        label = CATEGORY_LABELS.get(cat_key, cat_key)
        repos  = sorted(categorised[cat_key], key=lambda r: r["_score"], reverse=True)
        lines += [f"## {label} {{#{cat_key}}}", ""]
        lines += [
            "| Repo | Stars | Lang | Rating | Last push |",
            "|------|-------|------|--------|-----------|",
        ]
        for r in repos:
            name   = r["full_name"]
            slug   = name.replace("/", "-")
            stars  = r.get("stargazers_count", 0)
            lang   = r.get("language") or "—"
            pushed = (r.get("pushed_at") or "")[:10]
            rating = rating_label(r["_score"])
            lines.append(
                f"| [{name}](repos/{slug}.md) | {stars} | {lang} | {rating} | {pushed} |"
            )
        lines.append("")

    # --- Overlapping purposes section
    lines += [
        "---",
        "",
        "## Overlapping Purposes",
        "",
        "Extensions in multiple categories often duplicate functionality already in ww or each other.",
        "",
    ]

    # Find repos that touch ≥2 categories by re-scoring against all rules
    overlap_map: dict[str, list[str]] = {}
    for r in all_repos:
        cats = set()
        combined = f"{r.get('description','') or ''} {r.get('_readme','')}"
        lower = combined.lower()
        for keyword, cat in CATEGORY_RULES:
            if keyword in lower:
                cats.add(cat)
        if len(cats) >= 2:
            name = r["full_name"]
            overlap_map[name] = sorted(cats)

    if overlap_map:
        lines += ["| Repo | Categories |", "|------|------------|"]
        for name, cats in sorted(overlap_map.items()):
            cat_labels = ", ".join(CATEGORY_LABELS.get(c, c) for c in cats)
            slug = name.replace("/", "-")
            lines.append(f"| [{name}](repos/{slug}.md) | {cat_labels} |")
    else:
        lines.append("_No overlapping extensions detected._")

    lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--token", default="", help="GitHub PAT (defaults to gh auth token)")
    parser.add_argument("--out",   default="docs/taskwarrior-extensions", help="Output directory")
    args = parser.parse_args()

    token = args.token or gh_token()
    if not token:
        print("Warning: no GitHub token found; rate limits will be tight.", file=sys.stderr)

    out_dir = Path(args.out)
    repos_dir = out_dir / "repos"
    repos_dir.mkdir(parents=True, exist_ok=True)

    # 1. Search
    print("Searching GitHub for taskwarrior-topic repos …")
    repos = []
    for topic in TOPICS:
        found = search_repos(topic, token)
        print(f"  topic:{topic} → {len(found)} repos")
        repos.extend(found)

    # Deduplicate by full_name
    seen = set()
    unique = []
    for r in repos:
        if r["full_name"] not in seen:
            seen.add(r["full_name"])
            unique.append(r)
    repos = unique
    print(f"  {len(repos)} unique repos total")

    # 2. Fetch READMEs & score
    categorised: dict[str, list[dict]] = {}
    for i, r in enumerate(repos, 1):
        owner, name = r["full_name"].split("/", 1)
        print(f"  [{i}/{len(repos)}] {r['full_name']} …", end=" ", flush=True)

        readme = fetch_readme(owner, name, token)
        r["_readme"] = readme

        combined = f"{r.get('description') or ''} {readme}"
        cat = categorise(combined)
        score, _ = score_ww(combined)
        r["_category"] = cat
        r["_score"]    = score

        print(f"{CATEGORY_LABELS.get(cat, cat)}  score={score}")

        # Write per-repo doc
        slug = r["full_name"].replace("/", "-")
        doc  = repo_md(r, readme)
        (repos_dir / f"{slug}.md").write_text(doc, encoding="utf-8")

        categorised.setdefault(cat, []).append(r)
        time.sleep(0.3)

    # 3. Write index
    idx = index_md(categorised, repos)
    (out_dir / "index.md").write_text(idx, encoding="utf-8")

    # 4. Write machine-readable summary JSON
    summary = []
    for r in repos:
        summary.append({
            "repo":     r["full_name"],
            "url":      r["html_url"],
            "stars":    r.get("stargazers_count", 0),
            "language": r.get("language"),
            "archived": r.get("archived", False),
            "pushed":   (r.get("pushed_at") or "")[:10],
            "category": r["_category"],
            "score":    r["_score"],
            "rating":   rating_label(r["_score"]),
        })
    summary.sort(key=lambda x: x["score"], reverse=True)
    (out_dir / "summary.json").write_text(
        json.dumps(summary, indent=2), encoding="utf-8"
    )

    # 5. Print top 20 by score
    print("\n── Top 20 by Workwarrior integration score ──")
    for entry in summary[:20]:
        print(f"  {entry['score']:+3d}  {entry['rating'][:7]}  {entry['repo']}")

    print(f"\nDone. Output: {out_dir}/")
    print(f"  {out_dir}/index.md          — categorised overview")
    print(f"  {out_dir}/repos/*.md        — per-repo detail")
    print(f"  {out_dir}/summary.json      — machine-readable data")


if __name__ == "__main__":
    main()
