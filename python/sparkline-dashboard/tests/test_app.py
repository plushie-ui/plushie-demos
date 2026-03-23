"""Tests for the Dashboard app logic.

Tests the app directly (no renderer needed) by calling init/update/view
and inspecting the results. Timer events are simulated by constructing
TimerTick instances.

Wire-level sparkline prop tests verify that the view tree carries the
correct extension type, data, color, and fill after each interaction.
This proves that props cross the wire to the extension widget.

AppFixture integration tests exercise the full init -> update -> view ->
normalize -> renderer cycle against a real plushie binary.
"""

from __future__ import annotations

import math
from dataclasses import replace

import pytest

from sparkline_dashboard.app import (
    MAX_SAMPLES,
    Dashboard,
    Model,
    cpu_sample,
    mem_sample,
    net_sample,
)
from plushie.events import Click, TimerTick
from plushie.subscriptions import Subscription
from plushie.tree import find, normalize, text_of


def _app() -> Dashboard:
    return Dashboard()


def _timer_event() -> TimerTick:
    return TimerTick(tag="sample", timestamp=0)


def _sparkline_props(model: Model, node_id: str) -> dict:
    """Render the view tree and return a sparkline node's props."""
    tree = normalize(_app().view(model))
    node = find(tree, node_id)
    assert node is not None, f"sparkline node '{node_id}' not found in tree"
    return node["props"]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


class TestHelpers:
    """Metric generation helper functions."""

    def test_cpu_sample_includes_sine_wave(self) -> None:
        """CPU samples incorporate a sine wave component."""
        # At tick 0, sin(0) = 0, so the wave component is 0.
        # At other ticks, the wave shifts the value.
        samples_at_0 = [cpu_sample(0) for _ in range(100)]
        samples_at_5 = [cpu_sample(5) for _ in range(100)]
        # The averages should differ due to the sine component
        avg_0 = sum(samples_at_0) / len(samples_at_0)
        avg_5 = sum(samples_at_5) / len(samples_at_5)
        # sin(0) * 15 = 0; sin(0.5) * 15 ~ 7.2
        # The difference in averages should reflect the sine offset
        expected_offset = math.sin(5 * 0.1) * 15
        assert abs((avg_5 - avg_0) - expected_offset) < 5  # within noise margin

    def test_cpu_sample_in_range(self) -> None:
        for tick in range(20):
            val = cpu_sample(tick)
            assert 0 <= val <= 100, f"cpu_sample({tick}) = {val}"

    def test_mem_sample_oscillates(self) -> None:
        """Memory samples stay in the 20-100 range via modular arithmetic."""
        for tick in range(200):
            val = mem_sample(tick)
            assert 20 <= val <= 100, f"mem_sample({tick}) = {val}"

    def test_net_sample_in_range(self) -> None:
        for _ in range(100):
            val = net_sample()
            assert 0 <= val <= 100, f"net_sample() = {val}"


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------


class TestInit:
    """Initial state from init()."""

    def test_empty_samples(self) -> None:
        model = _app().init()
        assert model.cpu_samples == ()
        assert model.mem_samples == ()
        assert model.net_samples == ()

    def test_running_true(self) -> None:
        model = _app().init()
        assert model.running is True

    def test_tick_count_zero(self) -> None:
        model = _app().init()
        assert model.tick_count == 0


# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------


class TestUpdate:
    """Event handling in update()."""

    def test_timer_adds_samples(self) -> None:
        app = _app()
        model = app.init()
        updated = app.update(model, _timer_event())

        assert len(updated.cpu_samples) == 1
        assert len(updated.mem_samples) == 1
        assert len(updated.net_samples) == 1
        assert updated.tick_count == 1

    def test_timer_ignored_when_paused(self) -> None:
        app = _app()
        model = replace(app.init(), running=False)
        updated = app.update(model, _timer_event())

        assert updated.cpu_samples == ()
        assert updated.tick_count == 0

    def test_samples_capped_at_max(self) -> None:
        app = _app()
        model = replace(
            app.init(),
            cpu_samples=tuple(range(MAX_SAMPLES)),
            mem_samples=tuple(range(MAX_SAMPLES)),
            net_samples=tuple(range(MAX_SAMPLES)),
        )
        updated = app.update(model, _timer_event())

        assert len(updated.cpu_samples) == MAX_SAMPLES
        assert len(updated.mem_samples) == MAX_SAMPLES
        assert len(updated.net_samples) == MAX_SAMPLES

    def test_tick_count_increments(self) -> None:
        app = _app()
        model = app.init()
        m1 = app.update(model, _timer_event())
        m2 = app.update(m1, _timer_event())
        m3 = app.update(m2, _timer_event())

        assert m3.tick_count == 3

    def test_toggle_pauses(self) -> None:
        app = _app()
        model = app.init()
        updated = app.update(model, Click(id="toggle_running"))
        assert updated.running is False

    def test_toggle_resumes(self) -> None:
        app = _app()
        model = replace(app.init(), running=False)
        updated = app.update(model, Click(id="toggle_running"))
        assert updated.running is True

    def test_clear_resets(self) -> None:
        app = _app()
        model = replace(
            app.init(),
            cpu_samples=(1.0, 2.0, 3.0),
            mem_samples=(4.0, 5.0, 6.0),
            net_samples=(7.0, 8.0, 9.0),
            tick_count=42,
        )
        updated = app.update(model, Click(id="clear"))

        assert updated.cpu_samples == ()
        assert updated.mem_samples == ()
        assert updated.net_samples == ()
        assert updated.tick_count == 0

    def test_unknown_event_returns_model_unchanged(self) -> None:
        app = _app()
        model = app.init()
        result = app.update(model, Click(id="nonexistent"))
        assert result is model


# ---------------------------------------------------------------------------
# Subscribe
# ---------------------------------------------------------------------------


class TestSubscribe:
    """Subscription management."""

    def test_active_when_running(self) -> None:
        app = _app()
        model = app.init()
        subs = app.subscribe(model)

        assert len(subs) == 1
        assert isinstance(subs[0], Subscription)
        assert subs[0].tag == "sample"
        assert subs[0].interval_ms == 500

    def test_empty_when_paused(self) -> None:
        app = _app()
        model = replace(app.init(), running=False)
        subs = app.subscribe(model)

        assert subs == []


# ---------------------------------------------------------------------------
# View
# ---------------------------------------------------------------------------


class TestView:
    """View tree structure."""

    def test_has_window(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        assert tree["type"] == "window"
        assert tree["id"] == "main"

    def test_has_title_text(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        node = find(tree, "title")
        assert node is not None
        assert text_of(node) == "System Monitor"

    def test_has_controls(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        assert find(tree, "toggle_running") is not None
        assert find(tree, "clear") is not None
        assert find(tree, "status") is not None

    def test_has_sparkline_cards(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        assert find(tree, "cpu_spark") is not None
        assert find(tree, "mem_spark") is not None
        assert find(tree, "net_spark") is not None
        assert find(tree, "cpu_label") is not None
        assert find(tree, "mem_label") is not None
        assert find(tree, "net_label") is not None

    def test_pause_button_label_when_running(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        node = find(tree, "toggle_running")
        assert node is not None
        assert text_of(node) == "Pause"

    def test_resume_button_label_when_paused(self) -> None:
        app = _app()
        model = replace(app.init(), running=False)
        tree = normalize(app.view(model))
        node = find(tree, "toggle_running")
        assert node is not None
        assert text_of(node) == "Resume"

    def test_status_shows_sample_count(self) -> None:
        app = _app()
        model = replace(app.init(), cpu_samples=tuple(range(42)))
        tree = normalize(app.view(model))
        node = find(tree, "status")
        assert node is not None
        assert text_of(node) == "42 samples"

    def test_value_shown_when_data_present(self) -> None:
        app = _app()
        model = replace(app.init(), cpu_samples=(10.0, 20.0, 30.5))
        tree = normalize(app.view(model))
        node = find(tree, "cpu_value")
        assert node is not None
        assert text_of(node) == "30.5"

    def test_no_value_when_data_empty(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        # cpu_value should not exist when there's no data
        node = find(tree, "cpu_value")
        assert node is None


# ---------------------------------------------------------------------------
# Wire-level sparkline props
# ---------------------------------------------------------------------------


class TestSparklineWireProps:
    """Verify sparkline extension props in the view tree.

    These tests inspect the normalized view tree to confirm that the
    sparkline widgets carry the correct type, data, color, and fill.
    This is the closest we get to wire-level verification without a
    running renderer -- the same props that appear here are what gets
    encoded to msgpack and sent to the Rust extension.
    """

    def test_sparkline_type(self) -> None:
        model = _app().init()
        tree = normalize(_app().view(model))
        for node_id in ("cpu_spark", "mem_spark", "net_spark"):
            node = find(tree, node_id)
            assert node is not None
            assert node["type"] == "sparkline"

    def test_initial_sparkline_props(self) -> None:
        model = _app().init()
        cpu_props = _sparkline_props(model, "cpu_spark")
        assert cpu_props["data"] == []
        assert cpu_props["color"] == "#4CAF50"
        assert cpu_props["fill"] is True
        assert cpu_props["stroke_width"] == 2.0
        assert cpu_props["height"] == 60.0

    def test_net_sparkline_no_fill(self) -> None:
        model = _app().init()
        net_props = _sparkline_props(model, "net_spark")
        assert net_props["color"] == "#FF9800"
        assert net_props["fill"] is False

    def test_sparkline_data_after_tick(self) -> None:
        app = _app()
        model = app.update(app.init(), _timer_event())
        cpu_props = _sparkline_props(model, "cpu_spark")
        assert len(cpu_props["data"]) == 1
        assert isinstance(cpu_props["data"][0], float)


# ---------------------------------------------------------------------------
# Sequential journey
# ---------------------------------------------------------------------------


class TestSequentialJourney:
    """A realistic user journey testing state accumulation.

    Walks through: init -> tick -> tick -> pause -> tick ignored ->
    resume -> tick -> clear.
    """

    def test_full_journey(self) -> None:
        app = _app()
        model = app.init()

        # -- Initial state --
        assert model.cpu_samples == ()
        assert model.running is True
        assert model.tick_count == 0

        # -- First tick --
        model = app.update(model, _timer_event())
        assert len(model.cpu_samples) == 1
        assert model.tick_count == 1

        # -- Second tick --
        model = app.update(model, _timer_event())
        assert len(model.cpu_samples) == 2
        assert model.tick_count == 2

        # -- Pause --
        model = app.update(model, Click(id="toggle_running"))
        assert model.running is False

        # -- Tick ignored while paused --
        model = app.update(model, _timer_event())
        assert len(model.cpu_samples) == 2
        assert model.tick_count == 2

        # -- Resume --
        model = app.update(model, Click(id="toggle_running"))
        assert model.running is True

        # -- Tick after resume --
        model = app.update(model, _timer_event())
        assert len(model.cpu_samples) == 3
        assert model.tick_count == 3

        # -- Clear --
        model = app.update(model, Click(id="clear"))
        assert model.cpu_samples == ()
        assert model.mem_samples == ()
        assert model.net_samples == ()
        assert model.tick_count == 0

        # -- Verify wire props after clear --
        cpu_props = _sparkline_props(model, "cpu_spark")
        assert cpu_props["data"] == []


# ---------------------------------------------------------------------------
# Rapid interactions
# ---------------------------------------------------------------------------


class TestRapidInteractions:
    """Rapid toggle and clear operations maintain consistency."""

    def test_rapid_toggle(self) -> None:
        app = _app()
        model = app.init()

        for _ in range(10):
            model = app.update(model, Click(id="toggle_running"))
        # Even number of toggles -> back to running
        assert model.running is True

    def test_rapid_tick_then_clear(self) -> None:
        app = _app()
        model = app.init()

        for _ in range(50):
            model = app.update(model, _timer_event())
        assert len(model.cpu_samples) == 50

        model = app.update(model, Click(id="clear"))
        assert model.cpu_samples == ()
        assert model.tick_count == 0

    def test_samples_overflow_cap(self) -> None:
        """Pumping more than MAX_SAMPLES ticks stays capped."""
        app = _app()
        model = app.init()

        for _ in range(MAX_SAMPLES + 20):
            model = app.update(model, _timer_event())

        assert len(model.cpu_samples) == MAX_SAMPLES
        assert len(model.mem_samples) == MAX_SAMPLES
        assert len(model.net_samples) == MAX_SAMPLES
        assert model.tick_count == MAX_SAMPLES + 20


# ---------------------------------------------------------------------------
# Extension command wire path (render-only, no commands)
# ---------------------------------------------------------------------------

# The sparkline extension is render-only. It has no commands -- all
# interaction happens through the view tree props. The full wire path:
#
#     Python timer tick -> update() adds sample to model
#     -> view() passes samples as sparkline data prop
#     -> Runtime diffs the tree, sends patch to binary
#     -> Rust SparklineExtension::render() reads data array
#     -> iced canvas draws the chart
#
# There is no reverse path (no events from the extension). This is
# the simplest extension pattern: pure props in, rendered pixels out.


# ---------------------------------------------------------------------------
# AppFixture integration tests (require plushie renderer)
# ---------------------------------------------------------------------------


class TestAppFixtureDashboard:
    """Integration tests using AppFixture against the real binary.

    These exercise the full init -> update -> view -> normalize ->
    renderer cycle. The binary must include the sparkline extension.
    """

    @pytest.fixture(autouse=True)
    def _require_pool(self, plushie_pool: object) -> None:
        self._pool = plushie_pool

    def test_window_exists(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(Dashboard, self._pool) as app:
            assert app.tree is not None
            assert app.tree["type"] == "window"
            assert app.tree["id"] == "main"

    def test_initial_model(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(Dashboard, self._pool) as app:
            assert app.model.cpu_samples == ()
            assert app.model.running is True
            assert app.model.tick_count == 0

    def test_sparkline_widgets_exist(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(Dashboard, self._pool) as app:
            # Sparklines are inside named containers (cpu_card, etc.)
            # so their wire IDs are scoped: cpu_card/cpu_spark
            for card, spark in [
                ("cpu_card", "cpu_spark"),
                ("mem_card", "mem_spark"),
                ("net_card", "net_spark"),
            ]:
                app.assert_exists(f"#{card}/{spark}")
                el = app.find(f"#{card}/{spark}")
                assert el.type == "sparkline"

    def test_sparkline_initial_props(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(Dashboard, self._pool) as app:
            el = app.find("#cpu_card/cpu_spark")
            assert el.props["data"] == []
            assert el.props["color"] == "#4CAF50"
            assert el.props["fill"] is True

    def test_view_structure(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(Dashboard, self._pool) as app:
            app.assert_exists("#title")
            app.assert_exists("#toggle_running")
            app.assert_exists("#clear")
            app.assert_exists("#status")
            app.assert_exists("#cpu_card/cpu_spark")
            app.assert_exists("#mem_card/mem_spark")
            app.assert_exists("#net_card/net_spark")
            app.assert_exists("#cpu_card/cpu_label")
            app.assert_exists("#mem_card/mem_label")
            app.assert_exists("#net_card/net_label")

    def test_title_text(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(Dashboard, self._pool) as app:
            app.assert_text("#title", "System Monitor")

    def test_pause_button_label(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(Dashboard, self._pool) as app:
            # Initially running -> button says "Pause"
            app.assert_text("#toggle_running", "Pause")

    def test_click_toggle_pauses(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(Dashboard, self._pool) as app:
            app.click("#toggle_running")
            assert app.model.running is False
            app.assert_text("#toggle_running", "Resume")

    def test_click_toggle_resumes(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(Dashboard, self._pool) as app:
            app.click("#toggle_running")
            assert app.model.running is False
            app.click("#toggle_running")
            assert app.model.running is True
            app.assert_text("#toggle_running", "Pause")

    def test_click_clear(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(Dashboard, self._pool) as app:
            app.click("#clear")
            assert app.model.cpu_samples == ()
            assert app.model.tick_count == 0

    def test_subscribe_returns_timer_when_running(self) -> None:
        """Verify the app declares a timer subscription when running."""
        app = Dashboard()
        model = app.init()
        subs = app.subscribe(model)
        assert len(subs) == 1
        assert subs[0].tag == "sample"
        assert subs[0].interval_ms == 500

    def test_subscribe_empty_when_paused(self) -> None:
        """Verify no subscriptions when paused."""
        from plushie.testing import AppFixture

        with AppFixture(Dashboard, self._pool) as fixture:
            fixture.click("#toggle_running")
            subs = Dashboard().subscribe(fixture.model)
            assert subs == []
