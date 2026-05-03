from pathlib import Path
from bookbuilder.ingest import (
    _detect_source, _iter_markdown, _iter_text, _md_heading_outline,
)


# ── _detect_source ────────────────────────────────────────────────────────────

def test_detect_markdown():
    assert _detect_source(Path("notes.md")) == "markdown"
    assert _detect_source(Path("README.markdown")) == "markdown"

def test_detect_text():
    assert _detect_source(Path("notes.txt")) == "text"

def test_detect_docx():
    assert _detect_source(Path("report.docx")) == "docx"


# ── _md_heading_outline ───────────────────────────────────────────────────────

def test_heading_outline_basic():
    md = "# Title\n## Section One\n### Subsection\n## Section Two\nsome body text"
    outline = _md_heading_outline(md)
    assert "Title" in outline
    assert "Section One" in outline
    assert "  Subsection" in outline   # indented one level
    assert "body text" not in outline

def test_heading_outline_empty():
    assert _md_heading_outline("no headings here") == ""

def test_heading_outline_preserves_depth():
    md = "# H1\n## H2\n### H3\n#### H4"
    lines = _md_heading_outline(md).splitlines()
    assert lines[0] == "H1"
    assert lines[1] == "  H2"
    assert lines[2] == "    H3"
    assert lines[3] == "      H4"


# ── _iter_markdown ────────────────────────────────────────────────────────────

def test_iter_markdown_basic(tmp_path):
    f = tmp_path / "article.md"
    f.write_text("# My Article\n\n## Background\n\nSome content here.\n\n## Findings\n\nMore content.")
    items = list(_iter_markdown(f))
    assert len(items) == 1
    item = items[0]
    assert item.source == "markdown"
    assert item.card_title == "My Article"
    assert "My Article" in item.text
    assert "Background" in item.text
    assert "Findings" in item.text
    assert "[Document outline]" in item.text
    assert "[Content]" in item.text

def test_iter_markdown_url_is_file_uri(tmp_path):
    f = tmp_path / "doc.md"
    f.write_text("# Doc\nContent.")
    items = list(_iter_markdown(f))
    assert items[0].url.startswith("file://")

def test_iter_markdown_title_fallback(tmp_path):
    f = tmp_path / "my-notes.md"
    f.write_text("No heading here, just text.")
    items = list(_iter_markdown(f))
    assert items[0].card_title == "my-notes"

def test_iter_markdown_stable_id(tmp_path):
    f = tmp_path / "doc.md"
    f.write_text("# Title\nContent.")
    id1 = list(_iter_markdown(f))[0].id
    id2 = list(_iter_markdown(f))[0].id
    assert id1 == id2

def test_iter_markdown_heading_markers_stripped_from_body(tmp_path):
    f = tmp_path / "doc.md"
    f.write_text("# Title\n## Section\nBody text.")
    item = list(_iter_markdown(f))[0]
    # The [Content] section should not have ## markers
    content_section = item.text.split("[Content]")[-1]
    assert "## Section" not in content_section
    assert "Section" in content_section


# ── _iter_text ────────────────────────────────────────────────────────────────

def test_iter_text_basic(tmp_path):
    f = tmp_path / "my-notes.txt"
    f.write_text("This is a plain text file with some content.")
    items = list(_iter_text(f))
    assert len(items) == 1
    item = items[0]
    assert item.source == "text"
    assert "plain text" in item.text
    assert item.card_title == "My Notes"   # filename title-cased

def test_iter_text_no_outline(tmp_path):
    f = tmp_path / "notes.txt"
    f.write_text("Just text.")
    item = list(_iter_text(f))[0]
    assert "[Document outline]" not in item.text

def test_iter_text_truncation(tmp_path):
    f = tmp_path / "big.txt"
    f.write_text("x" * 30000)
    item = list(_iter_text(f))[0]
    assert len(item.text) <= 20000
