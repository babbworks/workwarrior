from bookbuilder.models import Analysis, Entities, Item, TechRefs
from bookbuilder.export import _export_markdown, _export_html, _ts, _esc


def _item(id="1", handle="alice", summary="A great insight about Python.",
          tags=None, cats=None, score=0.8, ts="2024-03-15T10:00:00Z",
          source="bookmark") -> Item:
    a = Analysis(
        summary=summary,
        tags=tags or ["python", "ml"],
        categories=cats or ["ai_ml/ai_tools"],
        tech_refs=TechRefs(languages=["Python"]),
        quality_score=score,
        entities=Entities(),
    )
    return Item(
        id=id, source=source,
        url=f"https://x.com/u/status/{id}",
        text=summary, author_name="Alice",
        author_handle=handle, timestamp=ts, analysis=a,
    )


# ── _ts ───────────────────────────────────────────────────────────────────────

def test_ts_iso():
    assert _ts("2024-03-15T10:00:00Z") == "Mar 15, 2024"

def test_ts_empty():
    assert _ts("") == ""

def test_ts_short():
    # bare date strings are also parsed successfully
    assert _ts("2024-03-15") == "Mar 15, 2024"


# ── _esc ──────────────────────────────────────────────────────────────────────

def test_esc_html_chars():
    assert _esc("<b>hello & world</b>") == "&lt;b&gt;hello &amp; world&lt;/b&gt;"

def test_esc_clean():
    assert _esc("hello world") == "hello world"


# ── _export_markdown ──────────────────────────────────────────────────────────

def test_markdown_contains_title():
    items = [_item()]
    md = _export_markdown(items, "My Digest", "10 items")
    assert "# My Digest" in md

def test_markdown_contains_meta():
    items = [_item()]
    md = _export_markdown(items, "Title", "5 items · min score 0.6")
    assert "5 items" in md

def test_markdown_contains_summary():
    items = [_item(summary="Transformers are powerful.")]
    md = _export_markdown(items, "T", "m")
    assert "Transformers are powerful." in md

def test_markdown_contains_author():
    items = [_item(handle="karpathy")]
    md = _export_markdown(items, "T", "m")
    assert "karpathy" in md

def test_markdown_groups_by_category():
    items = [
        _item(id="1", cats=["ai_ml/ai_tools"]),
        _item(id="2", cats=["software_dev/backend"]),
    ]
    md = _export_markdown(items, "T", "m")
    assert "Ai Ml" in md or "ai_ml" in md.lower()
    assert "Software Dev" in md or "software_dev" in md.lower()

def test_markdown_has_source_link():
    items = [_item()]
    md = _export_markdown(items, "T", "m")
    assert "tweet" in md or "source" in md

def test_markdown_document_source_label():
    items = [_item(source="markdown")]
    md = _export_markdown(items, "T", "m")
    assert "source" in md

def test_markdown_has_generated_timestamp():
    items = [_item()]
    md = _export_markdown(items, "T", "m")
    assert "Generated" in md


# ── _export_html ──────────────────────────────────────────────────────────────

def test_html_is_valid_structure():
    items = [_item()]
    html = _export_html(items, "My Digest", "meta")
    assert "<!DOCTYPE html>" in html
    assert "<title>My Digest" in html
    assert "</html>" in html

def test_html_contains_summary():
    items = [_item(summary="Key insight about RAG.")]
    html = _export_html(items, "T", "m")
    assert "Key insight about RAG." in html

def test_html_escapes_special_chars():
    items = [_item(summary="Use <b>bold</b> & more")]
    html = _export_html(items, "T", "m")
    assert "<b>bold</b>" not in html
    assert "&lt;b&gt;" in html

def test_html_contains_tags():
    items = [_item(tags=["transformer", "attention"])]
    html = _export_html(items, "T", "m")
    assert "transformer" in html
    assert "attention" in html

def test_html_has_print_css():
    items = [_item()]
    html = _export_html(items, "T", "m")
    assert "@media print" in html

def test_html_groups_by_category():
    items = [
        _item(id="1", cats=["ai_ml/ai_tools"]),
        _item(id="2", cats=["software_dev/backend"]),
    ]
    html = _export_html(items, "T", "m")
    assert "Ai Ml" in html or "ai_ml" in html.lower()

def test_html_multiple_items():
    items = [_item(id=str(i), summary=f"Insight {i}") for i in range(5)]
    html = _export_html(items, "T", "m")
    for i in range(5):
        assert f"Insight {i}" in html
