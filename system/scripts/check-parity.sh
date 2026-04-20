#!/usr/bin/env bash
# Gate C — docs / help / CSSOT parity (TASK-QUAL-002)
#
# For each active domain in system/config/command-syntax.yaml, ensures every syntax
# line is reflected in the mapped `ww … help` output (see syntax_matches() for relaxations).
#
# Usage:
#   bash system/scripts/check-parity.sh
#   WW_ROOT=/path/to/ww bash system/scripts/check-parity.sh
#
# Exit 0 on success; exit 1 with stderr details on first set of mismatches.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WW_ROOT="${WW_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
WW_BIN="${WW_BIN:-${WW_ROOT}/bin/ww}"
CSSOT="${CSSOT:-${WW_ROOT}/system/config/command-syntax.yaml}"

if [[ ! -f "$WW_BIN" ]]; then
  echo "check-parity: ww not found: $WW_BIN" >&2
  exit 1
fi
if [[ ! -f "$CSSOT" ]]; then
  echo "check-parity: CSSOT missing: $CSSOT" >&2
  exit 1
fi

exec python3 - "$WW_ROOT" "$WW_BIN" "$CSSOT" << 'PY'
import re
import subprocess
import sys
from pathlib import Path

ww_root, ww_bin, cssot = sys.argv[1], sys.argv[2], sys.argv[3]

HELP_ARGV: dict[str, list[str]] = {
    "profile": ["help", "profile"],
    "journal": ["help", "journal"],
    "ledger": ["help", "ledger"],
    "service": ["help", "service"],
    "issues": ["issues", "help"],
    "find": ["help", "find"],
    "group": ["help", "group"],
    "model": ["help", "model"],
    "ctrl": ["help", "ctrl"],
    "extensions": ["help", "extensions"],
    "timew": ["help", "timew"],
    "custom": ["help", "custom"],
    "schedule": ["schedule", "help"],
    "next": ["next", "help"],
    "gun": ["gun", "help"],
    "tui": ["tui", "help"],
    "profile.density": ["profile", "density", "help"],
    "mcp": ["mcp", "help"],
    "questions": ["help", "questions"],
    "browser": ["browser", "--help"],
}


def run_help(argv: list[str]) -> str:
    import os

    env = dict(**os.environ)
    env["WW_BASE"] = ww_root
    for k in ("WARRIOR_PROFILE", "WORKWARRIOR_BASE", "TIMEWARRIORDB"):
        env.pop(k, None)
    p = subprocess.run(
        [ww_bin, *argv],
        capture_output=True,
        text=True,
        env=env,
    )
    return (p.stdout or "") + (p.stderr or "")


def syntax_prefix(s: str) -> str:
    s = s.strip()
    if len(s) >= 2 and s[0] == '"' and s[-1] == '"':
        s = s[1:-1]
    cut = s
    for sep in (" <", " ["):
        if sep in cut:
            cut = cut.split(sep)[0]
    return " ".join(cut.split())


def syntax_matches(syn: str, dom: str, blob: str) -> bool:
    """Return True if CSSOT syntax line syn is reflected in help text blob."""
    pre = syntax_prefix(syn)
    if not pre:
        return True
    b = blob.lower()

    if pre.lower() in b:
        return True

    # issues: CSSOT uses i- form; help documents ww issues …
    if pre.startswith("i "):
        alt = ("ww issues " + pre[2:]).split("[")[0].strip().lower()
        if alt in b:
            return True
        first = ("ww issues " + pre[2:].split()[0]).lower() if pre[2:].split() else ""
        return bool(first) and first in b

    # profile: help lists actions without repeating ww profile on every line
    if dom == "profile" and pre.startswith("ww profile "):
        inner = pre[len("ww profile ") :].strip().lower()
        if inner and inner in b:
            return True
        parts = pre.split()
        if len(parts) >= 3:
            verb = parts[2].lower()
            return f"  {verb}" in b or f"ww profile {verb}" in b

    # group / model: same pattern as profile (action tables omit ww <domain> prefix)
    if dom in ("group", "model") and pre.startswith(f"ww {dom} "):
        inner = pre[len(f"ww {dom} ") :].strip().lower()
        if inner and inner in b:
            return True
        parts = pre.split()
        if len(parts) >= 3:
            verb = parts[2].lower()
            if verb in b and f"ww {dom}" in b:
                return True

    # find: Usage line may be the only place with ww find; flags documented without repetition
    if dom == "find" and pre.startswith("ww find "):
        if "ww find" not in b:
            return False
        for tok in pre.split()[2:]:
            if tok.startswith("--") and tok.lower() not in b:
                return False
        return True

    # timew: help summarizes extensions; allow install/remove subcommands without full URL
    if dom == "timew" and pre.startswith("ww timew"):
        if "ww timew" not in b and "timew" not in b:
            return False
        if "extensions install https://" in pre.lower():
            return "extensions install" in b
        if pre.lower() in ("ww timew extensions help", "ww timew help"):
            return "extensions" in b and "help" in b
        return pre.lower() in b

    # questions: help may show q-commands without repeating every synonym
    if dom == "questions" and pre.startswith("q"):
        if pre.lower() in b:
            return True
        return "q" in b and "questions" in b

    return False


def parse_cssot(path: str) -> list[dict]:
    text = Path(path).read_text(encoding="utf-8")
    domains: list[dict] = []
    cur: dict | None = None
    in_syntax = False

    for raw in text.splitlines():
        line = raw.rstrip("\n")
        if re.match(r"^  - domain:\s*\"", line):
            if cur is not None:
                domains.append(cur)
            m = re.match(r"^  - domain:\s*\"([^\"]+)\"", line)
            cur = {"name": m.group(1), "syntax": [], "status": "active"}
            in_syntax = False
            continue
        if cur is None:
            continue
        if re.match(r"^\s{4}syntax:\s*$", line):
            in_syntax = True
            continue
        if in_syntax and (m := re.match(r"^\s{6}-\s+\"(.+)\"\s*$", line)):
            cur["syntax"].append(m.group(1))
            continue
        if in_syntax and re.match(r"^\s{4}[a-z_]+:\s*", line):
            in_syntax = False
        mst = re.match(r"^\s{4}status:\s*\"([^\"]+)\"\s*$", line)
        if mst and cur is not None:
            cur["status"] = mst.group(1)
    if cur is not None:
        domains.append(cur)
    return domains


def main() -> int:
    failures: list[str] = []
    domains = parse_cssot(cssot)
    yaml_names = {d["name"] for d in domains}
    unmapped = sorted(n for n in yaml_names if n not in HELP_ARGV)
    if unmapped:
        print(
            "check-parity: WARNING — CSSOT domain(s) without help mapping: "
            + ", ".join(unmapped)
            + " (extend HELP_ARGV in system/scripts/check-parity.sh)",
            file=sys.stderr,
        )

    for d in domains:
        if d.get("status") != "active":
            continue
        dom = d["name"]
        argv = HELP_ARGV.get(dom)
        if argv is None:
            continue
        blob = run_help(argv).lower()
        if not blob.strip():
            failures.append(f"domain={dom}: empty help for argv={' '.join(argv)}")
            continue
        for syn in d["syntax"]:
            pre = syntax_prefix(syn)
            if not pre:
                continue
            if not syntax_matches(syn, dom, blob):
                failures.append(
                    f"domain={dom}: syntax not found in help\n"
                    f"  cssot:  {syn!r}\n"
                    f"  prefix: {pre!r}\n"
                    f"  help:   ww {' '.join(argv)}\n"
                )

    if failures:
        print("check-parity: FAIL — Gate C syntax/help mismatches\n", file=sys.stderr)
        for f in failures:
            print(f, file=sys.stderr)
        return 1
    print("check-parity: OK — active CSSOT syntax prefixes found in mapped help text")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY
