"""Integration tests: full open-file flow with real sample data.

These tests exercise the app's internal load path using the actual
sample CSV, verifying that the loader, stats, and app wire up correctly.
No renderer needed -- the async task callable is invoked directly.
"""

from __future__ import annotations

from dataclasses import replace
from pathlib import Path
from typing import Any

from data_explorer.app import DataExplorer, Model
from plushie.commands import Command
from plushie.events import AsyncResult, Click, EffectResult, Sort, Submit
from plushie.tree import find, normalize

SAMPLE_CSV = str(Path(__file__).resolve().parent.parent / "sample_data" / "sample.csv")


def _unwrap(result: object) -> tuple[Model, Command | None]:
    if isinstance(result, tuple):
        model, cmd = result
        return model, cmd
    return result, None  # type: ignore[return-value]


class TestOpenFileFlow:
    """Simulate the full open-file flow: effect -> task -> result."""

    def test_load_sample_csv(self) -> None:
        app = DataExplorer()
        model = app.init()

        # Simulate EffectResult with the sample CSV path
        event = EffectResult(
            request_id="ef_1", status="ok", result={"path": SAMPLE_CSV}
        )
        model, cmd = _unwrap(app.update(model, event))
        assert model.loading is True
        assert cmd is not None
        assert cmd.type == "task"

        # Execute the background task directly
        task_fn = cmd.payload["fn"]
        loaded: dict[str, Any] = task_fn()

        # Feed the result back as an AsyncResult
        model, _ = _unwrap(
            app.update(model, AsyncResult(tag="file_loaded", value=loaded))
        )
        assert model.loading is False
        assert model.file_name == "sample.csv"
        assert model.total_rows == 50
        assert len(model.columns) == 8
        assert "name" in model.columns
        assert model.summary is not None
        assert model.summary["rows"] == 50

    def test_view_after_load(self) -> None:
        """After loading data, the view tree contains the table."""
        app = DataExplorer()
        model = app.init()

        event = EffectResult(
            request_id="ef_1", status="ok", result={"path": SAMPLE_CSV}
        )
        model, cmd = _unwrap(app.update(model, event))
        loaded = cmd.payload["fn"]()  # type: ignore[union-attr]
        model, _ = _unwrap(
            app.update(model, AsyncResult(tag="file_loaded", value=loaded))
        )

        tree = normalize(app.view(model))
        table_node = find(tree, "data_table")
        assert table_node is not None
        assert table_node["type"] == "table"
        assert find(tree, "empty") is None


class TestSearchAfterLoad:
    """Search filtering with real data."""

    def _load(self) -> tuple[DataExplorer, Model]:
        app = DataExplorer()
        model = app.init()
        event = EffectResult(
            request_id="ef_1", status="ok", result={"path": SAMPLE_CSV}
        )
        model, cmd = _unwrap(app.update(model, event))
        loaded = cmd.payload["fn"]()  # type: ignore[union-attr]
        model, _ = _unwrap(
            app.update(model, AsyncResult(tag="file_loaded", value=loaded))
        )
        return app, model

    def test_search_filters_rows(self) -> None:
        app, model = self._load()
        model = replace(model, search_query="San Francisco")
        new_model = app.update(model, Submit(id="search", value="San Francisco"))
        assert isinstance(new_model, Model)
        assert new_model.total_rows < 50
        assert new_model.total_rows > 0


class TestPaginationAfterLoad:
    """Pagination with real data."""

    def _load(self) -> tuple[DataExplorer, Model]:
        app = DataExplorer()
        model = app.init()
        event = EffectResult(
            request_id="ef_1", status="ok", result={"path": SAMPLE_CSV}
        )
        model, cmd = _unwrap(app.update(model, event))
        loaded = cmd.payload["fn"]()  # type: ignore[union-attr]
        model, _ = _unwrap(
            app.update(model, AsyncResult(tag="file_loaded", value=loaded))
        )
        return app, model

    def test_paginate_small_page(self) -> None:
        app, model = self._load()
        # Use a small page size to force multiple pages
        model = replace(model, page_size=10)
        new_model, _ = _unwrap(app.update(model, Click(id="next_page")))
        assert new_model.page == 2
        assert len(new_model.rows) == 10

    def test_last_page_has_no_next(self) -> None:
        app, model = self._load()
        # page_size=100, total_rows=50: already on last page
        result = app.update(model, Click(id="next_page"))
        assert result is model


class TestSearchEdgeCases:
    """Edge cases for search."""

    def _load(self) -> tuple[DataExplorer, Model]:
        app = DataExplorer()
        model = app.init()
        event = EffectResult(
            request_id="ef_1", status="ok", result={"path": SAMPLE_CSV}
        )
        model, cmd = _unwrap(app.update(model, event))
        loaded = cmd.payload["fn"]()  # type: ignore[union-attr]
        model, _ = _unwrap(
            app.update(model, AsyncResult(tag="file_loaded", value=loaded))
        )
        return app, model

    def test_no_results_search(self) -> None:
        app, model = self._load()
        model = replace(model, search_query="zzzznonexistent")
        new_model = app.update(model, Submit(id="search", value="zzzznonexistent"))
        assert isinstance(new_model, Model)
        assert new_model.total_rows == 0
        assert len(new_model.rows) == 0


class TestSortAfterLoad:
    """Sort with real data."""

    def _load(self) -> tuple[DataExplorer, Model]:
        app = DataExplorer()
        model = app.init()
        event = EffectResult(
            request_id="ef_1", status="ok", result={"path": SAMPLE_CSV}
        )
        model, cmd = _unwrap(app.update(model, event))
        loaded = cmd.payload["fn"]()  # type: ignore[union-attr]
        model, _ = _unwrap(
            app.update(model, AsyncResult(tag="file_loaded", value=loaded))
        )
        return app, model

    def test_sort_by_salary(self) -> None:
        app, model = self._load()
        new_model = app.update(model, Sort(id="data_table", value="salary"))
        assert isinstance(new_model, Model)
        assert new_model.sort_column == "salary"
        # First row should be the lowest salary
        first_salary = float(new_model.rows[0]["salary"])
        last_salary = float(new_model.rows[-1]["salary"])
        assert first_salary <= last_salary
