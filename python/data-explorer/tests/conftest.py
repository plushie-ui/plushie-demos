"""Shared fixtures for data-explorer tests."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

# Ensure src/ is importable without install
src = str(Path(__file__).resolve().parent.parent / "src")
if src not in sys.path:
    sys.path.insert(0, src)

SAMPLE_CSV = str(Path(__file__).resolve().parent.parent / "sample_data" / "sample.csv")


@pytest.fixture()
def sample_csv_path() -> str:
    """Path to the bundled sample CSV."""
    return SAMPLE_CSV


def _has_plushie_binary() -> bool:
    """Check whether the plushie binary is available."""
    try:
        from plushie.binary import resolve

        resolve()
        return True
    except Exception:
        return False


@pytest.fixture(scope="session")
def needs_plushie_binary() -> None:
    """Skip if the plushie binary is not available."""
    if not _has_plushie_binary():
        pytest.skip("plushie binary not available")
