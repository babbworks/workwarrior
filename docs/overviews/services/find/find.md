# services/find/find.sh + find.py

**Type:** Executed service script + Python implementation
**Invoked by:** `ww find <term>`, `search <term>` shell function
**Subservient to:** Find service (`services/find/`)

---

## Role

Cross-profile and cross-tool search. Searches across TaskWarrior tasks, TimeWarrior entries, JRNL journals, and Hledger ledgers for a given term. Can target a specific profile, data type, or use native tool search where available.

---

## Command Surface

```
ww find <term>                    Search active/last profile, all data types
ww find --type <type> <term>      Search specific type: task|time|journal|ledger
ww find --profile <name> <term>   Search a specific profile without activating it
ww find --query <expr>            Advanced query syntax
ww find --case-sensitive <term>   Case-sensitive matching
ww find --regex <term>            Treat term as regex
ww find --exclude <glob> <term>   Exclude matching paths (repeatable)
ww find --native <term>           Use native tool search (task, timew, jrnl)
```

---

## Implementation Split

`find.sh` — bash dispatcher. Parses flags, resolves profile scope, calls `find.py` with the appropriate arguments.

`find.py` — Python implementation. Handles the actual search logic:
- **Tasks:** `task export` JSON, filters by description/project/tags/annotations
- **Time:** `timew export` JSON, filters by tags
- **Journals:** reads JRNL files directly, line-by-line search
- **Ledger:** `hledger` register output, text search

`installed-pythons.sh` — detects available Python interpreters. `find.py` requires Python 3.

---

## Native Search Mode

`--native` delegates to each tool's own search:
- Tasks: `task <term>` (uses TaskWarrior's filter syntax)
- Time: `timew summary :ids` with tag filter
- Journals: `jrnl <term>`

Native mode is faster for simple searches but doesn't support cross-type results.

---

## Profile Scope

Without `--profile`, uses the active profile (or last profile). With `--profile <name>`, sets `TASKRC`/`TASKDATA`/`TIMEWARRIORDB` to that profile's paths without activating it — the current shell profile is unchanged.
