"""Tests for the TemperatureMonitor app logic.

Tests the app directly (no renderer needed) by calling init/update/view
and inspecting the results. Extension events (value_changed) are
simulated by constructing WidgetEvent instances.

Wire-level gauge prop tests verify that the view tree carries the
correct extension type, value, color, and label after each interaction.
This proves that props cross the wire to the extension widget.

AppFixture integration tests exercise the full init -> update -> view ->
normalize -> renderer cycle against a real plushie binary.
"""

from __future__ import annotations

from dataclasses import replace

import pytest

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


def _gauge_props(model: Model) -> dict:
    """Render the view tree and return the gauge node's props."""
    tree = normalize(_app().view(model))
    node = find(tree, "temp")
    assert node is not None, "gauge node 'temp' not found in tree"
    return node["props"]


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

    def test_slider_does_not_change_current_temperature(self) -> None:
        """animate_to updates the Rust-side target only, not the Python model's temperature.

        The slider sends an animate_to extension command to the Rust
        gauge, which smoothly animates the needle. The Python-side
        temperature field only changes when the Rust extension emits
        a value_changed event back.
        """
        app = _app()
        model = Model()
        new_model, _cmd = _unwrap(app.update(model, Slide(id="target", value=75.0)))
        assert new_model.target_temp == 75.0
        assert new_model.temperature == 20.0  # unchanged

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
# Wire-level gauge props
# ---------------------------------------------------------------------------


class TestGaugeWireProps:
    """Verify gauge extension props in the view tree after interactions.

    These tests inspect the normalized view tree to confirm that the
    gauge widget carries the correct type, value, color, and label.
    This is the closest we get to wire-level verification without a
    running renderer -- the same props that appear here are what gets
    encoded to msgpack and sent to the Rust extension.
    """

    def test_initial_gauge_props(self) -> None:
        model = _app().init()
        props = _gauge_props(model)
        assert props["value"] == 20.0
        assert props["min"] == 0
        assert props["max"] == 100
        assert props["color"] == "#3498db"
        assert props["label"] == "20\u00b0C"

    def test_gauge_type_is_extension(self) -> None:
        """'gauge' is NOT a built-in widget type -- it only exists because
        the Rust extension registered it via WidgetExtension::type_names."""
        tree = normalize(_app().view(_app().init()))
        node = find(tree, "temp")
        assert node is not None
        assert node["type"] == "gauge"

    def test_gauge_props_after_high(self) -> None:
        # The full path: click handler returns (model, Command.extension_command)
        # -> Runtime sends extension_command over msgpack
        # -> Custom binary receives it
        # -> Rust GaugeExtension::handle_command processes it
        #
        # Here we verify the Python-side optimistic update produces
        # correct props in the view tree. The extension_command goes
        # to Rust in parallel.
        app = _app()
        model = app.init()
        event = WidgetEvent(
            kind="value_changed", id="temp", value=None, data={"value": 90.0}
        )
        model, _ = _unwrap(app.update(model, event))

        props = _gauge_props(model)
        assert props["value"] == 90.0
        assert props["color"] == "#e74c3c"
        assert props["label"] == "90\u00b0C"

    def test_gauge_props_after_reset(self) -> None:
        app = _app()
        model = replace(Model(), temperature=90.0, history=(20.0, 90.0))
        event = WidgetEvent(
            kind="value_changed", id="temp", value=None, data={"value": 20.0}
        )
        model, _ = _unwrap(app.update(model, event))

        props = _gauge_props(model)
        assert props["value"] == 20.0
        assert props["color"] == "#3498db"
        assert props["label"] == "20\u00b0C"


# ---------------------------------------------------------------------------
# Sequential stateful journey
# ---------------------------------------------------------------------------


class TestStatefulJourney:
    """A single realistic user journey testing state accumulation.

    Walks through: initial -> high -> verify -> reset -> verify ->
    slide to 75 -> verify target -> rapid high/reset -> verify history.
    """

    def test_full_journey(self) -> None:
        app = _app()
        model = app.init()

        # -- Initial state --
        assert model.temperature == 20.0
        assert model.target_temp == 20.0
        assert model.history == (20.0,)

        props = _gauge_props(model)
        assert props["value"] == 20.0
        assert props["color"] == "#3498db"

        # -- Click high --
        model, cmd = _unwrap(app.update(model, Click(id="high")))
        assert cmd is not None
        assert cmd.type == "extension_command"
        assert model.target_temp == 90.0

        # Simulate the Rust extension responding with value_changed
        event = WidgetEvent(
            kind="value_changed", id="temp", value=None, data={"value": 90.0}
        )
        model, _ = _unwrap(app.update(model, event))
        assert model.temperature == 90.0

        props = _gauge_props(model)
        assert props["value"] == 90.0
        assert props["color"] == "#e74c3c"
        assert props["label"] == "90\u00b0C"

        # -- Click reset --
        model, cmd = _unwrap(app.update(model, Click(id="reset")))
        assert cmd is not None
        assert model.target_temp == 20.0

        event = WidgetEvent(
            kind="value_changed", id="temp", value=None, data={"value": 20.0}
        )
        model, _ = _unwrap(app.update(model, event))
        assert model.temperature == 20.0

        props = _gauge_props(model)
        assert props["value"] == 20.0
        assert props["color"] == "#3498db"

        # -- Slide to 75 --
        model, cmd = _unwrap(app.update(model, Slide(id="target", value=75.0)))
        assert model.target_temp == 75.0
        assert model.temperature == 20.0  # slider doesn't change current temp
        assert cmd is not None
        assert cmd.payload["op"] == "animate_to"

        # -- Rapid high/reset clicks --
        for _ in range(3):
            model, _ = _unwrap(app.update(model, Click(id="high")))
            event = WidgetEvent(
                kind="value_changed", id="temp", value=None, data={"value": 90.0}
            )
            model, _ = _unwrap(app.update(model, event))

            model, _ = _unwrap(app.update(model, Click(id="reset")))
            event = WidgetEvent(
                kind="value_changed", id="temp", value=None, data={"value": 20.0}
            )
            model, _ = _unwrap(app.update(model, event))

        # History should have the full sequence
        assert model.history[-1] == 20.0
        assert model.history[-2] == 90.0
        assert model.temperature == 20.0
        assert model.target_temp == 20.0


# ---------------------------------------------------------------------------
# Rapid click consistency
# ---------------------------------------------------------------------------


class TestRapidClicks:
    """Multiple high/reset clicks verify final state and history integrity."""

    def test_rapid_high_reset_maintains_consistency(self) -> None:
        app = _app()
        model = app.init()

        for _ in range(5):
            # High
            model, _ = _unwrap(app.update(model, Click(id="high")))
            event = WidgetEvent(
                kind="value_changed", id="temp", value=None, data={"value": 90.0}
            )
            model, _ = _unwrap(app.update(model, event))

            # Reset
            model, _ = _unwrap(app.update(model, Click(id="reset")))
            event = WidgetEvent(
                kind="value_changed", id="temp", value=None, data={"value": 20.0}
            )
            model, _ = _unwrap(app.update(model, event))

        assert model.temperature == 20.0
        assert model.target_temp == 20.0

        # History alternates: 20 -> 90 -> 20 -> 90 -> ... -> 20
        assert model.history[0] == 20.0
        assert model.history[-1] == 20.0
        assert model.history[-2] == 90.0

        # Every odd index should be 90, every even index should be 20
        for i, temp in enumerate(model.history):
            expected = 90.0 if i % 2 == 1 else 20.0
            assert temp == expected, f"history[{i}] = {temp}, expected {expected}"

    def test_rapid_clicks_produce_correct_commands(self) -> None:
        """Each click produces the correct extension command regardless of pace."""
        app = _app()
        model = app.init()
        commands: list[Command] = []

        for _ in range(3):
            model, cmd = _unwrap(app.update(model, Click(id="high")))
            assert cmd is not None
            commands.append(cmd)
            model, cmd = _unwrap(app.update(model, Click(id="reset")))
            assert cmd is not None
            commands.append(cmd)

        # All commands should be extension_commands with alternating ops
        for i, cmd in enumerate(commands):
            assert cmd.type == "extension_command"
            if i % 2 == 0:
                assert cmd.payload["op"] == "set_value"
                assert cmd.payload["payload"]["value"] == 90.0
            else:
                assert cmd.payload["op"] == "set_value"
                assert cmd.payload["payload"]["value"] == 20.0


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


# ---------------------------------------------------------------------------
# AppFixture integration tests (require plushie renderer)
# ---------------------------------------------------------------------------


class TestAppFixtureGauge:
    """Integration tests using AppFixture against the real binary.

    These exercise the full init -> update -> view -> normalize ->
    renderer cycle. The binary must include the gauge extension.
    """

    @pytest.fixture(autouse=True)
    def _require_pool(self, plushie_pool: object) -> None:
        self._pool = plushie_pool

    def test_window_exists(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(TemperatureMonitor, self._pool) as app:
            assert app.tree is not None
            assert app.tree["type"] == "window"

    def test_initial_model(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(TemperatureMonitor, self._pool) as app:
            assert app.model.temperature == 20.0
            assert app.model.target_temp == 20.0
            assert app.model.history == (20.0,)

    def test_gauge_widget_exists(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(TemperatureMonitor, self._pool) as app:
            app.assert_exists("#temp")
            el = app.find("#temp")
            assert el.type == "gauge"

    def test_gauge_props_correct(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(TemperatureMonitor, self._pool) as app:
            el = app.find("#temp")
            assert el.props["value"] == 20.0
            assert el.props["min"] == 0
            assert el.props["max"] == 100
            assert el.props["color"] == "#3498db"

    def test_click_high_updates_model(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(TemperatureMonitor, self._pool) as app:
            app.click("#high")
            assert app.model.target_temp == 90.0

    def test_click_reset_updates_model(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(TemperatureMonitor, self._pool) as app:
            app.click("#high")
            app.click("#reset")
            assert app.model.target_temp == 20.0

    def test_slider_updates_target(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(TemperatureMonitor, self._pool) as app:
            app.slide("#target", 65.0)
            assert app.model.target_temp == 65.0
            # Slider doesn't change current temperature (only animate_to)
            assert app.model.temperature == 20.0

    def test_view_structure(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(TemperatureMonitor, self._pool) as app:
            app.assert_exists("#title")
            app.assert_exists("#temp")
            app.assert_exists("#status")
            app.assert_exists("#reading")
            app.assert_exists("#target")
            app.assert_exists("#reset")
            app.assert_exists("#high")
            app.assert_exists("#history")

    def test_title_text(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(TemperatureMonitor, self._pool) as app:
            app.assert_text("#title", "Temperature Monitor")

    def test_status_text_initial(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(TemperatureMonitor, self._pool) as app:
            text = app.text("#status")
            assert text is not None
            assert "Cool" in text

    def test_high_then_reset_journey(self) -> None:
        """Click high, verify target, click reset, verify target."""
        from plushie.testing import AppFixture

        with AppFixture(TemperatureMonitor, self._pool) as app:
            app.click("#high")
            assert app.model.target_temp == 90.0

            app.click("#reset")
            assert app.model.target_temp == 20.0
