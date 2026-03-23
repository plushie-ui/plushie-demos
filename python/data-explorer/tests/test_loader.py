"""Tests for the DataFrame loading and row extraction utilities."""

from __future__ import annotations

import json
import tempfile
from pathlib import Path

import pandas as pd
import pytest

from data_explorer.loader import df_columns, df_dtypes, df_to_rows, load_file

SAMPLE_CSV = str(Path(__file__).resolve().parent.parent / "sample_data" / "sample.csv")


class TestLoadFile:
    """load_file dispatches on extension and returns a DataFrame."""

    def test_csv(self) -> None:
        df = load_file(SAMPLE_CSV)
        assert isinstance(df, pd.DataFrame)
        assert len(df) == 50
        assert "name" in df.columns

    def test_json(self) -> None:
        data = [{"x": 1, "y": "a"}, {"x": 2, "y": "b"}]
        with tempfile.NamedTemporaryFile(suffix=".json", mode="w", delete=False) as f:
            json.dump(data, f)
            f.flush()
            df = load_file(f.name)
        assert len(df) == 2
        assert list(df.columns) == ["x", "y"]

    def test_unsupported_extension_raises(self) -> None:
        with pytest.raises(ValueError, match="Unsupported file type"):
            load_file("/tmp/data.xyz")


class TestDfToRows:
    """df_to_rows extracts a page of rows as dicts."""

    def test_full_page(self) -> None:
        df = pd.DataFrame({"a": [1, 2, 3], "b": ["x", "y", "z"]})
        rows = df_to_rows(df, 0, 10)
        assert len(rows) == 3
        assert rows[0]["a"] == "1"
        assert rows[0]["b"] == "x"

    def test_pagination(self) -> None:
        df = pd.DataFrame({"val": range(20)})
        rows = df_to_rows(df, 5, 3)
        assert len(rows) == 3
        assert rows[0]["val"] == "5"
        assert rows[2]["val"] == "7"

    def test_float_formatting(self) -> None:
        df = pd.DataFrame({"price": [10.0, 3.14]})
        rows = df_to_rows(df, 0, 10)
        assert rows[0]["price"] == "10"
        assert rows[1]["price"] == "3.14"

    def test_null_formatting(self) -> None:
        df = pd.DataFrame({"val": [1.0, None]})
        rows = df_to_rows(df, 0, 10)
        assert rows[1]["val"] == ""

    def test_empty_dataframe(self) -> None:
        df = pd.DataFrame({"a": pd.Series([], dtype="int64")})
        rows = df_to_rows(df, 0, 10)
        assert rows == ()

    def test_single_row(self) -> None:
        df = pd.DataFrame({"x": [42]})
        rows = df_to_rows(df, 0, 10)
        assert len(rows) == 1
        assert rows[0]["x"] == "42"

    def test_single_column(self) -> None:
        df = pd.DataFrame({"only": ["a", "b", "c"]})
        rows = df_to_rows(df, 0, 10)
        assert len(rows) == 3
        assert all("only" in r for r in rows)

    def test_inf_formatting(self) -> None:
        df = pd.DataFrame({"val": [float("inf"), float("-inf")]})
        rows = df_to_rows(df, 0, 10)
        assert rows[0]["val"] == "inf"
        assert rows[1]["val"] == "-inf"


class TestDfColumns:
    """df_columns returns a tuple of column names."""

    def test_returns_tuple(self) -> None:
        df = pd.DataFrame({"a": [1], "b": [2]})
        assert df_columns(df) == ("a", "b")


class TestDfDtypes:
    """df_dtypes returns string dtype names."""

    def test_returns_tuple(self) -> None:
        df = pd.DataFrame({"a": [1], "b": ["x"]})
        dtypes = df_dtypes(df)
        assert isinstance(dtypes, tuple)
        assert len(dtypes) == 2
        assert "int" in dtypes[0]
        assert dtypes[1] in ("object", "str", "string")
