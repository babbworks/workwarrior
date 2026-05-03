import json
import tempfile
from pathlib import Path

import pytest

from bookbuilder.ingest import (
    _content_hash, _detect_source, _make_url_item,
    iter_raw_items, normalise, run_ingest,
)


# ── normalise ─────────────────────────────────────────────────────────────────

def test_normalise_basic():
    raw = {"url": "https://x.com/user/status/123", "text": "hello", "author": "Alice @alice"}
    item = normalise(raw, "bookmark")
    assert item is not None
    assert item.id == "123"
    assert item.source == "bookmark"
    assert item.text == "hello"


def test_normalise_missing_url_returns_none():
    assert normalise({}, "bookmark") is None
    assert normalise({"url": ""}, "bookmark") is None


def test_normalise_non_tweet_url_returns_none():
    assert normalise({"url": "https://example.com/page"}, "bookmark") is None


def test_normalise_links_new_format():
    raw = {
        "url": "https://x.com/user/status/1",
        "links": ["https://a.com", "https://b.com"],
    }
    item = normalise(raw, "bookmark")
    assert item.links == ["https://a.com", "https://b.com"]


def test_normalise_links_old_format():
    raw = {
        "url": "https://x.com/user/status/1",
        "textLinks": ["https://a.com"],
        "extraLinks": ["https://b.com"],
    }
    item = normalise(raw, "bookmark")
    assert "https://a.com" in item.links
    assert "https://b.com" in item.links


# ── _detect_source ────────────────────────────────────────────────────────────

def test_detect_source_from_filename():
    assert _detect_source(Path("my_bookmarks.json")) == "bookmark"
    assert _detect_source(Path("twitter_likes.json")) == "like"
    assert _detect_source(Path("feed.xml")) == "rss"
    assert _detect_source(Path("pocket_export.html")) == "pocket"
    assert _detect_source(Path("instapaper.csv")) == "instapaper"
    assert _detect_source(Path("bookmarks.html")) == "bookmarks_html"


# ── _make_url_item ────────────────────────────────────────────────────────────

def test_make_url_item():
    item = _make_url_item("https://example.com/article")
    assert item is not None
    assert item.source == "manual"
    assert item.url == "https://example.com/article"
    assert len(item.id) == 16


def test_make_url_item_empty_returns_none():
    assert _make_url_item("") is None
    assert _make_url_item("   ") is None


# ── iter_raw_items — Twitter JSON ─────────────────────────────────────────────

def test_iter_raw_items_json_array(tmp_path):
    data = [
        {"url": "https://x.com/u/status/1", "text": "a"},
        {"url": "https://x.com/u/status/2", "text": "b"},
        {"url": "https://example.com/no-id"},  # should be skipped
    ]
    f = tmp_path / "bookmarks.json"
    f.write_text(json.dumps(data))
    items = list(iter_raw_items(f))
    assert len(items) == 2
    assert {i.id for i in items} == {"1", "2"}


def test_iter_raw_items_json_wrapped(tmp_path):
    data = {"bookmarks": [{"url": "https://x.com/u/status/99", "text": "hi"}]}
    f = tmp_path / "bookmarks.json"
    f.write_text(json.dumps(data))
    items = list(iter_raw_items(f))
    assert len(items) == 1
    assert items[0].id == "99"


# ── iter_raw_items — RSS ──────────────────────────────────────────────────────

def test_iter_raw_items_rss(tmp_path):
    rss = """<?xml version="1.0"?>
<rss version="2.0"><channel>
  <item><title>Test Article</title><link>https://example.com/a</link><description>desc</description></item>
  <item><title>Another</title><link>https://example.com/b</link></item>
</channel></rss>"""
    f = tmp_path / "feed.xml"
    f.write_text(rss)
    items = list(iter_raw_items(f))
    assert len(items) == 2
    assert all(i.source == "rss" for i in items)
    assert items[0].card_title == "Test Article"


# ── iter_raw_items — Pocket HTML ──────────────────────────────────────────────

def test_iter_raw_items_pocket(tmp_path):
    html = """<!DOCTYPE html><html><body>
<ul><li><a href="https://example.com/1" time_added="1700000000">Article One</a></li>
<li><a href="https://example.com/2" time_added="1700000001">Article Two</a></li>
</ul></body></html>"""
    f = tmp_path / "pocket_export.html"
    f.write_text(html)
    items = list(iter_raw_items(f))
    assert len(items) == 2
    assert all(i.source == "pocket" for i in items)
    assert items[0].card_title == "Article One"


# ── iter_raw_items — Instapaper CSV ──────────────────────────────────────────

def test_iter_raw_items_instapaper(tmp_path):
    csv_content = "URL,Title,Selection,Folder\nhttps://example.com/a,Title A,Some text,Unread\nhttps://example.com/b,Title B,,Archive\n"
    f = tmp_path / "instapaper.csv"
    f.write_text(csv_content)
    items = list(iter_raw_items(f))
    assert len(items) == 2
    assert all(i.source == "instapaper" for i in items)
    assert items[0].card_title == "Title A"


# ── iter_raw_items — Browser bookmarks HTML ───────────────────────────────────

def test_iter_raw_items_bookmarks_html(tmp_path):
    html = """<!DOCTYPE NETSCAPE-Bookmark-file-1>
<DL><p>
  <DT><A HREF="https://example.com/a" ADD_DATE="1700000000">Page A</A>
  <DT><A HREF="https://example.com/b" ADD_DATE="1700000001">Page B</A>
  <DT><A HREF="javascript:void(0)">Skip me</A>
</DL>"""
    f = tmp_path / "bookmarks.html"
    f.write_text(html)
    items = list(iter_raw_items(f))
    assert len(items) == 2
    assert all(i.source == "bookmarks_html" for i in items)


# ── run_ingest deduplication ──────────────────────────────────────────────────

def test_run_ingest_deduplicates(tmp_path):
    root = tmp_path
    (root / "system").mkdir()
    (root / "system" / "config.yaml").write_text("ai:\n  model: test\n")
    state_dir = root / "state"
    state_dir.mkdir()
    (root / "knowledge" / "items").mkdir(parents=True)

    data = [
        {"url": "https://x.com/u/status/1", "text": "hello"},
        {"url": "https://x.com/u/status/1", "text": "hello"},  # duplicate
        {"url": "https://x.com/u/status/2", "text": "world"},
    ]
    f = tmp_path / "bookmarks.json"
    f.write_text(json.dumps(data))

    new, updated, skipped = run_ingest([f], state_dir, root)
    assert new == 2
    assert skipped == 1


def test_run_ingest_cross_source_dedup(tmp_path):
    root = tmp_path
    (root / "system").mkdir()
    (root / "system" / "config.yaml").write_text("ai:\n  model: test\n")
    state_dir = root / "state"
    state_dir.mkdir()
    (root / "knowledge" / "items").mkdir(parents=True)

    tweet = {"url": "https://x.com/u/status/42", "text": "same content"}
    bookmarks = tmp_path / "bookmarks.json"
    likes = tmp_path / "likes.json"
    bookmarks.write_text(json.dumps([tweet]))
    likes.write_text(json.dumps([tweet]))

    new1, _, _ = run_ingest([bookmarks], state_dir, root)
    new2, _, skipped2 = run_ingest([likes], state_dir, root)
    assert new1 == 1
    assert new2 == 0
    assert skipped2 == 1
