# Decisions

Lightweight ADR log. Add an entry whenever a non-obvious choice is made.

---

## 2024 — JSONL for state, JSON for items

`state/items.jsonl` is append-friendly and survives partial writes.
`knowledge/items/{id}.json` is one file per item so individual items can be read/written without loading the whole corpus. At 10k+ items a single JSON array would be slow to update.

## 2024 — HDBSCAN over k-means for clustering

HDBSCAN doesn't require specifying k upfront and handles noise natively (label -1). The corpus size is unknown at design time and topics are uneven in density. k-means would require tuning k and forces every item into a cluster.

## 2024 — Claude for analysis, OpenAI for embeddings

Claude produces better structured JSON for the analysis task (summary, tags, categories). OpenAI's text-embedding-3-small is cheaper and faster for bulk embedding than Anthropic's current embedding options. Keeping them separate also means either can be swapped independently.

## 2024 — Agents never auto-edit taxonomy.yaml

taxonomy_evolver writes proposals to system/notes/taxonomy_proposals.md rather than editing taxonomy.yaml directly. The taxonomy is a human-curated schema; AI proposals should be reviewed before being applied. A future `bookbuilder taxonomy apply` command can handle the apply step explicitly.

## 2024 — Manifest fingerprinting for incremental builds

Both the build stage and agents use SHA-256 fingerprints of input content to skip unchanged work. This is simpler than timestamp-based invalidation (which breaks when files are copied or clocks drift) and cheaper than re-running everything.

## 2024 — Semantic search as opt-in, not default

`bookbuilder search` defaults to keyword scoring because it works offline and requires no API call. `--semantic` is opt-in because it costs an OpenAI embedding call per query and requires the embedding cache to exist. The MCP server exposes both as separate tools for the same reason.

## 2024 — Source normalisation to RawItem at ingest boundary

All sources (Twitter JSON, RSS, Pocket, Instapaper, browser bookmarks, manual URL) normalise to `RawItem` at the ingest boundary. Everything downstream is source-agnostic. New sources only need a parser that produces `RawItem` — no other stage needs to change.
