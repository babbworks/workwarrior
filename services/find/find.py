#!/usr/bin/env python3
import argparse
import json
import os
import re
import shlex
import sys
from collections import defaultdict
from pathlib import Path


WW_BASE = Path(os.environ.get("WW_BASE", Path.home() / "ww"))
PROFILES_DIR = Path(os.environ.get("PROFILES_DIR", WW_BASE / "profiles"))
WW_GLOBAL_BASE = Path(os.environ.get("WW_GLOBAL_BASE", WW_BASE / "global"))
FIND_QUERIES = WW_BASE / "config" / "find-queries.yaml"


def load_queries():
    if not FIND_QUERIES.exists():
        return {}
    queries = {}
    for line in FIND_QUERIES.read_text().splitlines():
        if line.strip().startswith("#") or not line.strip():
            continue
        if line.strip() == "queries:":
            continue
        if line.startswith("  "):
            key, _, val = line.strip().partition(": ")
            if key and val:
                if val.startswith('"') and val.endswith('"'):
                    val = val[1:-1]
                queries[key] = val
    return queries


def save_query(name, query):
    FIND_QUERIES.parent.mkdir(parents=True, exist_ok=True)
    queries = load_queries()
    queries[name] = query
    lines = ["queries:"]
    for k in sorted(queries.keys()):
        v = queries[k].replace('"', '\\"')
        lines.append(f'  {k}: "{v}"')
    FIND_QUERIES.write_text("\n".join(lines) + "\n")


def tokenize_query(expr):
    expr = expr.replace("(", " ( ").replace(")", " ) ")
    return shlex.split(expr)


def parse_pipe(query):
    parts = []
    current = ""
    in_quote = False
    quote_char = ""
    for ch in query:
        if ch in ("'", '"'):
            if in_quote and ch == quote_char:
                in_quote = False
            elif not in_quote:
                in_quote = True
                quote_char = ch
        if ch == "|" and not in_quote:
            parts.append(current.strip())
            current = ""
        else:
            current += ch
    if current.strip():
        parts.append(current.strip())
    return parts


def shunting_yard(tokens):
    out = []
    ops = []
    prec = {"NOT": 3, "AND": 2, "OR": 1}
    i = 0
    while i < len(tokens):
        t = tokens[i]
        upper = t.upper()
        if upper in ("AND", "OR", "NOT"):
            while ops and ops[-1] != "(" and prec.get(ops[-1], 0) >= prec[upper]:
                out.append(ops.pop())
            ops.append(upper)
        elif t == "(":
            ops.append(t)
        elif t == ")":
            while ops and ops[-1] != "(":
                out.append(ops.pop())
            if ops and ops[-1] == "(":
                ops.pop()
        else:
            out.append(t)
        i += 1
    while ops:
        out.append(ops.pop())
    return out


def build_predicate(token, use_regex=False, case_sensitive=False):
    if token.startswith("type:"):
        v = token.split(":", 1)[1]
        return lambda line, meta: meta["type"] == v
    if token.startswith("profile:"):
        v = token.split(":", 1)[1]
        return lambda line, meta: meta["profile"] == v
    if token.startswith("path:"):
        v = token.split(":", 1)[1]
        return lambda line, meta: Path(meta["path"]).match(v)
    if token.startswith("regex:") or token.startswith("re:"):
        v = token.split(":", 1)[1]
        flags = 0 if case_sensitive else re.IGNORECASE
        reg = re.compile(v, flags)
        return lambda line, meta: bool(reg.search(line))
    if token.startswith("date:"):
        v = token.split(":", 1)[1]
        return lambda line, meta: v in line
    if use_regex:
        flags = 0 if case_sensitive else re.IGNORECASE
        reg = re.compile(token, flags)
        return lambda line, meta: bool(reg.search(line))
    if case_sensitive:
        return lambda line, meta: token in line
    # default literal term (case-insensitive)
    lit = token.lower()
    return lambda line, meta: lit in line.lower()


def eval_rpn(rpn, line, meta, use_regex=False, case_sensitive=False):
    stack = []
    for t in rpn:
        if t in ("AND", "OR", "NOT"):
            if t == "NOT":
                a = stack.pop() if stack else False
                stack.append(not a)
            else:
                b = stack.pop() if stack else False
                a = stack.pop() if stack else False
                stack.append(a and b if t == "AND" else a or b)
        else:
            pred = build_predicate(t, use_regex=use_regex, case_sensitive=case_sensitive)
            stack.append(pred(line, meta))
    return stack[-1] if stack else False


def parse_query(expr):
    tokens = tokenize_query(expr)
    # Insert implicit AND
    expanded = []
    prev_term = False
    for t in tokens:
        is_term = t not in ("AND", "OR", "NOT", "(", ")")
        if prev_term and is_term:
            expanded.append("AND")
        expanded.append(t)
        prev_term = is_term or t == ")"
    return shunting_yard(expanded)


def gather_profiles(target_profiles):
    if target_profiles:
        return target_profiles
    if not PROFILES_DIR.exists():
        return []
    return sorted([p.name for p in PROFILES_DIR.iterdir() if p.is_dir()])


def files_for_type(base, t):
    if t == "journal":
        return list((base / "journals").glob("*.txt"))
    if t == "ledger":
        return list((base / "ledgers").glob("*.journal"))
    if t == "list":
        return list((base / "list").glob("*.list"))
    if t == "task":
        return []
    if t == "time":
        return []
    return []


def extract_native_terms(query_expr):
    tokens = tokenize_query(query_expr)
    terms = []
    for t in tokens:
        upper = t.upper()
        if upper in ("AND", "OR", "NOT", "(", ")"):
            continue
        if any(t.startswith(prefix) for prefix in ("type:", "profile:", "path:", "date:", "re:", "regex:")):
            continue
        terms.append(t)
    return terms


def run_cmd(cmd, env=None):
    import subprocess
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, env=env, check=False)
        return res.stdout.strip()
    except Exception:
        return ""


def native_task(profile, base, query_expr):
    env = os.environ.copy()
    env["TASKRC"] = str(base / ".taskrc")
    env["TASKDATA"] = str(base / ".task")
    terms = extract_native_terms(query_expr) or [query_expr]
    cmd = ["task", "rc.verbose=nothing"] + [f"/{t}/" for t in terms] + ["list"]
    out = run_cmd(cmd, env=env)
    return out.splitlines()


def native_time(profile, base, query_expr):
    env = os.environ.copy()
    env["TIMEWARRIORDB"] = str(base / ".timewarrior")
    args = shlex.split(query_expr) if query_expr else []
    cmd = ["timew", "summary"] + args
    out = run_cmd(cmd, env=env)
    return out.splitlines()


def native_journal(profile, base, query_expr):
    jrnl_config = base / "jrnl.yaml"
    if not jrnl_config.exists():
        return []
    terms = extract_native_terms(query_expr) or [query_expr]
    query = " ".join(terms)
    cmd = ["jrnl", "--config-file", str(jrnl_config), "-contains", query]
    out = run_cmd(cmd)
    return out.splitlines()


def native_ledger(profile, base, query_expr):
    ledgers_yaml = base / "ledgers.yaml"
    ledger_file = None
    if ledgers_yaml.exists():
        for line in ledgers_yaml.read_text().splitlines():
            if line.startswith("  default:"):
                ledger_file = line.split(":", 1)[1].strip()
                break
    if not ledger_file:
        return []
    args = shlex.split(query_expr) if query_expr else []
    cmd = ["hledger", "-f", ledger_file, "register"] + args
    out = run_cmd(cmd)
    return out.splitlines()


def search_files(files, rpn, meta_base, context=0, max_hits=None, use_regex=False, case_sensitive=False, excludes=None):
    hits = []
    for f in files:
        if excludes:
            skip = False
            for ex in excludes:
                if f.match(ex):
                    skip = True
                    break
            if skip:
                continue
        if not f.exists():
            continue
        try:
            lines = f.read_text(errors="ignore").splitlines()
        except Exception:
            continue
        for idx, line in enumerate(lines, start=1):
            meta = dict(meta_base)
            meta["path"] = str(f)
            if eval_rpn(rpn, line, meta, use_regex=use_regex, case_sensitive=case_sensitive):
                ctx_before = []
                ctx_after = []
                if context > 0:
                    start = max(0, idx - 1 - context)
                    end = min(len(lines), idx - 1 + context + 1)
                    ctx_before = lines[start:idx - 1]
                    ctx_after = lines[idx:end]
                hits.append({
                    "profile": meta["profile"],
                    "type": meta["type"],
                    "path": str(f),
                    "line": idx,
                    "text": line,
                    "context_before": ctx_before,
                    "context_after": ctx_after,
                })
                if max_hits and len(hits) >= max_hits:
                    return hits
    return hits


def group_hits(hits, group):
    grouped = defaultdict(list)
    for h in hits:
        key = h["profile"] if group == "profile" else h["type"] if group == "type" else "all"
        grouped[key].append(h)
    return grouped


def format_hits(hits, group="profile", context=0, paths_only=False):
    if not hits:
        return ""
    grouped = group_hits(hits, group)
    out = []
    for key in sorted(grouped.keys()):
        if group != "none":
            label = "Profile" if group == "profile" else "Type"
            out.append(f"{label}: {key}")
        for h in grouped[key]:
            rel = h["path"]
            if group == "profile":
                base = (WW_GLOBAL_BASE if h["profile"] == "global" else PROFILES_DIR / h["profile"])
                try:
                    rel = str(Path(h["path"]).relative_to(base))
                except Exception:
                    rel = h["path"]
            if paths_only:
                out.append(f"  {rel}")
            else:
                out.append(f"  {rel}:{h['line']}  {h['text']}")
                if context > 0:
                    for c in h["context_before"]:
                        out.append(f"    | {c}")
                    for c in h["context_after"]:
                        out.append(f"    | {c}")
        out.append("")
    return "\n".join(out).rstrip()


def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--profile", action="append", default=[])
    parser.add_argument("--profiles", default="")
    parser.add_argument("--global", dest="include_global", action="store_true")
    parser.add_argument("--type", dest="types", action="append", default=[])
    parser.add_argument("--query")
    parser.add_argument("--advanced")
    parser.add_argument("--json", dest="json_out", action="store_true")
    parser.add_argument("--case-sensitive", action="store_true")
    parser.add_argument("--regex", dest="regex_mode", action="store_true")
    parser.add_argument("--exclude", action="append", default=[])
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--context", type=int, default=0)
    parser.add_argument("--max", type=int, default=0)
    parser.add_argument("--group", choices=["profile", "type", "none"], default="profile")
    parser.add_argument("--paths-only", action="store_true")
    parser.add_argument("--summary", action="store_true")
    parser.add_argument("--save")
    parser.add_argument("--load")
    parser.add_argument("-h", "--help", action="store_true")
    parser.add_argument("term", nargs="*")
    args = parser.parse_args()

    if args.help:
        print("Usage: ww find [options] <term>")
        print("Options:")
        print("  --query <expr>           Advanced query string")
        print("  --advanced <expr>        Alias for --query")
        print("  --profile <name>         Search a single profile")
        print("  --profiles <a,b,c>       Search a comma-separated list of profiles")
        print("  --global                 Include global workspace")
        print("  --type <t>               Restrict to type: journal|ledger|list|task|time|all")
        print("  --context <n>            Include context lines")
        print("  --max <n>                Limit number of results")
        print("  --group profile|type|none Group output")
        print("  --json                   JSON output")
        print("  --paths-only             Only show file paths")
        print("  --summary                Show counts by profile/type")
        print("  --case-sensitive         Case-sensitive matching")
        print("  --regex                  Treat bare terms as regex")
        print("  --exclude <glob>         Exclude matching paths (repeatable)")
        print("  --native                 Use native tool search where available")
        print("  --save <name>            Save query")
        print("  --load <name>            Load saved query")
        sys.exit(0)

    if args.load:
        q = load_queries().get(args.load)
        if not q:
            print(f"Error: Query not found: {args.load}", file=sys.stderr)
            sys.exit(1)
        expr = q
    elif args.query:
        expr = args.query
    elif args.advanced:
        expr = args.advanced
    else:
        if not args.term:
            print("Error: Search term required", file=sys.stderr)
            sys.exit(1)
        expr = " ".join(args.term)

    if args.save:
        save_query(args.save, expr)

    parts = parse_pipe(expr)
    query_expr = parts[0]
    transforms = parts[1:]

    # apply pipe transforms
    for t in transforms:
        t = t.strip()
        if t.startswith("head"):
            _, _, n = t.partition(" ")
            if n.isdigit():
                args.max = int(n)
        elif t.startswith("group"):
            _, _, grp = t.partition(" ")
            if grp in ("profile", "type", "none"):
                args.group = grp
        elif t == "json":
            args.json_out = True
        elif t == "summary":
            args.summary = True

    types = args.types or ["journal", "ledger", "list"]
    if "all" in types:
        types = ["journal", "ledger", "list", "task", "time"]

    profiles = []
    if args.profiles:
        profiles.extend([p for p in args.profiles.split(",") if p])
    profiles.extend(args.profile or [])
    profiles = [p for p in profiles if p]

    rpn = parse_query(query_expr)
    hits = []

    for profile in gather_profiles(profiles):
        base = PROFILES_DIR / profile
        if not base.exists():
            continue
        for t in types:
            remaining = None
            if args.max:
                remaining = max(args.max - len(hits), 0)
                if remaining == 0:
                    break
            if args.native and t in ("task", "time", "journal", "ledger"):
                if t == "task":
                    lines = native_task(profile, base, query_expr)
                elif t == "time":
                    lines = native_time(profile, base, query_expr)
                elif t == "journal":
                    lines = native_journal(profile, base, query_expr)
                else:
                    lines = native_ledger(profile, base, query_expr)
                for idx, line in enumerate(lines, start=1):
                    hits.append({
                        "profile": profile,
                        "type": t,
                        "path": f"{t}",
                        "line": idx,
                        "text": line,
                        "context_before": [],
                        "context_after": [],
                    })
                    if remaining and len(hits) >= args.max:
                        break
            else:
                files = files_for_type(base, t)
                hits.extend(search_files(
                    files, rpn, {"profile": profile, "type": t},
                    args.context, remaining, use_regex=args.regex_mode,
                    case_sensitive=args.case_sensitive, excludes=args.exclude
                ))
            if args.max and len(hits) >= args.max:
                break
        if args.max and len(hits) >= args.max:
            break

    if args.include_global:
        base = WW_GLOBAL_BASE
        if base.exists():
            for t in types:
                remaining = None
                if args.max:
                    remaining = max(args.max - len(hits), 0)
                    if remaining == 0:
                        break
                if args.native and t in ("task", "time", "journal", "ledger"):
                    if t == "task":
                        lines = native_task("global", base, query_expr)
                    elif t == "time":
                        lines = native_time("global", base, query_expr)
                    elif t == "journal":
                        lines = native_journal("global", base, query_expr)
                    else:
                        lines = native_ledger("global", base, query_expr)
                    for idx, line in enumerate(lines, start=1):
                        hits.append({
                            "profile": "global",
                            "type": t,
                            "path": f"{t}",
                            "line": idx,
                            "text": line,
                            "context_before": [],
                            "context_after": [],
                        })
                        if remaining and len(hits) >= args.max:
                            break
                else:
                    files = files_for_type(base, t)
                    hits.extend(search_files(
                        files, rpn, {"profile": "global", "type": t},
                        args.context, remaining, use_regex=args.regex_mode,
                        case_sensitive=args.case_sensitive, excludes=args.exclude
                    ))
                if args.max and len(hits) >= args.max:
                    break

    if args.summary:
        counts = defaultdict(int)
        for h in hits:
            key = (h["profile"], h["type"])
            counts[key] += 1
        for (p, t), c in sorted(counts.items()):
            print(f"{p}\t{t}\t{c}")
        sys.exit(0)

    if args.json_out:
        print(json.dumps(hits, indent=2))
        sys.exit(0)

    print(f'Find: "{query_expr}"')
    scope = "profiles=all" if not profiles else "profiles=" + ",".join(profiles)
    types_display = ",".join(types)
    print(f"Scope: {scope}  types={types_display}")
    if args.include_global:
        print("Global: enabled")
    print("")
    out = format_hits(hits, group=args.group, context=args.context, paths_only=args.paths_only)
    if out:
        print(out)
    else:
        print("(no matches)")


if __name__ == "__main__":
    main()
