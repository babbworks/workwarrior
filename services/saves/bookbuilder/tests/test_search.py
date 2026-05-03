from bookbuilder.models import Analysis, Entities, Item, TechRefs
from bookbuilder.search import matches_author, matches_category, matches_tech, score_item


def _item(
    id="1", handle="alice", text="", summary="", tags=None,
    categories=None, tech=None, quality=0.5,
) -> Item:
    a = Analysis(
        summary=summary,
        tags=tags or [],
        categories=categories or [],
        tech_refs=TechRefs(**(tech or {})),
        quality_score=quality,
        entities=Entities(),
    )
    return Item(
        id=id, source="bookmark",
        url=f"https://x.com/u/status/{id}",
        text=text, author_name="Alice", author_handle=handle,
        timestamp="2024-01-01", analysis=a,
    )


# ── score_item ────────────────────────────────────────────────────────────────

def test_score_item_text_match():
    item = _item(text="python is great")
    score = score_item(item, {"python"})
    assert score > 0


def test_score_item_summary_scores_higher_than_text():
    item_text = _item(text="python rocks")
    item_summary = _item(summary="python rocks")
    s_text = score_item(item_text, {"python"})
    s_summary = score_item(item_summary, {"python"})
    assert s_summary > s_text


def test_score_item_tag_match():
    item = _item(tags=["machine-learning", "python"])
    score = score_item(item, {"python"})
    assert score > 0


def test_score_item_no_match():
    item = _item(text="hello world", summary="nothing here")
    assert score_item(item, {"python"}) == 0.0


def test_score_item_multiple_words():
    item = _item(text="rust and python", summary="systems programming")
    score = score_item(item, {"rust", "python"})
    assert score > score_item(item, {"rust"})


# ── matches_category ──────────────────────────────────────────────────────────

def test_matches_category_exact():
    item = _item(categories=["ai_ml/ai_tools"])
    assert matches_category(item, "ai_ml/ai_tools")


def test_matches_category_prefix():
    item = _item(categories=["ai_ml/ai_tools"])
    assert matches_category(item, "ai_ml")


def test_matches_category_no_match():
    item = _item(categories=["software_dev/backend"])
    assert not matches_category(item, "ai_ml")


def test_matches_category_case_insensitive():
    item = _item(categories=["AI_ML/ai_tools"])
    assert matches_category(item, "ai_ml")


def test_matches_category_no_analysis():
    item = Item(
        id="1", source="bookmark", url="https://x.com/u/status/1",
        text="", author_name="", author_handle="", timestamp="",
    )
    assert not matches_category(item, "ai_ml")


# ── matches_author ────────────────────────────────────────────────────────────

def test_matches_author_exact():
    item = _item(handle="karpathy")
    assert matches_author(item, "karpathy")


def test_matches_author_strips_at():
    item = _item(handle="karpathy")
    assert matches_author(item, "@karpathy")


def test_matches_author_case_insensitive():
    item = _item(handle="Karpathy")
    assert matches_author(item, "karpathy")


def test_matches_author_no_match():
    item = _item(handle="alice")
    assert not matches_author(item, "bob")


# ── matches_tech ──────────────────────────────────────────────────────────────

def test_matches_tech_language():
    item = _item(tech={"languages": ["Python", "Rust"]})
    assert matches_tech(item, "python")
    assert matches_tech(item, "rust")


def test_matches_tech_substring():
    item = _item(tech={"frameworks": ["PyTorch"]})
    assert matches_tech(item, "torch")


def test_matches_tech_no_match():
    item = _item(tech={"languages": ["Python"]})
    assert not matches_tech(item, "javascript")


def test_matches_tech_no_analysis():
    item = Item(
        id="1", source="bookmark", url="https://x.com/u/status/1",
        text="", author_name="", author_handle="", timestamp="",
    )
    assert not matches_tech(item, "python")
