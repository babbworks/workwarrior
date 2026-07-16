# List Item Format — v1

**Contract for:** files in `<profile>/list/<listname>` and `<profile>/list/.<listname>.done`
**Status:** normative. Documents the existing format; adds conventions for timestamps, notes, and tags.
**Producers:** `tools/list/list.py`, browser `list_add`/`list_edit` actions.
**Consumers:** `tools/list/list.py`, browser `renderListRows()`, any future CLI extensions.

---

## 1. File structure

One item per line. Two files per named list:

```
<profile>/list/<name>         # active items
<profile>/list/.<name>.done   # finished items
```

Lines are sorted by SHA1 hash ID (not by insertion order). This minimizes merge conflicts
in version-controlled lists.

Comment lines (starting with `#`) are permitted and skipped by the parser.

---

## 2. Line format

```
<text> | <meta>
```

Or, for items without explicit metadata (hand-edited files):

```
<text>
```

### Fields

| Part | Description |
|---|---|
| `text` | Everything before the last ` \| ` (space-pipe-space). The user-visible content. |
| `meta` | Comma-separated `key:value` pairs. Always includes `id:<sha1>`. |

**The `|` delimiter uses the LAST occurrence** (via `rpartition('|')` in list.py). Text may
contain pipe characters; metadata cannot.

### Example

```
Buy milk #errands // check if oat milk is on sale | id:a3f8c92b1e
[2026-07-14 08:00] Read chapter 5 of DDIA #reading | id:7b2e01cdf4
Simple item with no metadata
```

---

## 3. Text anatomy — timestamps, body, tags, and notes

The `text` portion (everything before ` | meta`) has this structure:

```
[<timestamp>] <body with #tags> // <note>
```

All parts except `<body>` are optional.

### 3.1 Timestamps (optional prefix)

```
[YYYY-MM-DD HH:MM]
[YYYY-MM-DD]
```

If present, MUST be the first characters of `text` (after any leading whitespace, which
should not exist). The bracket-enclosed date is followed by a space, then the body.

**Timestamps are added at creation time.** They are part of the stored text — not
separate metadata. Readers parse them for sorting and display; writers include them when
the user or system wants to record when an item was captured.

### 3.2 Body

The main item content. Everything after the optional timestamp and before the optional
` // ` note separator. This is what the user typed.

### 3.3 Tags (inline in body)

```
#word
```

Tags are `#` followed by one or more characters matching `[a-zA-Z0-9_-]`. They appear
anywhere in the body text. They are NOT extracted or stored separately — they live in
the text and are parsed on read.

**Rules:**
- Tags are case-insensitive for filtering (`#Reading` matches `#reading`).
- A `#` preceded by a non-space character is not a tag (e.g., `C#` is not a tag).
- Tags may appear in the note portion too, but canonical tag filtering operates on
  the body (pre-` // `) by default.

### 3.4 Notes (optional suffix)

```
 // <note text>
```

The separator is exactly: space, slash, slash, space (` // `). Everything after it is
the note. A note is a short inline annotation — a thought, a reminder, context.

**Rules:**
- Only the FIRST occurrence of ` // ` is the separator. Note text may itself contain
  ` // ` (parsed greedily: first split wins).
- An item with no note simply has no ` // ` in its text.
- Notes are appended via `list_edit` (browser) or `list -e` (CLI) — there is no
  separate "add note" storage operation. The edit replaces the full text.

---

## 4. Metadata keys

| Key | Required | Meaning |
|---|---|---|
| `id` | yes | SHA1 hash of the original text at creation time. Stable identifier. |

Additional metadata keys are permitted (the parser handles arbitrary `key:value` pairs)
but none are currently used beyond `id`. Future extensions (e.g., `created:timestamp`)
would go here, not in the text body.

---

## 5. Parsed representation

When a consumer reads a line, it produces:

```json
{
  "id": "a3f8c92b1e...",
  "prefix": "a3f",
  "text": "Buy milk #errands // check if oat milk is on sale",
  "body": "Buy milk #errands",
  "tags": ["errands"],
  "note": "check if oat milk is on sale",
  "timestamp": null,
  "done": false
}
```

The `prefix` is the shortest unique prefix of the ID among all items in the same list.
It is computed at display time, not stored.

---

## 6. lists.yaml

Per-profile configuration at `<profile>/lists.yaml`:

```yaml
lists:
  default: tasks
```

The `default` key names the active list (the `-l` value passed to list.py). Additional
keys may be added as the multi-list feature evolves (e.g., a list of all known list
names for discovery without scanning the filesystem).

---

## 7. Compatibility rules

**For readers:**
- MUST handle lines with no ` | ` delimiter (text-only, no metadata).
- MUST handle items with no timestamp, no tags, and no note (plain text body only).
- MUST handle unknown metadata keys gracefully (ignore them).
- MUST use first-occurrence splitting for ` // ` (note separator).
- MUST use last-occurrence splitting for ` | ` (metadata separator).

**For writers:**
- MUST preserve the ` | id:<hash>` suffix when editing items.
- MUST NOT reorder fields within the metadata section arbitrarily (preserve existing).
- MUST NOT add newlines within an item (one line = one item, always).
- SHOULD include `id:<hash>` on every item written.

---

## 8. Changelog

**v1 — 2026-07-14**
- Documented the existing format (previously implicit in `list.py` + browser code).
- Codified the ` // ` note separator convention (implemented in browser since ≈2026-06).
- Codified the `[YYYY-MM-DD HH:MM]` timestamp convention (browser `_parseListItemDate`).
- Defined the `#tag` convention (new — not yet parsed by browser or CLI).
- Established `lists.yaml` as the per-profile list configuration file.
