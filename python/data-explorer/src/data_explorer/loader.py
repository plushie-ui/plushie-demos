"""DataFrame loading and row extraction utilities."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pandas as pd


def load_file(path: str) -> pd.DataFrame:
    """Load a file into a DataFrame based on extension."""
    ext = Path(path).suffix.lower()
    match ext:
        case ".csv":
            return pd.read_csv(path)
        case ".json":
            return pd.read_json(path)
        case ".parquet":
            return pd.read_parquet(path)
        case ".xlsx" | ".xls":
            return pd.read_excel(path)
        case _:
            raise ValueError(f"Unsupported file type: {ext}")


def _format_value(val: Any) -> str:
    """Format a single cell value for display."""
    if pd.isna(val):
        return ""
    if isinstance(val, float):
        if val == int(val):
            return str(int(val))
        return f"{val:.2f}"
    return str(val)


def df_to_rows(df: pd.DataFrame, start: int, count: int) -> tuple[dict[str, str], ...]:
    """Extract a page of rows as a tuple of dicts."""
    page = df.iloc[start : start + count]
    return tuple(
        {col: _format_value(val) for col, val in row.items()}
        for _, row in page.iterrows()
    )


def df_columns(df: pd.DataFrame) -> tuple[str, ...]:
    """Column names."""
    return tuple(df.columns)


def df_dtypes(df: pd.DataFrame) -> tuple[str, ...]:
    """String dtype names."""
    return tuple(str(dt) for dt in df.dtypes)
