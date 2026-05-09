"""Shared fixtures for plushie_pad tests."""

from __future__ import annotations

import pytest

from plushie_pad import experiments as pad_experiments


@pytest.fixture(autouse=True)
def restore_experiments():
    """Snapshot experiment files before each test and restore them after.

    Tests that exercise save/delete mutate the experiments directory on disk.
    This fixture guarantees a clean slate for every test regardless of order.
    """
    snapshot = {exp.name: exp.source for exp in pad_experiments.list_experiments()}
    yield
    current = {exp.name for exp in pad_experiments.list_experiments()}
    for name in current - snapshot.keys():
        pad_experiments.delete(name)
    for name, source in snapshot.items():
        pad_experiments.save(name, source)


def _has_plushie_binary() -> bool:
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
