"""Column and summary statistics for DataFrames."""

from __future__ import annotations

import math
from typing import Any

import pandas as pd


def column_stats(df: pd.DataFrame, column: str) -> dict[str, Any]:
    """Compute stats for a single column.

    Returns count, nulls, dtype, unique count. For numeric columns also
    includes mean, std, min, max, and median.
    """
    series = df[column]
    stats: dict[str, Any] = {
        "count": int(series.count()),  # type: ignore[arg-type]
        "nulls": int(series.isna().sum()),  # type: ignore[arg-type]
        "dtype": str(series.dtype),
        "unique": int(series.nunique()),  # type: ignore[arg-type]
    }

    if pd.api.types.is_numeric_dtype(series):

        def _safe_round(val: float) -> float | None:
            return round(val, 2) if math.isfinite(val) else None

        mean = float(series.mean())  # type: ignore[arg-type]
        stats["mean"] = _safe_round(mean)
        stats["std"] = _safe_round(float(series.std()))  # type: ignore[arg-type]
        stats["min"] = float(series.min()) if series.count() > 0 else None  # type: ignore[arg-type]
        stats["max"] = float(series.max()) if series.count() > 0 else None  # type: ignore[arg-type]
        stats["median"] = _safe_round(float(series.median()))  # type: ignore[arg-type]
    else:
        mode = series.mode()
        if not mode.empty:
            stats["top"] = str(mode.iloc[0])
        stats["top_freq"] = (
            int(series.value_counts().iloc[0]) if series.count() > 0 else 0  # type: ignore[arg-type]
        )

    return stats


def summary_stats(df: pd.DataFrame) -> dict[str, Any]:
    """Overall summary: row count, column count, memory usage, null total."""
    return {
        "rows": len(df),
        "columns": len(df.columns),
        "memory_bytes": int(df.memory_usage(deep=True).sum()),  # type: ignore[arg-type]
        "total_nulls": int(df.isna().sum().sum()),  # type: ignore[arg-type]
    }
