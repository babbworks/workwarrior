# Technical Overview

A detailed reference for how bookbuilder works internally — data flow, storage layout, module responsibilities, and design decisions. For a general introduction see `README.md`.

---

## Table of contents

1. [Architecture summary](#1-architecture-summary)
2. [Directory layout](#2-directory-layout)
3. [Data model](#3-data-model)
4. [Pipeline stages](#4-pipeline-stages)
5. [Agent system](#5-agent-system)
6. [Search](#6-search)
7. [MCP server](#7-mcp-server)
8. [Configuration system](#8-configuration-system)
9. [Incremental execution and manifests](#9-incremental-execution-and-manifests)
10. [External dependencies](#10-external-dependencies)

---

## 1. Architecture summary

bookbuilder is a local-first, file-based pipeline. There is no database. Every piece of state is a file on disk — JSON, JSONL, Markdown, or YAML. This makes the system inspectable, debuggable, and trivially backed up.

The pipeline has two distinct phases:

**Build phase** (`ingest → fetch → analyze → cluster → build`) — transforms raw input files into a structured knowledge base. Each stage reads from and writes to `knowledge/items/{id}.json`, enriching items in place. Stages are independently re-runnable; completed work is skipped unless `--force` is passed.

**Query phase** (`search`, `mcp`) — reads the built knowledge base without modifying it. The MCP server is a persistent process that exposes the knowledge base as a structured API to Claude.

**Agent phase** (`agents`) — runs after build. Agents perform cross-item and cross-cluster reasoning that the single-item analysis pass cannot do. They write synthesis documents to `knowledge/` and `system/notes/`.

```
input/          ─── ingest ──► state/items.jsonl
                               knowledge/items/*.json
                                    │
                               fetch ──► cache/pages/  cache/images/
                                    │
                               analyze ──► knowledge/items/*.json (enriched)
                                    │
                               cluster ──► cache/embeddings/items.json
                                          system/clusters.json
                                    │
                               build ──► knowledge/topics/  authors/  tech/
                                         knowledge/index.json
                                         site/
                                    │
                               agents ──► knowledge/clusters/  connections.md  gaps.md
                                          system/notes/taxonomy_proposals.md
```

---

## 2. Directory layout

```
bookbuilder/          Python package
  cli.py              Entry point, argparse dispatch
  models.py           All dataclasses (RawItem, Item, Analysis, ...)
  store.py            Read/write Item to knowledge/items/{id}.json
  config.py           YAML loaders (cached with lru_cache)
  ingest.py           Source parsers → RawItem normalisation
  fetch.py            Async HTTP crawler, readability extraction
  analyze.py          Claude API calls, prompt rendering
  cluster.py          OpenAI embeddings, HDBSCAN, cluster naming
  build.py            Markdown digest generation, search index, static site
  search.py           Keyword scoring + cosine similarity search
  mcp_server.py       FastMCP stdio server
  agents/
    base.py           Agent ABC, _AgentManifest
    runner.py         Orchestrator, dependency gates
    item_critic.py
    cluster_analyst.py
    digest_writer.py
    connection_finder.py
    gap_detector.py
    taxonomy_evolver.py

input/                Drop source files here
state/
  items.jsonl         Pipeline state for every item (one JSON object per line)
  build_manifest.json Fingerprints for build stage incremental skipping
  agents_manifest.json Fingerprints for agent stage incremental skipping
cache/
  pages/              {url_hash}.txt + {url_hash}.meta.json per fetched page
  images/             {item_id}_{n}.ext per downloaded image
  embeddings/
    items.json        {item_id: [float, ...]} — flat embedding cache
knowledge/
  items/              {id}.json — one file per item, single source of truth
  clusters/           {cluster_id}.md — agent synthesis per cluster
  topics/             {cat}/{subcat}.md — topic digests
  authors/            {handle}.md — per-author digests
  tech/               {slug}.md — per-technology pages
  connections.md      Cross-cluster connection analysis
  gaps.md             Knowledge gap analysis
  index.json          Fuse.js search index
site/                 Static HTML site
system/
  config.yaml         Runtime configuration
  pipeline.yaml       Stage enable/disable and per-stage options
  taxonomy.yaml       Classification schema
  skip_domains.txt    Domains never fetched
  clusters.json       Cluster registry (written by cluster stage)
  prompts/
    analyze.md        Analysis prompt template
    agents/           One .md prompt per agent
  notes/
    roadmap.md
    decisions.md
    changelog.md
    taxonomy_proposals.md   Written by taxonomy_evolver agent
```

---

## 3. Data model

All models are Python dataclasses defined in `models.py`. There is no ORM or schema validation library — the dataclasses are the schema.

### RawItem

Produced by ingest parsers before deduplication. Never persisted directly.

```
id            str    Tweet ID (from URL) or SHA-256[:16] of URL for non-tweet sources
source        str    bookmark | like | rss | pocket | instapaper | bookmarks_html | manual
url           str    Canonical URL
text          str    Raw tweet text or article title+excerpt
author_raw    str    Raw author string from source (e.g. "Alice @alice_dev")
timestamp     str    ISO 8601 or Unix timestamp string from source
links         list   Resolved URLs from tweet text or card
card_url      str    Link card URL
card_title    str    Link card title
card_desc     str    Link card description
quote         QuoteRef | None   Quoted tweet, if present
content_hash  str    SHA-256[:16] of (url + "|" + text) — used for dedup
```

`author_name` and `author_handle` are computed properties that parse `author_raw`.

### Item

The core persistent record. Written by ingest, enriched in place by every subsequent stage. Stored as `knowledge/items/{id}.json`.

```
id, source, url, text, author_name, author_handle, timestamp
links         list[str]
card_url, card_title, card_desc
quote         QuoteRef | None
fetched_pages list[FetchedPage]   Added by fetch stage
images        list[FetchedImage]  Added by fetch stage
analysis      Analysis | None     Added by analyze stage
state         ItemState | None    Pipeline status flags
```

`all_urls` is a computed property returning deduplicated `links + [card_url]`.

### Analysis

Written by the analyze stage, updated in place by `item_critic`.

```
summary       str    1–2 sentence plain-English summary
tags          list   3–6 lowercase hyphenated keyword tags
entities      Entities   people, orgs, concepts, places
tech_refs     TechRefs   languages, frameworks, tools, packages, repos, hardware, platforms
categories    list   1–2 taxonomy paths (e.g. ["ai_ml/ai_tools"])
quality_score float  0.0–1.0 signal value score
cluster_id    str | None   Written by cluster stage
analyzed_at   str    ISO 8601 timestamp
model         str    Model name used for this analysis
```

### ItemState

Lightweight pipeline status record. Stored in `state/items.jsonl` (one JSON object per line, not a JSON array). Kept separate from the item JSON so state can be loaded cheaply without reading all item content.

```
item_id         str
content_hash    str    Used to detect content changes on re-ingest
source          str
ingested_at     str
fetch_status    str    pending | ok | error
analyze_status  str    pending | ok | error
fetched_at      str
analyzed_at     str
```

### FetchedPage / FetchedImage

```
FetchedPage:
  url, title, text_path (path to cache/pages/{hash}.txt), word_count, fetched_at, status

FetchedImage:
  url, path (path to cache/images/{id}_{n}.ext), fetched_at, status
```

---

## 4. Pipeline stages

### 4.1 Ingest (`ingest.py`)

**Input:** files in `input/` or explicit `--input` paths, or a URL via `bookbuilder add`

**Output:** entries in `state/items.jsonl`, base `knowledge/items/{id}.json` files

Source type is detected from filename and extension:

| Extension / filename pattern | Parser |
|---|---|
| `*bookmark*.json`, `*like*.json` | Twitter/X JSON (two schema variants) |
| `*.xml` | RSS 2.0 / Atom |
| `pocket*.html` | Pocket export HTML |
| `*.csv` | Instapaper CSV |
| `bookmarks*.html` | Netscape bookmark HTML |
| URL string | `_make_url_item()` — creates a minimal RawItem |

All parsers normalise to `RawItem` at the ingest boundary. Everything downstream is source-agnostic.

**Deduplication** happens in two passes:
1. By tweet ID — if the same ID exists in state, content hash is compared. If unchanged, skip. If changed, reset `fetch_status` and `analyze_status` to `pending`.
2. By content hash across sources — if the same tweet appears in both bookmarks and likes exports, the second occurrence is skipped and the first item's `source` is updated to `"both"`.

For non-tweet sources (RSS, Pocket, etc.) the ID is `SHA-256[:16]` of the URL, so the same URL from two different sources deduplicates correctly.

### 4.2 Fetch (`fetch.py`)

**Input:** `state/items.jsonl` (items with `fetch_status != "ok"`)

**Output:** `cache/pages/`, `cache/images/`, updated `knowledge/items/{id}.json`

Uses `httpx.AsyncClient` with a configurable semaphore (`fetch.workers`, default 8) for concurrency. For each item:

1. Collects all URLs from `item.all_urls` (links + card_url), filters against `skip_domains.txt`
2. For each page URL: checks cache first (by URL hash), fetches if missing, extracts readable text via `readability-lxml`, saves to `cache/pages/{hash}.txt` with a `.meta.json` sidecar
3. For image URLs (pbs.twimg.com patterns + direct image links): downloads to `cache/images/{item_id}_{n}.ext`, capped at 5 images per item and `image_max_kb` size limit
4. Writes `FetchedPage` and `FetchedImage` records back to the item JSON

Page text is truncated to `fetch.max_content_chars` (default 20,000) before storage to keep the cache manageable and avoid sending huge documents to the AI.

### 4.3 Analyze (`analyze.py`)

**Input:** items with `analyze_status != "ok"` (filtered by optional `--since` / `--cluster`)

**Output:** `analysis` field populated in `knowledge/items/{id}.json`

The prompt template is loaded from `system/prompts/analyze.md` at runtime, making it editable without touching code. Variables substituted at render time:

```
{text}                 item.text
{fetched_title}        first ok FetchedPage title
{fetched_text}         first 800 chars of cached page text
{card_title}           item.card_title
{card_desc}            item.card_desc
{taxonomy_categories}  flat list of all valid category paths from taxonomy.yaml
```

The response is expected to be a JSON object. `_extract_json()` tries three strategies in order: direct parse, markdown code block extraction, outermost-brace extraction. This handles Claude occasionally wrapping the JSON in prose.

`--since DATE` filters by `state.ingested_at[:10] >= DATE[:10]` — ISO date prefix comparison, no datetime parsing needed.

`--cluster ID` loads each candidate item to check `item.analysis.cluster_id`. This is slower than the since filter but cluster-targeted re-analysis is an infrequent operation.

### 4.4 Cluster (`cluster.py`)

**Input:** all items with `analysis != None`

**Output:** `cache/embeddings/items.json`, `system/clusters.json`, `cluster_id` written back to each item

**Embedding generation:** Uses OpenAI `text-embedding-3-small`. The embedding text for each item is composed from `analysis.summary + tags + entities.concepts` (up to 1000 chars). Embeddings are cached in `cache/embeddings/items.json` as `{item_id: [float, ...]}` — only items not already in the cache are sent to the API, in batches of 100.

**Clustering:** HDBSCAN with `min_cluster_size` and `min_samples` from config. Input is a float32 numpy matrix of all cached embeddings. Items not in the cache are excluded. Label `-1` means noise, assigned `cluster_id = "_noise"`.

**Cluster naming:** For each non-noise cluster, the top 10 items by quality score are sent to Claude with a minimal prompt asking for a 2–5 word label. This is the only AI call in the cluster stage.

**Cluster registry (`system/clusters.json`):** Merges new clustering results with existing registry. Manually renamed clusters (where `auto: false`) have their labels preserved. Clusters that no longer appear in the new run are flagged `stale: true` rather than deleted.

### 4.5 Build (`build.py`)

**Input:** all items in `knowledge/items/`

**Output:** `knowledge/topics/`, `knowledge/authors/`, `knowledge/tech/`, `knowledge/index.json`, `site/`

Uses `_Manifest` (fingerprint-based) to skip unchanged outputs. The fingerprint for each output file is a SHA-256 of `item_id:analyzed_at` strings for all contributing items, sorted for stability.

**Topic digests** (`knowledge/topics/{cat}/{subcat}.md`): Items are grouped by their `analysis.categories` paths. Each digest has a Highlights section (top N items by quality score above a threshold) with full summaries, and an All Items section as a compact list. The `digest_writer` agent later prepends an AI-written intro paragraph, marked with `<!-- digest_writer -->` sentinels so it can be replaced on re-runs without duplicating.

**Author digests** (`knowledge/authors/{handle}.md`): Only created for authors with `author_min_items` or more saved items (default 3).

**Tech registry** (`knowledge/tech/{slug}.md`): One file per unique technology name across all `tech_refs` subcategories. Items are grouped by which subcategory (languages, frameworks, tools, etc.) they reference the technology under.

**Search index** (`knowledge/index.json`): A flat JSON array of compact item records for Fuse.js. Fields: `id, url, handle, ts, text[:200], summary, tags, cats, tech, score, source`.

**Static site** (`site/`): `index.html` + `style.css` + `search.js`. The JS loads `knowledge/index.json` and uses Fuse.js (loaded from CDN) for client-side fuzzy search. No server required — open `site/index.html` directly in a browser.

---

## 5. Agent system

### Design principles

Agents run after build. They perform reasoning that requires seeing multiple items at once — something the single-item analyze pass cannot do. Each agent has a single focused job, a dedicated prompt file, and writes to a specific output location.

Agents are not autonomous and do not spawn sub-agents. `bookbuilder agents` runs them once in dependency order and exits. The orchestrator is a simple loop, not a planner.

### Base class (`agents/base.py`)

All agents extend `Agent` (ABC). The base class provides:

- `call(prompt, max_tokens)` — single Claude API call, returns text
- `prompt_template()` — reads `system/prompts/agents/{name}.md`
- `needs_update(key, content)` — checks fingerprint in `_AgentManifest`
- `checkpoint()` — saves manifest to disk mid-run (used by item_critic every 50 items for crash resilience)
- `save_manifest()` — final manifest save

`_AgentManifest` stores `{key: sha256[:16]}` in `state/agents_manifest.json`. Keys are agent-specific strings like `"critic:{item_id}"` or `"cluster_analyst:{cluster_id}"`.

### Runner (`agents/runner.py`)

Iterates `_AGENTS` in dependency order. Before running each agent:

1. Checks `agents.{name}.enabled` in config
2. For agents in `_NEEDS_CLUSTERS` (`cluster_analyst`, `connection_finder`, `gap_detector`): checks that `system/clusters.json` exists, skips with a clear message if not

`only` parameter (from `--only` CLI flag) filters to a named subset without changing order.

### Agent details

**item_critic**

Targets items where `quality_score < score_threshold` (default 0.55) or `categories == ["_uncategorized"]`. For each, renders a prompt with the current analysis fields plus cluster context (the cluster label and parent category if the item has been clustered). The response is a partial JSON object — only fields being changed are returned. Updates `quality_score`, `categories`, `summary`, `tags` in place and writes the item back. Checkpoints every 50 items.

**cluster_analyst**

For each non-noise cluster with `>= min_items` items: takes the top N items by quality score, extracts their summaries and top tags, sends to Claude asking for a three-part analysis (synthesis, so-what, tensions/open questions). Writes to `knowledge/clusters/{cluster_id}.md`. Fingerprint is `cluster_id:updated_at:item_count` — re-runs only if the cluster has changed.

**digest_writer**

For each topic digest in `knowledge/topics/` with `>= min_items` items: sends top N item summaries to Claude asking for a 4–6 sentence intro paragraph. Prepends the result to the existing digest file between `<!-- digest_writer -->` sentinel comments. On re-runs, the old intro is replaced (regex strip before re-insert). Fingerprint is the concatenation of `item_id:quality_score` for the top N items.

**connection_finder**

Builds two cross-cluster maps from the full item corpus:
- `tech_clusters`: `{tech_name: set(cluster_ids)}` — which clusters reference each technology
- `author_clusters`: `{handle: set(cluster_ids)}` — which clusters each author appears in

Filters to technologies appearing in 3+ clusters (cross-cutting tech) and authors spanning 3+ clusters (bridge authors). Sends a cluster map + these two lists to Claude asking for a 400–500 word analysis of non-obvious connections. Writes to `knowledge/connections.md`.

**gap_detector**

Computes three gap signals:
- Thin categories: taxonomy categories with fewer than 5 items
- Noisy clusters: clusters with 10+ items but average quality score < 0.5
- Underrepresented tech: technologies mentioned by prolific authors (10+ items saved) but with fewer than 3 items saved overall

Sends these to Claude for a 300–400 word gap analysis with concrete recommendations. Writes to `knowledge/gaps.md`.

**taxonomy_evolver**

Collects items where `categories == ["_uncategorized"]` or `cluster_id == "_noise"`. Builds a tag frequency counter across these items. Sends samples + top tags + existing category list to Claude asking for 3–6 new subcategory proposals with keys, labels, descriptions, and seed keywords. Writes proposals to `system/notes/taxonomy_proposals.md`. Never modifies `taxonomy.yaml` directly — proposals require human review.

---

## 6. Search

### Keyword search (`search_items`)

Iterates all items in `knowledge/items/`. For each item, scores against query words with field-weighted matching:

| Field | Weight per matching word |
|---|---|
| summary | 2.0 |
| tags | 2.0 |
| card_title | 1.5 |
| text | 1.0 |
| categories | 1.0 |
| entity concepts | 0.5 |

With no query, items are ranked by `quality_score` (list mode). Structural filters (`category`, `author`, `tech`) are applied before scoring and short-circuit the score calculation.

This is an O(n) scan over all items on every query. At typical corpus sizes (1k–20k items) this is fast enough for CLI use. The MCP server runs the same function — it does not maintain an in-memory index between calls.

### Semantic search (`semantic_search`)

Embeds the query string using the same OpenAI model used for clustering (`text-embedding-3-small`). Loads the full embedding cache from `cache/embeddings/items.json`. Computes cosine similarity between the query vector and each cached item vector. Items not in the cache (not yet clustered) are excluded.

Falls back to keyword search with a warning if:
- `cache/embeddings/items.json` does not exist (cluster stage not run)
- `OPENAI_API_KEY` is not set

Cosine similarity formula: `dot(q, v) / (||q|| * ||v|| + 1e-9)` — the epsilon prevents division by zero on zero vectors.

---

## 7. MCP server

`bookbuilder mcp` starts a stdio MCP server using `FastMCP` from the `mcp` package. Claude Desktop and Claude Code connect to it by launching the process and communicating over stdin/stdout.

The server is stateless between tool calls — `_root` is set once at startup and all tools call through to `search_items`, `read_item`, or file reads. There is no in-memory cache or session state.

### Why MCP instead of direct folder access

The pipeline stages scan the full `knowledge/items/` directory for batch operations — this is appropriate for build and agent work where every item needs to be processed. For interactive queries from Claude, this approach has two problems:

1. **Latency** — loading 5,000+ JSON files per query is slow. The MCP tools return structured results from targeted reads.
2. **Interface** — folder access gives Claude raw files with no query semantics. MCP tools give Claude a defined API: `semantic_search_knowledge("RAG retrieval strategies", limit=10)` returns ranked, structured results. Claude can chain calls (`list_clusters` → `get_cluster` → `search_knowledge` with a refined query) to build up context across a conversation.
3. **Scope control** — the server exposes exactly the knowledge base content. Direct folder access would expose `state/`, `system/` (including config and API key env var names), and `cache/`.

### Tool inventory

| Tool | Primary use |
|---|---|
| `search_knowledge` | Keyword search — fast, works offline |
| `semantic_search_knowledge` | Conceptual queries — requires embeddings |
| `get_item` | Deep dive on a specific item by ID |
| `list_clusters` | Orientation — what topic areas exist |
| `get_cluster` | Cluster metadata + agent synthesis narrative |
| `find_by_tech` | "What have I saved about PyTorch?" |
| `find_by_author` | "What has @karpathy posted that I saved?" |
| `find_by_category` | Browse by taxonomy category |
| `get_connections` | Cross-cluster analysis from connection_finder |
| `get_gaps` | Gap analysis from gap_detector |

---

## 8. Configuration system

Configuration is split across three YAML files, each with a distinct role:

**`system/config.yaml`** — runtime settings: AI models, API key env var names, fetch parameters, output thresholds, agent settings. Read by `config.load_config()`, cached with `lru_cache(maxsize=1)` so it's loaded once per process.

**`system/pipeline.yaml`** — which stages are enabled and their per-stage options. Read directly by `build.py` for output flags. Not currently used to gate stage execution in `cli.py` (stages are always run when invoked; `pipeline.yaml` is consulted for output options within build).

**`system/taxonomy.yaml`** — the classification schema. Categories and subcategories with labels, descriptions, and seed keywords. Read by `config.load_taxonomy()` (also `lru_cache`). The flat list of valid category paths is computed by `taxonomy_category_paths()` and injected into the analyze prompt so Claude knows what categories are available.

**`system/skip_domains.txt`** — one domain per line, `#` comments supported. Loaded by `config.load_skip_domains()` into a `frozenset` for O(1) lookup. Domain matching is hierarchical: `twitter.com` in the skip list also blocks `mobile.twitter.com`.

API keys are never stored in config files. The config stores the name of the environment variable to read (`anthropic_env: ANTHROPIC_API_KEY`), and the code does `os.environ.get(cfg["api_keys"]["anthropic_env"])`.

---

## 9. Incremental execution and manifests

Three separate manifest/state mechanisms prevent redundant work:

**`state/items.jsonl`** — tracks per-item pipeline status (`fetch_status`, `analyze_status`). Stages check this before processing an item. Updated atomically by rewriting the full file after each stage run.

**`state/build_manifest.json`** — maps output file paths to fingerprints. The fingerprint for a topic digest is `SHA-256[:16]` of sorted `item_id:analyzed_at` strings for all contributing items. If the fingerprint matches, the file is skipped. Written at the end of each build run.

**`state/agents_manifest.json`** — same fingerprint mechanism for agents. Keys are agent-specific (e.g. `"critic:{item_id}"`, `"cluster_analyst:{cluster_id}"`). `item_critic` calls `checkpoint()` every 50 items to save the manifest mid-run, so a crash doesn't lose all progress.

The `--force` flag bypasses all manifest checks and re-runs everything for the targeted stage.

---

## 10. External dependencies

| Package | Used for |
|---|---|
| `anthropic` | Claude API — analysis, cluster naming, all agents |
| `openai` | Embeddings (`text-embedding-3-small`), semantic search |
| `hdbscan` | Density-based clustering |
| `numpy` | Embedding matrix operations, cosine similarity |
| `httpx[http2]` | Async HTTP fetching with HTTP/2 support |
| `readability-lxml` | Article text extraction from HTML |
| `pyyaml` | Config and taxonomy file parsing |
| `mcp[cli]` | MCP server (FastMCP, stdio transport) |
| `rich` | Terminal search output formatting (optional — falls back gracefully) |

All AI calls go through two providers:
- **Anthropic** — all text generation (analysis, cluster naming, all six agents)
- **OpenAI** — all embeddings (clustering, semantic search)

Neither provider is used for the other's task. This separation means either can be swapped independently by changing `system/config.yaml` and the relevant module.
