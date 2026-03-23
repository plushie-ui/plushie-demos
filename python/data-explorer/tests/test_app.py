"""Tests for the DataExplorer app logic.

Tests the app directly (no renderer needed) by calling init/update/view
and inspecting the results. File loading is exercised via the real loader
against sample_data/sample.csv.
"""

from __future__ import annotations

from dataclasses import replace
from pathlib import Path
from typing import Any

import pandas as pd

from data_explorer.app import DataExplorer, Model, _stats_panel
from plushie.commands import Command
from plushie.events import AsyncResult, Click, EffectResult, Input, Sort, Submit
from plushie.tree import find, normalize, text_of

SAMPLE_CSV = str(Path(__file__).resolve().parent.parent / "sample_data" / "sample.csv")


def _app() -> DataExplorer:
    return DataExplorer()


def _unwrap(result: object) -> tuple[Model, Command | None]:
    """Unwrap an update return into (model, optional command)."""
    if isinstance(result, tuple):
        model, cmd = result
        return model, cmd
    return result, None  # type: ignore[return-value]


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------


class TestInit:
    """Initial state from init()."""

    def test_returns_empty_model(self) -> None:
        model = _app().init()
        assert model.file_path is None
        assert model.columns == ()
        assert model.rows == ()
        assert model.status == "Open a file to begin"

    def test_not_loading(self) -> None:
        model = _app().init()
        assert model.loading is False
        assert model.error is None


# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------


class TestUpdateOpenFile:
    """Open file button returns an effect command."""

    def test_open_file_returns_effect(self) -> None:
        app = _app()
        model = app.init()
        new_model, cmd = _unwrap(app.update(model, Click(id="open_file")))
        assert cmd is not None
        assert cmd.type == "effect"
        assert cmd.payload["kind"] == "file_open"
        # Model unchanged until file is actually loaded
        assert new_model is model


class TestUpdateEffectResult:
    """EffectResult events trigger async loading or are ignored."""

    def test_ok_result_triggers_loading(self) -> None:
        app = _app()
        model = app.init()
        event = EffectResult(
            request_id="ef_1", status="ok", result={"path": "/tmp/test.csv"}
        )
        new_model, cmd = _unwrap(app.update(model, event))
        assert new_model.loading is True
        assert new_model.status == "Loading..."
        assert cmd is not None
        assert cmd.type == "task"
        assert cmd.payload["tag"] == "file_loaded"

    def test_cancelled_returns_model_unchanged(self) -> None:
        app = _app()
        model = app.init()
        event = EffectResult(request_id="ef_1", status="cancelled")
        result = app.update(model, event)
        assert result is model


class TestUpdateAsyncResult:
    """AsyncResult from background file loading."""

    def test_successful_load(self) -> None:
        app = _app()
        model = replace(app.init(), loading=True)
        loaded: dict[str, Any] = {
            "file_path": "/data/test.csv",
            "file_name": "test.csv",
            "columns": ("a", "b"),
            "dtypes": ("int64", "object"),
            "rows": ({"a": "1", "b": "x"},),
            "total_rows": 1,
            "summary": {"rows": 1, "columns": 2, "memory_bytes": 100, "total_nulls": 0},
            "status": "1 rows x 2 columns",
        }
        event = AsyncResult(tag="file_loaded", value=loaded)
        new_model, cmd = _unwrap(app.update(model, event))
        assert new_model.loading is False
        assert new_model.file_name == "test.csv"
        assert new_model.columns == ("a", "b")
        assert new_model.error is None
        assert cmd is None

    def test_failed_load(self) -> None:
        app = _app()
        model = replace(app.init(), loading=True)
        event = AsyncResult(tag="file_loaded", value=ValueError("bad file"))
        new_model, cmd = _unwrap(app.update(model, event))
        assert new_model.loading is False
        assert new_model.error == "bad file"
        assert new_model.status == "Error"
        assert cmd is None


class TestUpdateSearch:
    """Search input and submit events."""

    def test_input_updates_query(self) -> None:
        app = _app()
        model = app.init()
        new_model, cmd = _unwrap(app.update(model, Input(id="search", value="alice")))
        assert new_model.search_query == "alice"
        assert cmd is None

    def test_submit_filters_rows(self) -> None:
        app = _app()
        app._df = pd.DataFrame({"name": ["Alice", "Bob", "Carol"], "age": [30, 25, 40]})
        model = replace(
            app.init(),
            columns=("name", "age"),
            dtypes=("object", "int64"),
            search_query="alice",
            total_rows=3,
        )
        new_model = app.update(model, Submit(id="search", value="alice"))
        assert isinstance(new_model, Model)
        assert new_model.total_rows == 1
        assert len(new_model.rows) == 1

    def test_submit_without_df_returns_model(self) -> None:
        app = _app()
        model = replace(app.init(), search_query="test")
        result = app.update(model, Submit(id="search", value="test"))
        assert result is model


class TestUpdateSort:
    """Sort events from the table widget."""

    def test_sort_sets_column(self) -> None:
        app = _app()
        app._df = pd.DataFrame({"a": [3, 1, 2], "b": ["x", "y", "z"]})
        model = replace(
            app.init(),
            columns=("a", "b"),
            dtypes=("int64", "object"),
            total_rows=3,
        )
        new_model = app.update(model, Sort(id="data_table", value="a"))
        assert isinstance(new_model, Model)
        assert new_model.sort_column == "a"
        assert new_model.sort_ascending is True

    def test_sort_toggles_ascending(self) -> None:
        app = _app()
        app._df = pd.DataFrame({"a": [3, 1, 2]})
        model = replace(
            app.init(),
            columns=("a",),
            dtypes=("int64",),
            total_rows=3,
            sort_column="a",
            sort_ascending=True,
        )
        new_model = app.update(model, Sort(id="data_table", value="a"))
        assert isinstance(new_model, Model)
        assert new_model.sort_ascending is False


class TestUpdatePagination:
    """Prev/next page clicks."""

    def test_next_page(self) -> None:
        app = _app()
        app._df = pd.DataFrame({"a": range(250)})
        model = replace(
            app.init(),
            columns=("a",),
            dtypes=("int64",),
            total_rows=250,
            page=1,
            page_size=100,
        )
        new_model, cmd = _unwrap(app.update(model, Click(id="next_page")))
        assert new_model.page == 2
        assert cmd is None

    def test_prev_page(self) -> None:
        app = _app()
        app._df = pd.DataFrame({"a": range(250)})
        model = replace(
            app.init(),
            columns=("a",),
            dtypes=("int64",),
            total_rows=250,
            page=2,
            page_size=100,
        )
        new_model, cmd = _unwrap(app.update(model, Click(id="prev_page")))
        assert new_model.page == 1
        assert cmd is None

    def test_prev_page_at_first_does_nothing(self) -> None:
        app = _app()
        model = replace(app.init(), page=1)
        result = app.update(model, Click(id="prev_page"))
        # Falls through to the default case since guard fails
        assert result is model

    def test_next_page_at_last_does_nothing(self) -> None:
        app = _app()
        model = replace(app.init(), total_rows=50, page=1, page_size=100)
        result = app.update(model, Click(id="next_page"))
        assert result is model


class TestUpdateUnknownEvent:
    """Unknown events return the model unchanged."""

    def test_unknown_click(self) -> None:
        app = _app()
        model = app.init()
        result = app.update(model, Click(id="nonexistent"))
        assert result is model


# ---------------------------------------------------------------------------
# View
# ---------------------------------------------------------------------------


class TestView:
    """View tree structure."""

    def test_has_window(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        assert tree["type"] == "window"

    def test_empty_state_shows_no_data(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        node = find(tree, "empty")
        assert node is not None
        assert text_of(node) == "No data loaded"

    def test_has_open_button(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        node = find(tree, "open_file")
        assert node is not None
        assert node["type"] == "button"

    def test_has_search_input(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        node = find(tree, "search")
        assert node is not None
        assert node["type"] == "text_input"

    def test_with_data_shows_table(self) -> None:
        app = _app()
        model = replace(
            app.init(),
            columns=("name", "age"),
            dtypes=("object", "int64"),
            rows=({"name": "Alice", "age": "30"},),
            total_rows=1,
        )
        tree = normalize(app.view(model))
        table_node = find(tree, "data_table")
        assert table_node is not None
        assert table_node["type"] == "table"
        # Empty text should be gone
        assert find(tree, "empty") is None

    def test_with_data_shows_pagination(self) -> None:
        app = _app()
        model = replace(
            app.init(),
            columns=("a",),
            dtypes=("int64",),
            rows=({"a": "1"},),
            total_rows=1,
        )
        tree = normalize(app.view(model))
        assert find(tree, "prev_page") is not None
        assert find(tree, "next_page") is not None

    def test_error_displayed(self) -> None:
        app = _app()
        model = replace(app.init(), error="Something broke")
        tree = normalize(app.view(model))
        node = find(tree, "error")
        assert node is not None
        content = text_of(node) or ""
        assert "Something broke" in content

    def test_status_text(self) -> None:
        app = _app()
        model = replace(app.init(), status="42 rows x 5 columns")
        tree = normalize(app.view(model))
        node = find(tree, "status")
        assert node is not None
        assert text_of(node) == "42 rows x 5 columns"


# ---------------------------------------------------------------------------
# Stats panel
# ---------------------------------------------------------------------------


class TestStatsPanel:
    """_stats_panel view helper."""

    def test_returns_empty_when_no_stats(self) -> None:
        model = Model()
        assert _stats_panel(model) == []

    def test_returns_container_with_stats(self) -> None:
        model = replace(
            Model(),
            selected_column="age",
            column_stats={"count": 50, "mean": 35.0},
        )
        nodes = _stats_panel(model)
        assert len(nodes) == 1
        tree = normalize(nodes[0])
        assert tree["type"] == "container"
