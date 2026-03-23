"""Data explorer app -- tabular data viewer with search, sort, and stats.

Demonstrates:
- File dialog effects (open CSV/JSON/Parquet/Excel)
- Async task commands (background DataFrame loading)
- Table widget with sortable columns
- Search filtering across text columns
- Pagination
- Column statistics panel

Run::

    python -m data_explorer
    python -m plushie run data_explorer.app:DataExplorer
"""

from __future__ import annotations

from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any

import pandas as pd
import plushie
from plushie import effects, ui
from plushie.commands import Command
from plushie.events import AsyncResult, Click, EffectResult, Input, Sort, Submit

from data_explorer.loader import df_columns, df_dtypes, df_to_rows, load_file
from data_explorer.stats import column_stats, summary_stats


@dataclass(frozen=True, slots=True)
class Model:
    """Application state for the data explorer."""

    file_path: str | None = None
    file_name: str = ""
    columns: tuple[str, ...] = ()
    dtypes: tuple[str, ...] = ()
    rows: tuple[dict[str, str], ...] = ()
    total_rows: int = 0
    search_query: str = ""
    sort_column: str | None = None
    sort_ascending: bool = True
    page: int = 1
    page_size: int = 100
    selected_column: str | None = None
    column_stats: dict[str, Any] | None = None
    summary: dict[str, Any] | None = None
    status: str = "Open a file to begin"
    error: str | None = None
    loading: bool = False


class DataExplorer(plushie.App[Model]):
    """Tabular data explorer with search, sort, pagination, and column stats."""

    def __init__(self) -> None:
        self._df: pd.DataFrame | None = None

    def init(self) -> Model:
        return Model()

    def update(self, model: Model, event: object) -> Model | tuple[Model, Command]:
        match event:
            case Click(id="open_file"):
                return model, effects.file_open(
                    title="Open Data File",
                    filters=[
                        ("CSV", "*.csv"),
                        ("JSON", "*.json"),
                        ("Parquet", "*.parquet"),
                        ("Excel", "*.xlsx;*.xls"),
                        ("All Files", "*"),
                    ],
                )

            case EffectResult(status="ok", result=result):
                path = result.get("path") or result.get("paths", [None])[0]
                if path:
                    return (
                        replace(model, loading=True, status="Loading..."),
                        Command.task(lambda: self._load(path), "file_loaded"),
                    )
                return model

            case EffectResult(status="cancelled"):
                return model

            case AsyncResult(tag="file_loaded", value=result):
                if isinstance(result, Exception):
                    return replace(
                        model, loading=False, error=str(result), status="Error"
                    )
                return replace(
                    model,
                    **result,
                    loading=False,
                    error=None,
                    page=1,
                    search_query="",
                    sort_column=None,
                )

            case Input(id="search", value=query):
                return replace(model, search_query=query)

            case Submit(id="search"):
                return self._apply_query(model)

            case Sort(id="data_table", value=col):
                return self._apply_sort(model, col)

            case Click(id="prev_page") if model.page > 1:
                return self._change_page(model, model.page - 1)

            case Click(id="next_page") if (
                model.page * model.page_size < model.total_rows
            ):
                return self._change_page(model, model.page + 1)

            case Click(id=col_name, scope=("col_stats", *_)):
                stats = (
                    column_stats(self._df, col_name)
                    if self._df is not None and col_name in self._df.columns
                    else None
                )
                return replace(model, selected_column=col_name, column_stats=stats)

            case _:
                return model

    def _load(self, path: str) -> dict[str, Any]:
        """Background task: load file and extract initial page."""
        df = load_file(path)
        self._df = df
        return {
            "file_path": path,
            "file_name": Path(path).name,
            "columns": df_columns(df),
            "dtypes": df_dtypes(df),
            "rows": df_to_rows(df, 0, 100),
            "total_rows": len(df),
            "summary": summary_stats(df),
            "status": f"{len(df):,} rows x {len(df.columns)} columns",
        }

    def _apply_query(self, model: Model) -> Model:
        """Filter the DataFrame and update visible rows."""
        if self._df is None:
            return model
        df = self._df
        if model.search_query.strip():
            mask = pd.Series(False, index=df.index)
            for col in df.select_dtypes(include=["object", "string"]).columns:
                mask |= (
                    df[col]
                    .astype(str)
                    .str.contains(model.search_query, case=False, na=False)
                )
            df = df[mask]
        if model.sort_column and model.sort_column in df.columns:
            df = df.sort_values(model.sort_column, ascending=model.sort_ascending)  # type: ignore[call-overload]
        rows = df_to_rows(df, 0, model.page_size)  # type: ignore[arg-type]
        return replace(
            model,
            rows=rows,
            total_rows=len(df),
            page=1,
            status=f"{len(df):,} rows x {len(self._df.columns)} columns",
        )

    def _apply_sort(self, model: Model, column: str) -> Model:
        """Sort and re-paginate."""
        ascending = not model.sort_ascending if column == model.sort_column else True
        return self._refresh_page(
            replace(model, sort_column=column, sort_ascending=ascending, page=1)
        )

    def _change_page(self, model: Model, new_page: int) -> Model:
        return self._refresh_page(replace(model, page=new_page))

    def _refresh_page(self, model: Model) -> Model:
        """Re-query the DataFrame with current filters/sort/page."""
        if self._df is None:
            return model
        df = self._df
        if model.search_query.strip():
            mask = pd.Series(False, index=df.index)
            for col in df.select_dtypes(include=["object", "string"]).columns:
                mask |= (
                    df[col]
                    .astype(str)
                    .str.contains(model.search_query, case=False, na=False)
                )
            df = df[mask]
        if model.sort_column and model.sort_column in df.columns:
            df = df.sort_values(model.sort_column, ascending=model.sort_ascending)  # type: ignore[call-overload]
        start = (model.page - 1) * model.page_size
        rows = df_to_rows(df, start, model.page_size)  # type: ignore[arg-type]
        total_pages = max(1, -(-len(df) // model.page_size))
        return replace(
            model,
            rows=rows,
            total_rows=len(df),
            status=(
                f"{len(df):,} rows x {len(self._df.columns)} columns"
                f" | Page {model.page}/{total_pages}"
            ),
        )

    def view(self, model: Model) -> dict[str, Any]:
        return ui.window(
            "main",
            ui.column(
                # Header
                ui.row(
                    ui.text("title", "Data Explorer", size=24),
                    ui.space(width="fill"),
                    ui.button("open_file", "Open File"),
                    id="header",
                    spacing=8,
                    padding=(8, 16),
                ),
                # Status bar
                ui.text("status", model.status, size=12, color="#888888"),
                # Error display
                *(
                    []
                    if not model.error
                    else [
                        ui.text(
                            "error",
                            f"Error: {model.error}",
                            size=12,
                            color="#e74c3c",
                        )
                    ]
                ),
                # Search
                ui.text_input(
                    "search",
                    model.search_query,
                    placeholder="Search across all text columns...",
                    on_submit=True,
                    width="fill",
                ),
                # Table or empty state
                *(
                    [
                        ui.table(
                            "data_table",
                            columns=[
                                {"key": col, "label": f"{col} ({dtype})"}
                                for col, dtype in zip(
                                    model.columns, model.dtypes, strict=True
                                )
                            ],
                            rows=[
                                {col: str(row.get(col, "")) for col in model.columns}
                                for row in model.rows
                            ],
                            sortable=True,
                        )
                    ]
                    if model.columns
                    else [ui.text("empty", "No data loaded")]
                ),
                # Pagination
                *(
                    []
                    if not model.columns
                    else [
                        ui.row(
                            ui.button("prev_page", "< Prev"),
                            ui.text("page_info", f"Page {model.page}"),
                            ui.button("next_page", "Next >"),
                            id="pagination",
                            spacing=8,
                        )
                    ]
                ),
                # Column stats panel
                *(_stats_panel(model) if model.column_stats else []),
                padding=16,
                spacing=8,
                width="fill",
            ),
            title="Data Explorer",
            size=(1024, 768),
        )


def _stats_panel(model: Model) -> list[dict[str, Any]]:
    """Build the column statistics panel nodes."""
    stats = model.column_stats
    if stats is None:
        return []
    lines = [f"Column: {model.selected_column}"]
    for key, val in stats.items():
        lines.append(f"  {key}: {val}")
    return [
        ui.container(
            "stats_panel",
            ui.column(
                *(ui.text(f"stat_{i}", line, size=12) for i, line in enumerate(lines)),
                spacing=2,
            ),
            padding=12,
        )
    ]


if __name__ == "__main__":
    plushie.run(DataExplorer)
