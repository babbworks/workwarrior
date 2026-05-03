"""Tests for HeuristicEngine.match_compound() — multi-command matching."""

import os
import sys
import tempfile
import textwrap

import pytest

# Ensure the server module can be imported
sys.path.insert(0, os.path.dirname(__file__))

from server import HeuristicEngine, CONJUNCTIONS


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_engine(rules_yaml: str) -> HeuristicEngine:
    """Create a HeuristicEngine backed by a temporary YAML file."""
    tmpdir = tempfile.mkdtemp()
    os.makedirs(os.path.join(tmpdir, "config"), exist_ok=True)
    yaml_path = os.path.join(tmpdir, "config", "cmd-heuristics.yaml")
    with open(yaml_path, "w") as f:
        f.write(textwrap.dedent(rules_yaml))
    return HeuristicEngine(tmpdir)


SAMPLE_RULES = """\
threshold: 0.8

rules:
  - pattern: "^task add (.+)"
    action: "task add $1"
    confidence: 1.0
    source: compiled
    count: 0

  - pattern: "^(?:create|add|new|make) (?:a )?task (?:to |for |about )?(.+)"
    action: "task add $1"
    confidence: 0.90
    source: compiled
    count: 0

  - pattern: "^timew start (.+)"
    action: "timew start $1"
    confidence: 1.0
    source: compiled
    count: 0

  - pattern: "^(?:start tracking|track) (?:time )?(?:on |for )?(.+)"
    action: "timew start $1"
    confidence: 0.90
    source: compiled
    count: 0

  - pattern: "^timew stop"
    action: "timew stop"
    confidence: 1.0
    source: compiled
    count: 0

  - pattern: "^(?:stop tracking|stop timer)"
    action: "timew stop"
    confidence: 0.90
    source: compiled
    count: 0
"""


# ---------------------------------------------------------------------------
# CONJUNCTIONS regex tests
# ---------------------------------------------------------------------------

class TestConjunctionsRegex:
    def test_splits_on_and(self):
        parts = CONJUNCTIONS.split("add task groceries and start tracking time")
        parts = [p.strip() for p in parts if p.strip()]
        assert parts == ["add task groceries", "start tracking time"]

    def test_splits_on_then(self):
        parts = CONJUNCTIONS.split("create a task then stop tracking")
        parts = [p.strip() for p in parts if p.strip()]
        assert parts == ["create a task", "stop tracking"]

    def test_splits_on_also(self):
        parts = CONJUNCTIONS.split("task add review also timew start review")
        parts = [p.strip() for p in parts if p.strip()]
        assert parts == ["task add review", "timew start review"]

    def test_splits_on_plus(self):
        parts = CONJUNCTIONS.split("add task meeting plus start tracking meeting")
        parts = [p.strip() for p in parts if p.strip()]
        assert parts == ["add task meeting", "start tracking meeting"]

    def test_no_conjunction_returns_single(self):
        parts = CONJUNCTIONS.split("add a task for groceries")
        parts = [p.strip() for p in parts if p.strip()]
        assert parts == ["add a task for groceries"]

    def test_word_boundary_no_false_split(self):
        """'and' inside a word like 'android' should not cause a split."""
        parts = CONJUNCTIONS.split("add task android review")
        parts = [p.strip() for p in parts if p.strip()]
        assert parts == ["add task android review"]


# ---------------------------------------------------------------------------
# match_compound() tests
# ---------------------------------------------------------------------------

class TestMatchCompound:
    def setup_method(self):
        self.engine = _make_engine(SAMPLE_RULES)

    def test_returns_none_for_single_segment(self):
        """No conjunctions → returns None so caller uses single match()."""
        result = self.engine.match_compound("add a task for groceries")
        assert result is None

    def test_matches_two_segments(self):
        """Two recognizable segments joined by 'and' → list of match tuples."""
        result = self.engine.match_compound(
            "add a task for groceries and start tracking time on shopping"
        )
        assert result is not None
        assert len(result) == 2
        action1, conf1, idx1 = result[0]
        action2, conf2, idx2 = result[1]
        assert "task add" in action1
        assert "timew start" in action2

    def test_returns_none_when_segment_unrecognizable(self):
        """If any segment doesn't match, return None (AI fallback)."""
        result = self.engine.match_compound(
            "add a task for groceries and do something completely unknown"
        )
        assert result is None

    def test_all_conjunctions_work(self):
        """Each conjunction type should split and match."""
        for conj in ("and", "then", "also", "plus"):
            result = self.engine.match_compound(
                f"task add review {conj} timew start review"
            )
            assert result is not None, f"Failed for conjunction '{conj}'"
            assert len(result) == 2

    def test_increments_counts_not_done_by_match_compound(self):
        """match_compound itself does NOT increment counts — the handler does."""
        result = self.engine.match_compound(
            "task add review and timew start review"
        )
        assert result is not None
        # Counts should still be 0 — match_compound doesn't call increment_count
        for rule in self.engine.rules:
            assert rule.get("count", 0) == 0

    def test_three_segments(self):
        """Three segments joined by conjunctions."""
        result = self.engine.match_compound(
            "task add meeting and start tracking meeting then stop tracking"
        )
        # This depends on whether all three segments match
        # "task add meeting" → match, "start tracking meeting" → match,
        # "stop tracking" → match
        assert result is not None
        assert len(result) == 3

    def test_empty_input(self):
        result = self.engine.match_compound("")
        assert result is None

    def test_only_conjunction(self):
        result = self.engine.match_compound("and")
        assert result is None


class TestMatchCompoundWithSingleMatch:
    """Verify match_compound and match work together correctly."""

    def setup_method(self):
        self.engine = _make_engine(SAMPLE_RULES)

    def test_single_match_still_works(self):
        """Regular match() should still work for non-compound inputs."""
        result = self.engine.match("task add groceries")
        assert result is not None
        action, conf, idx = result
        assert action == "task add groceries"

    def test_compound_then_single_fallback(self):
        """If compound returns None, single match should still work."""
        compound = self.engine.match_compound("add a task for groceries")
        assert compound is None
        single = self.engine.match("add a task for groceries")
        assert single is not None
