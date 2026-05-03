# bookbuilder

Turns saved content from multiple sources into a searchable, AI-analysed knowledge base you can query, browse, export, and open in Obsidian.

## What it does

1. **Ingest** — parses exports from Twitter/X, RSS, Pocket, Instapaper, browser bookmarks, and local documents (`.md`, `.txt`, `.docx`); deduplicates by URL and content hash; writes normalised items to `state/`
2. **Fetch** — crawls linked pages and downloads tweet images into `cache/`
3. **Analyze** — sends each item to Claude for summary, tags, entities, tech refs, taxonomy categories, and a quality score
4. **Cluster** — groups items by embedding similarity (HDBSCAN via OpenAI embeddings) and writes clusters to `system/clusters.json`
5. **Build** — generates `knowledge/` (topic digests, author digests, tech registry, search index) and a navigable static `site/`
6. **Agents** — multi-agent pass that synthesises, critiques, and connects across the corpus

Run all stages with `bookbuilder run`, or each stage individually.

## Setup

```bash
pip install -e .
export ANTHROPIC_API_KEY=...
export OPENAI_API_KEY=...        # needed for embeddings + semantic search
```

## Input sources

Drop files into `input/` — source type is auto-detected from filename and extension:

| File | Source |
|---|---|
| `*bookmark*.json` | Twitter/X bookmarks export |
| `*like*.json` | Twitter/X likes export |
| `*.xml` | RSS / Atom feed |
| `pocket*.html` | Pocket export |
| `*.csv` | Instapaper export |
| `bookmarks*.html` | Browser bookmark HTML (Netscape format) |
| `*.md`, `*.markdown` | Markdown documents |
| `*.txt` | Plain text documents |
| `*.docx` | Word documents |

Or ingest a single URL directly:

```bash
bookbuilder add https://example.com/article
```

## CLI

```
bookbuilder status
bookbuilder add      <URL ...>
bookbuilder ingest   [--input FILE ...] [--source bookmark|like|rss|pocket|instapaper|bookmarks_html]
bookbuilder fetch    [--workers N] [--stale-after DAYS] [--force]
bookbuilder analyze  [--batch N] [--since DATE] [--cluster ID] [--force]
bookbuilder cluster  [--force]
bookbuilder build    [--force]
bookbuilder agents   [--only AGENT ...] [--force]
bookbuilder taxonomy apply [--dry-run]
bookbuilder inbox    [--status unread|read|want_to_read|archived] [--limit N]
bookbuilder mark     <ID ...> <status>
bookbuilder search   [TERM ...] [--limit N] [--min-score F] [--category CAT] [--author HANDLE] [--tech TECH] [--semantic]
bookbuilder export   [--format md|html] [--category CAT] [--author HANDLE] [--cluster ID] [--min-score F] [--limit N] [--output FILE]
bookbuilder obsidian [--vault PATH] [--no-items] [--min-score F]
bookbuilder watch    [--interval SECONDS] [--run-once]
bookbuilder watch install [--interval MINUTES]
bookbuilder run      [--stale-after DAYS] [--force]
bookbuilder mcp      # start MCP server (stdio) for Claude integration
```

Global flags: `--dry-run`, `--verbose`

### Targeted re-analysis

```bash
bookbuilder analyze --since 2024-06-01          # only items ingested after this date
bookbuilder analyze --cluster cluster_007        # only items in one cluster
bookbuilder search "long context transformers" --semantic   # embedding similarity search
```

### Reading list

```bash
bookbuilder inbox                        # show unread items, highest quality first
bookbuilder inbox --status want_to_read
bookbuilder mark 1a2b3c4d read           # mark by ID prefix
```

### Background scheduling

```bash
bookbuilder watch install --interval 15  # install launchd plist (macOS), runs every 15 min
launchctl load ~/Library/LaunchAgents/com.bookbuilder.watch.plist
```

Or run the watcher directly:

```bash
bookbuilder watch --interval 60          # poll every 60 seconds
```

## Agents

`bookbuilder agents` runs a multi-agent analysis pass after build. Each agent has a focused job:

| Agent | Output | Description |
|---|---|---|
| `item_critic` | updates items in place | Re-scores low-confidence and uncategorized items using cluster context |
| `cluster_analyst` | `knowledge/clusters/*.md` | Writes narrative synthesis, "so what", and open questions per cluster |
| `digest_writer` | prepends to `knowledge/topics/**/*.md` | AI-written intro paragraph for each topic digest |
| `highlight_curator` | `knowledge/highlights/**/*.md` | Editorially selects the best N items per topic from a scored pool |
| `connection_finder` | `knowledge/connections.md` | Finds cross-cluster tech bridges and author patterns |
| `gap_detector` | `knowledge/gaps.md` | Identifies thin categories and underrepresented topics |
| `taxonomy_evolver` | `system/notes/taxonomy_proposals.md` | Proposes new subcategories from uncategorized/noise items |

Run a single agent:

```bash
bookbuilder agents --only item_critic
bookbuilder agents --only cluster_analyst digest_writer
```

## MCP server

`bookbuilder mcp` starts a stdio MCP server for Claude Desktop / Claude Code:

| Tool | Description |
|---|---|
| `search_knowledge` | Keyword search across summaries, tags, tweet text |
| `semantic_search_knowledge` | Embedding similarity search |
| `get_item` | Full details for one item by ID |
| `list_clusters` | All named topic clusters |
| `get_cluster` | Full cluster analysis including agent synthesis |
| `find_by_tech` | Items referencing a specific technology |
| `find_by_author` | Items from a specific Twitter/X handle |
| `find_by_category` | Items in a taxonomy category (prefix matching) |
| `get_connections` | Cross-cluster connection analysis |
| `get_gaps` | Knowledge gap analysis |
| `reload_index` | Refresh in-memory index after a pipeline run |

## Configuration

| File | Purpose |
|---|---|
| `system/config.yaml` | AI models, API keys, fetch settings, agent thresholds |
| `system/pipeline.yaml` | Enable/disable stages and per-stage options |
| `system/taxonomy.yaml` | Classification schema — categories, subcategories, keywords |
| `system/skip_domains.txt` | Domains never fetched |
| `system/prompts/analyze.md` | Analysis prompt template |
| `system/prompts/agents/*.md` | One prompt file per agent |
| `system/notes/roadmap.md` | What's next |
| `system/notes/decisions.md` | Architectural decision log |
| `system/notes/changelog.md` | Version history |
| `system/notes/technical_overview.md` | Full internal reference |

## Output structure

```
knowledge/
  items/          one JSON per item
  clusters/       one markdown per cluster (agent synthesis)
  highlights/     curated highlight picks per topic
  topics/         markdown digest per taxonomy subcategory
  authors/        markdown digest per author (3+ items)
  tech/           markdown page per referenced technology
  connections.md  cross-cluster connection analysis
  gaps.md         knowledge gap analysis
  index.json      Fuse.js-ready search index
site/
  index.html      search interface
  topics.html     topic index
  authors.html    author index (filterable, sortable)
  clusters.html   cluster index
  topics/         one page per topic digest
  authors/        one page per author
  clusters/       one page per cluster
vault/            Obsidian-compatible vault (bookbuilder obsidian)
```

## Development

```bash
pip install -e ".[dev]"
python -m pytest tests/
```
