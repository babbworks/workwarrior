# bookbuilder — analysis prompt
# Used by: bookbuilder/analyze.py
# Variables: {text}, {fetched_title}, {fetched_text}, {card_title}, {card_desc},
#            {source_hint}, {taxonomy_categories}
# ─────────────────────────────────────────────────────────────────────────────

You are a knowledge curation assistant. Analyse the content below (a {source_hint}) and return
a single JSON object. Be precise and concise. Do not add commentary outside the JSON.

## Input

**Title / heading:** {fetched_title}

**Content:**
{text}

**Linked article title:** {card_title}
**Linked article excerpt:**
{fetched_text}

**Card description:** {card_desc}

## Task

Return a JSON object with exactly these fields:

```json
{
  "summary": "1–2 sentence plain-English summary of the core idea or finding.",

  "tags": ["tag1", "tag2", "tag3"],
  // 3–6 lowercase hyphenated keyword tags. Specific is better than generic.
  // Good: "local-llm", "apple-silicon", "zettelkasten"
  // Bad: "technology", "interesting", "ai"

  "entities": {
    "people":   ["Full Name"],          // real people mentioned by name
    "orgs":     ["Org Name"],           // companies, institutions, projects
    "concepts": ["concept name"],       // key ideas, methods, theories
    "places":   ["Place"]               // only if geographically relevant
  },

  "tech_refs": {
    "languages":   [],   // e.g. ["Python", "Rust", "TypeScript"]
    "frameworks":  [],   // e.g. ["PyTorch", "React", "FastAPI"]
    "tools":       [],   // apps, CLIs, editors e.g. ["Cursor", "Docker", "Neovim"]
    "packages":    [],   // specific packages/libraries e.g. ["vllm", "transformers"]
    "repos":       [],   // GitHub repos in "owner/repo" format
    "hardware":    [],   // chips, devices e.g. ["M4 Max", "H100"]
    "platforms":   []    // services/platforms e.g. ["Vercel", "Hugging Face", "GitHub"]
  },

  "categories": ["primary/subcategory", "optional_second/subcategory"],
  // Choose 1–2 paths from this list (use the exact keys):
  // {taxonomy_categories}
  // Always assign the most specific subcategory path possible.
  // Use "_uncategorized" only if nothing fits.

  "quality_score": 0.0
  // Float 0.0–1.0. Score the signal value of this item:
  //   0.9–1.0  substantive insight, tutorial, paper, tool announcement with depth
  //   0.7–0.8  interesting opinion, useful link, good thread
  //   0.5–0.6  casual comment, vague pointer, low context
  //   0.2–0.4  noise, personal update, meme, low information
  //   0.0–0.1  no meaningful content
  // For local documents (markdown, text, docx): score based on depth and usefulness
  // of the content itself, not its brevity.
}
```
