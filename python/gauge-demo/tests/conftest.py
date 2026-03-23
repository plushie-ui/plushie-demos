"""Shared fixtures for gauge-demo tests."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

# Ensure src/ is importable without install
src = str(Path(__file__).resolve().parent.parent / "src")
if src not in sys.path:
    sys.path.insert(0, src)


def _has_extension_binary() -> bool:
    """Check whether a custom-built binary with the gauge extension exists.

    The extension binary is produced by ``python -m plushie build`` and
    lives in the build output directory. Without it, integration tests
    that exercise the full wire protocol (Python -> msgpack -> Rust
    extension -> msgpack -> Python) cannot run.
    """
    try:
        from plushie.binary import resolve

        resolve()
        return True
    except Exception:
        return False


@pytest.fixture(scope="session")
def needs_extension_binary() -> None:
    """Skip the calling test if the gauge extension binary is not available."""
    if not _has_extension_binary():
        pytest.skip("gauge extension binary not built -- run: python -m plushie build")
