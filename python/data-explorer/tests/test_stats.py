"""Tests for column and summary statistics."""

from __future__ import annotations

import pandas as pd

from data_explorer.stats import column_stats, summary_stats


class TestColumnStatsNumeric:
    """column_stats for numeric columns."""

    def test_basic_numeric_stats(self) -> None:
        df = pd.DataFrame({"val": [10, 20, 30, 40, 50]})
        stats = column_stats(df, "val")
        assert stats["count"] == 5
        assert stats["nulls"] == 0
        assert stats["mean"] == 30.0
        assert stats["min"] == 10.0
        assert stats["max"] == 50.0
        assert stats["median"] == 30.0
        assert "std" in stats

    def test_unique_count(self) -> None:
        df = pd.DataFrame({"val": [1, 1, 2, 2, 3]})
        stats = column_stats(df, "val")
        assert stats["unique"] == 3


class TestColumnStatsString:
    """column_stats for string columns."""

    def test_string_stats(self) -> None:
        df = pd.DataFrame({"city": ["NYC", "NYC", "LA", "SF"]})
        stats = column_stats(df, "city")
        assert stats["count"] == 4
        assert stats["unique"] == 3
        assert stats["top"] == "NYC"
        assert stats["top_freq"] == 2
        assert "mean" not in stats


class TestColumnStatsNulls:
    """column_stats handles null values."""

    def test_numeric_with_nulls(self) -> None:
        df = pd.DataFrame({"val": [1.0, None, 3.0, None, 5.0]})
        stats = column_stats(df, "val")
        assert stats["count"] == 3
        assert stats["nulls"] == 2

    def test_string_with_nulls(self) -> None:
        df = pd.DataFrame({"name": ["Alice", None, "Carol"]})
        stats = column_stats(df, "name")
        assert stats["nulls"] == 1
        assert stats["count"] == 2


class TestSummaryStats:
    """summary_stats returns overall DataFrame summary."""

    def test_basic_summary(self) -> None:
        df = pd.DataFrame({"a": [1, 2, 3], "b": ["x", None, "z"]})
        summary = summary_stats(df)
        assert summary["rows"] == 3
        assert summary["columns"] == 2
        assert summary["total_nulls"] == 1
        assert summary["memory_bytes"] > 0
