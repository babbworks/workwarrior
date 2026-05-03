# Roadmap

## Done

### v0.1 — Core pipeline
- Ingest: Twitter/X bookmark and like JSON export parsing, deduplication by URL and content hash
- Fetch: async page crawl, image download, readability extraction, skip-domain list
- Analyze: Claude-powered per-item analysis (summary, tags, entities, tech_refs, categories, quality_score)
- Cluster: OpenAI embeddings + HDBSCAN, cluster naming via Claude
- Build: topic digests, author digests, tech registry, Fuse.js search index, static site
- Search: keyword scoring CLI + MCP server (6 tools)
- MCP server: stdio transport for Claude Desktop / Claude Code

### v0.2 — Multi-agent layer + source expansion
- agents/ package: item_critic, cluster_analyst, digest_writer, connection_finder, gap_detector, taxonomy_evolver
- Agent manifest with incremental checkpointing (crash-safe)
- Cluster prerequisite gate in runner (clear error if clusters.json missing)
- Source expansion: RSS/Atom, Pocket HTML, Instapaper CSV, browser bookmark HTML
- `bookbuilder add <url>` — ingest a single URL directly
- `bookbuilder analyze --since DATE --cluster ID` — targeted re-analysis
- `bookbuilder search --semantic` — cosine similarity search via embedding cache
- MCP: 4 new tools (semantic_search_knowledge, get_cluster, get_connections, get_gaps)
- models.py: replaced stub with full dataclass definitions
- pyproject.toml: fixed dependency format, added all runtime deps, entry point

## Next

### Near-term
- [ ] Highlight curation agent: ask Claude "which 5 of these 20 items would you actually recommend" instead of top-N by score
- [x] `bookbuilder status` command: show counts by stage, last run timestamps, quality distribution
- [x] Re-fetch stale pages: `bookbuilder fetch --stale-after DAYS`
- [x] Taxonomy proposals → apply: `bookbuilder taxonomy apply`
- [x] `bookbuilder watch` + launchd plist for background scheduling
- [x] Reading list: `bookbuilder inbox`, `bookbuilder mark`, `read_status` on ItemState
- [x] Obsidian vault export: `bookbuilder obsidian` reads proposals and applies to taxonomy.yaml interactively

### Medium-term
- [ ] Web UI improvements: topic pages, author pages, cluster pages linked from site/
- [ ] Export: generate a single markdown or PDF digest of the top-N items by category
- [ ] Scheduled runs: launchd / cron integration docs
- [ ] Source: Readwise export support
- [ ] Source: Raindrop.io export support

### Longer-term
- [ ] Incremental embedding updates (currently re-embeds all on cluster rerun)
- [ ] Multi-user / shared knowledge base mode
- [ ] Vector store backend option (replace flat JSON embedding cache with sqlite-vec or similar)
