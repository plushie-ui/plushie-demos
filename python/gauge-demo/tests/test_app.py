"""Tests for the TemperatureMonitor app logic.

Tests the app directly (no renderer needed) by calling init/update/view
and inspecting the results. Extension events (value_changed) are
simulated by constructing WidgetEvent instances.
"""

from __future__ import annotations

from dataclasses import replace

from gauge_demo.app import (
    Model,
    TemperatureMonitor,
    status_color,
    temperature_status,
)
from plushie.commands import Command
from plushie.events import Click, Slide, WidgetEvent
from plushie.tree import find, normalize, text_of


def _app() -> TemperatureMonitor:
    return TemperatureMonitor()


def _unwrap(result: object) -> tuple[Model, Command | None]:
    """Unwrap an update return into (model, optional command)."""
    if isinstance(result, tuple):
        model, cmd = result
        return model, cmd
    return result, None  # type: ignore[return-value]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


class TestHelpers:
    """temperature_status and status_color pure functions."""

    def test_cool(self) -> None:
        assert temperature_status(10) == "Cool"
        assert status_color(10) == "#3498db"

    def test_normal(self) -> None:
        assert temperature_status(50) == "Normal"
        assert status_color(50) == "#27ae60"

    def test_warning(self) -> None:
        assert temperature_status(70) == "Warning"
        assert status_color(70) == "#e67e22"

    def test_critical(self) -> None:
        assert temperature_status(90) == "Critical"
        assert status_color(90) == "#e74c3c"

    def test_boundary_40(self) -> None:
        assert temperature_status(40) == "Normal"

    def test_boundary_60(self) -> None:
        assert temperature_status(60) == "Warning"

    def test_boundary_80(self) -> None:
        assert temperature_status(80) == "Critical"


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------


class TestInit:
    """Initial state from init()."""

    def test_initial_temperature(self) -> None:
        model = _app().init()
        assert model.temperature == 20.0

    def test_initial_target(self) -> None:
        model = _app().init()
        assert model.target_temp == 20.0

    def test_initial_history(self) -> None:
        model = _app().init()
        assert model.history == (20.0,)


# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------


class TestUpdate:
    """Event handling in update()."""

    def test_reset_button(self) -> None:
        app = _app()
        model = replace(Model(), temperature=50.0, target_temp=50.0)
        new_model, cmd = _unwrap(app.update(model, Click(id="reset")))
        assert new_model.target_temp == 20.0
        assert cmd is not None
        assert cmd.type == "extension_command"
        assert cmd.payload["op"] == "set_value"
        assert cmd.payload["payload"]["value"] == 20.0

    def test_high_button(self) -> None:
        app = _app()
        model = Model()
        new_model, cmd = _unwrap(app.update(model, Click(id="high")))
        assert new_model.target_temp == 90.0
        assert cmd is not None
        assert cmd.type == "extension_command"
        assert cmd.payload["op"] == "set_value"
        assert cmd.payload["payload"]["value"] == 90.0

    def test_slider_updates_target(self) -> None:
        app = _app()
        model = Model()
        new_model, cmd = _unwrap(app.update(model, Slide(id="target", value=65.0)))
        assert new_model.target_temp == 65.0
        assert cmd is not None
        assert cmd.payload["op"] == "animate_to"
        assert cmd.payload["payload"]["value"] == 65.0

    def test_value_changed_event(self) -> None:
        app = _app()
        model = Model()
        event = WidgetEvent(
            kind="value_changed",
            id="temp",
            value=None,
            data={"value": 42.0},
        )
        new_model, cmd = _unwrap(app.update(model, event))
        assert new_model.temperature == 42.0
        assert cmd is None

    def test_history_accumulates(self) -> None:
        app = _app()
        model = Model()
        for temp in [30.0, 50.0, 70.0]:
            event = WidgetEvent(
                kind="value_changed",
                id="temp",
                value=None,
                data={"value": temp},
            )
            model, _ = _unwrap(app.update(model, event))
        assert model.history == (20.0, 30.0, 50.0, 70.0)

    def test_unknown_event_returns_model_unchanged(self) -> None:
        app = _app()
        model = Model()
        result = app.update(model, Click(id="nonexistent"))
        # Bare model return (no command)
        assert result is model


# ---------------------------------------------------------------------------
# View
# ---------------------------------------------------------------------------


class TestView:
    """View tree structure."""

    def test_has_window(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        assert tree is not None
        assert tree["type"] == "window"

    def test_has_title_text(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        node = find(tree, "title")
        assert node is not None
        assert text_of(node) == "Temperature Monitor"

    def test_has_gauge(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        node = find(tree, "temp")
        assert node is not None
        assert node["type"] == "gauge"

    def test_has_status_text(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        node = find(tree, "status")
        assert node is not None
        assert "Cool" in (text_of(node) or "")

    def test_has_reading_text(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        node = find(tree, "reading")
        assert node is not None
        content = text_of(node) or ""
        assert "20" in content
        assert "Target" in content

    def test_has_slider(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        node = find(tree, "target")
        assert node is not None
        assert node["type"] == "slider"

    def test_has_buttons(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        assert find(tree, "reset") is not None
        assert find(tree, "high") is not None

    def test_has_history_text(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        node = find(tree, "history")
        assert node is not None
        assert "20" in (text_of(node) or "")

    def test_status_changes_with_temperature(self) -> None:
        app = _app()
        model = replace(Model(), temperature=85.0)
        tree = normalize(app.view(model))
        node = find(tree, "status")
        assert node is not None
        assert "Critical" in (text_of(node) or "")


# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------


class TestSettings:
    """Settings returned by the app."""

    def test_extension_config_present(self) -> None:
        app = _app()
        s = app.settings()
        assert "extension_config" in s
        assert "gauge" in s["extension_config"]

    def test_gauge_config_values(self) -> None:
        app = _app()
        cfg = app.settings()["extension_config"]["gauge"]
        assert cfg["arcWidth"] == 8
        assert cfg["tickCount"] == 10
