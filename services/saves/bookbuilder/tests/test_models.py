from bookbuilder.models import (
    Analysis, Entities, FetchedImage, FetchedPage,
    Item, ItemState, QuoteRef, RawItem, TechRefs,
)


def _make_item(**kwargs) -> Item:
    defaults = dict(
        id="123", source="bookmark", url="https://x.com/user/status/123",
        text="hello world", author_name="Alice", author_handle="alice",
        timestamp="2024-01-01T00:00:00Z",
    )
    defaults.update(kwargs)
    return Item(**defaults)


def test_item_defaults():
    item = _make_item()
    assert item.links == []
    assert item.fetched_pages == []
    assert item.images == []
    assert item.analysis is None
    assert item.state is None


def test_item_all_urls_deduplicates():
    item = _make_item(
        links=["https://example.com", "https://other.com", "https://example.com"],
        card_url="https://other.com",
    )
    urls = item.all_urls
    assert len(urls) == len(set(urls))
    assert "https://example.com" in urls
    assert "https://other.com" in urls


def test_item_all_urls_excludes_empty():
    item = _make_item(links=["https://a.com", ""], card_url="")
    assert "" not in item.all_urls


def test_tech_refs_is_empty():
    assert TechRefs().is_empty()
    assert not TechRefs(languages=["Python"]).is_empty()
    assert not TechRefs(tools=["Docker"]).is_empty()


def test_tech_refs_all_refs():
    tr = TechRefs(languages=["Python"], frameworks=["FastAPI"], tools=["Docker"])
    refs = tr.all_refs()
    assert "Python" in refs
    assert "FastAPI" in refs
    assert "Docker" in refs
    assert len(refs) == 3


def test_raw_item_author_properties():
    raw = RawItem(
        id="1", source="bookmark", url="https://x.com/user/status/1",
        text="hi", author_raw="Alice @alice_dev", timestamp="",
        links=[], card_url="", card_title="", card_desc="",
        quote=None, content_hash="abc",
    )
    assert raw.author_handle == "alice_dev"
    assert "Alice" in raw.author_name


def test_raw_item_no_handle():
    raw = RawItem(
        id="1", source="bookmark", url="https://x.com/user/status/1",
        text="hi", author_raw="Alice", timestamp="",
        links=[], card_url="", card_title="", card_desc="",
        quote=None, content_hash="abc",
    )
    assert raw.author_handle == ""
    assert raw.author_name == "Alice"


def test_analysis_defaults():
    a = Analysis()
    assert a.quality_score == 0.0
    assert a.tags == []
    assert a.categories == []
    assert a.cluster_id is None
    assert a.entities.people == []
    assert a.tech_refs.is_empty()


def test_item_state_fields():
    s = ItemState(
        item_id="1", content_hash="abc", source="bookmark",
        ingested_at="2024-01-01", fetch_status="ok", analyze_status="pending",
    )
    assert s.fetch_status == "ok"
    assert s.analyze_status == "pending"
    assert s.fetched_at == ""
