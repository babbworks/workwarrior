# Changelog

### v0.4.0

### Added
- `bookbuilder watch` — polls `input/` every N seconds, triggers `bookbuilder run` when files are added or changed
- `bookbuilder watch install` — generates a launchd plist at `~/Library/LaunchAgents/com.bookbuilder.watch.plist` for macOS background scheduling
- `bookbuilder inbox` — shows items by read status (unread/read/want_to_read/archived), sorted by quality score
- `bookbuilder mark <id> <status>` — sets read status on one or more items; supports ID prefix matching
- `read_status` and `read_at` fields added to `ItemState`; old JSONL records default to `unread` on load
- `read_status` exposed in MCP `_item_summary` and search index
- `bookbuilder obsidian` — exports knowledge base as an Obsidian-compatible vault with YAML frontmatter, `[[wikilinks]]`, `#tags`, topic/author/cluster/item notes, and a `_index.md` home note
- `bookbuilder run --stale-after DAYS` — threads stale-after through to fetch stage
- `bookbuilder run --force` flag
- CLI search now uses in-memory index when `knowledge/index.json` exists (faster); falls back to file scan for filtered queries

### v0.3.0

### Added
- **Site redesign** — multi-page static site replacing the single search page:
  - Shared nav bar (Search / Topics / Authors / Clusters) on every page
  - `site/topics.html` — tile grid of all topic digests with item counts
  - `site/topics/{cat}__{sub}.html` — topic detail page with highlight cards + full item list
  - `site/authors.html` — tile grid of all authors sorted by item count
  - `site/authors/{handle}.html` — author detail page with their top 30 items as cards
  - `site/clusters.html` — tile grid of all clusters
  - `site/clusters/{id}.html` — cluster detail page with agent synthesis block + top 20 item cards
  - Shared CSS with print-friendly styles; author cards link to author pages
- **`bookbuilder export`** — generates a single long-form digest for reading or sharing
  - `--format md|html` (default: md)
  - `--category`, `--author`, `--cluster` filters
  - `--min-score` (default 0.6), `--limit` (default 200)
  - `--output FILE` or auto-named in project root
  - HTML output is self-contained with inline print CSS (no external deps, prints cleanly)
  - Items grouped by top-level category in both formats
- 20 new tests for export (test_export.py)

### v0.2.2

### Added
- Document ingestion: `.md`, `.txt`, `.docx` files in `input/` are now ingested as items
  - Headings extracted as a structured outline prepended to the text — AI sees document structure before body
  - `.docx` uses `python-docx`; heading styles (`Heading 1/2/3`) map to outline depth
  - `_detect_source()` dispatches on file extension; `iter_raw_items()` handles all types
  - `run_ingest` and `cmd_run` now glob all supported extensions, not just `*.json`
- `bookbuilder fetch --stale-after DAYS` — re-fetches pages last crawled more than N days ago
- Smarter `bookbuilder run` — per-stage dirty flags: each stage checks actual pending state rather than just whether ingest produced new items; fetch/analyze/cluster/build/agents each gate independently
- `highlight_curator` agent — asks Claude to editorially select the best N items per topic from a pool of top-scored candidates; writes to `knowledge/highlights/{cat}/{subcat}.md`
- `system/prompts/agents/highlight_curator.md` prompt
- `python-docx` added to dependencies
- 14 new tests for document parsing (test_documents.py)

### v0.2.1

### Added
- `bookbuilder status` — one-screen corpus health summary: item counts per pipeline stage, last-run timestamps, quality score distribution, cluster stats, agent output presence, build output counts
- `bookbuilder taxonomy apply` — interactive review and application of `taxonomy_proposals.md` to `taxonomy.yaml`; parses structured proposal blocks, checks for existing keys, inserts accepted proposals at the correct YAML location; `--dry-run` flag
- MCP server in-memory index: `knowledge/index.json` loaded at startup, all search/find tools now query from memory instead of scanning item files; `reload_index` MCP tool to refresh without restarting the server

## v0.2.0

### Added
- `bookbuilder/agents/` package: multi-agent analysis layer
  - `item_critic` — re-scores low-confidence and uncategorized items with cluster context
  - `cluster_analyst` — writes narrative synthesis for each cluster → `knowledge/clusters/`
  - `digest_writer` — prepends AI-written intro to each topic digest
  - `connection_finder` — finds cross-cluster tech/author bridges → `knowledge/connections.md`
  - `gap_detector` — identifies thin categories and underrepresented topics → `knowledge/gaps.md`
  - `taxonomy_evolver` — proposes new subcategories from uncategorized/noise items → `system/notes/taxonomy_proposals.md`
- Agent manifest with incremental checkpointing every 50 items (crash-safe for item_critic)
- Cluster prerequisite gate: agents that need clusters.json skip with a clear message
- Source expansion in `ingest.py`: RSS/Atom XML, Pocket HTML export, Instapaper CSV, browser bookmark HTML (Netscape format)
- `bookbuilder add <url>` — ingest one or more URLs directly without an export file
- `bookbuilder analyze --since DATE` — only re-analyze items ingested on or after a date
- `bookbuilder analyze --cluster ID` — only re-analyze items in a specific cluster
- `bookbuilder search --semantic` — cosine similarity search using the embedding cache
- MCP server: `semantic_search_knowledge`, `get_cluster`, `get_connections`, `get_gaps` tools
- `system/notes/` directory: roadmap.md, decisions.md, changelog.md
- `system/prompts/agents/` directory: one prompt file per agent

### Fixed
- `models.py` was a stub — replaced with full dataclass definitions for all pipeline models
- `pyproject.toml` had invalid `[project.dependencies]` table syntax — fixed to array format
- `bookbuilder/__init__.py` had prose text causing SyntaxError — fixed

## v0.1.0

- Initial pipeline: ingest → fetch → analyze → cluster → build → search
- MCP server with 6 tools
- Static site with Fuse.js search
