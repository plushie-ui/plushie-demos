"""Shared fixtures for sparkline-dashboard tests.

The plushie pytest plugin is disabled (pyproject.toml) because its
``pytest_configure`` hook hangs if the binary is missing. We provide
our own ``plushie_pool`` fixture that skips cleanly.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

# Ensure src/ is importable without install
src = str(Path(__file__).resolve().parent.parent / "src")
if src not in sys.path:
    sys.path.insert(0, src)


def _has_plushie_binary() -> bool:
    """Check whether the plushie binary is available."""
    try:
        from plushie.binary import resolve

        resolve()
        return True
    except Exception:
        return False


@pytest.fixture(scope="session")
def plushie_pool():  # type: ignore[no-untyped-def]
    """Provide a SessionPool if the binary is available, else skip."""
    if not _has_plushie_binary():
        pytest.skip("plushie binary not available")

    from plushie.testing.pool import SessionPool

    pool = SessionPool(mode="mock", max_sessions=8)
    pool.start()
    yield pool
    pool.stop()
