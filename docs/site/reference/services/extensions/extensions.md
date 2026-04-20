# services/extensions/extensions.sh

**Type:** Executed service script
**Invoked by:** `ww extensions taskwarrior <action>`
**Subservient to:** Extensions service (`services/extensions/`)

---

## Role

Registry and discovery for TaskWarrior extensions from the GitHub topic search. Provides search, list, and info commands against a locally cached extension database. The database is populated by `tools/scan-taskwarrior-extensions.py` and stored in `docs/taskwarrior-extensions/summary.json`.

---

## Commands

**`list [--status active]`**
Lists extensions from the registry. `--status active` filters to non-archived repos. Output includes: repo name, stars, language, category, rating, last push date.

**`search <term>`**
Full-text search across repo names, descriptions, and topics in the registry.

**`info <name>`**
Shows the full assessment doc for a specific extension from `docs/taskwarrior-extensions/repos/<name>.md`. Includes: upstream URL, author, license, ww integration rating, scoring notes, README excerpt.

**`refresh`**
Re-runs `tools/scan-taskwarrior-extensions.py` to update the registry from GitHub. Requires a GitHub API token or `gh` CLI auth.

---

## Registry Structure

```
docs/taskwarrior-extensions/
  summary.json          Scored and categorised list of all 185 scanned repos
  index.md              Human-readable index by category
  repos/                Per-repo assessment docs (one .md per repo)
    kdheepak-taskwarrior-tui.md
    hnsstrk-taskwarrior-mcp.md
    ...
```

---

## Scoring

Each repo is scored 0–14 based on keyword overlap with ww's domain:
- +3 for TimeWarrior integration
- +3 for UDA usage
- +2 for hook-based installation
- +2 for sync capability
- +1 each for: shell integration, Python tooling, CLI-first, GitHub integration, reporting, import/export

Score is a relevance signal, not a quality rating. High scores indicate keyword overlap with ww's domain — always read the assessment doc before integrating.

---

## Integration Pattern

When an extension is adopted into ww:
1. A `ww <command>` wrapper is added to `bin/ww`
2. An integration doc is written to `docs/taskwarrior-extensions/<name>-integration.md`
3. The domain is added to `system/config/command-syntax.yaml` with `upstream` and `upstream_author` fields
4. If the extension adds UDAs, they are registered in `system/config/service-uda-registry.yaml` under `extensions:`

## Changelog

- 2026-04-10 — Initial version
