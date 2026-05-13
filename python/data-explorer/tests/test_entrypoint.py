"""Tests for the packaged data-explorer entry point."""

from __future__ import annotations

import runpy

import plushie
import pytest

from data_explorer.app import DataExplorer


def test_main_runs_direct_mode_without_socket(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[tuple[str, object]] = []

    monkeypatch.delenv("PLUSHIE_SOCKET", raising=False)
    monkeypatch.setattr(plushie, "run", lambda app: calls.append(("run", app)))
    monkeypatch.setattr(
        plushie, "connect", lambda app: calls.append(("connect", app)), raising=False
    )

    runpy.run_module("data_explorer.__main__", run_name="__main__")

    assert calls == [("run", DataExplorer)]


def test_main_connects_when_socket_is_set(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[tuple[str, object]] = []

    monkeypatch.setenv("PLUSHIE_SOCKET", "/tmp/plushie.sock")
    monkeypatch.setattr(plushie, "run", lambda app: calls.append(("run", app)))
    monkeypatch.setattr(
        plushie, "connect", lambda app: calls.append(("connect", app)), raising=False
    )

    runpy.run_module("data_explorer.__main__", run_name="__main__")

    assert calls == [("connect", DataExplorer)]
