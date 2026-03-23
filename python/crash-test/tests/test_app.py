"""Tests for the crash test application.

These are pure Python tests that verify crash recovery behavior
without needing the renderer binary.
"""

import pytest

from plushie.events import Click

from crash_test.app import CrashTestApp, Model


@pytest.fixture
def app() -> CrashTestApp:
    return CrashTestApp()


@pytest.fixture
def model() -> Model:
    return Model()


class TestInit:
    """App initializes with clean state."""

    def test_init_returns_model(self, app: CrashTestApp) -> None:
        m = app.init()
        assert isinstance(m, Model)
        assert m.count == 0
        assert m.error_count == 0
        assert m.last_error == ""


class TestCounter:
    """Counter keeps working as proof of life."""

    def test_increment(self, app: CrashTestApp, model: Model) -> None:
        result = app.update(model, Click(id="inc", scope=()))
        assert isinstance(result, Model)
        assert result.count == 1

    def test_decrement(self, app: CrashTestApp, model: Model) -> None:
        result = app.update(model, Click(id="dec", scope=()))
        assert isinstance(result, Model)
        assert result.count == -1

    def test_counter_survives_after_crash(
        self, app: CrashTestApp, model: Model
    ) -> None:
        """Counter works before and after a crash in update."""
        m1 = app.update(model, Click(id="inc", scope=()))
        assert isinstance(m1, Model)
        assert m1.count == 1

        # Crash in update
        with pytest.raises(RuntimeError, match="deliberate update crash"):
            app.update(m1, Click(id="crash-update", scope=()))

        # Counter still works with the pre-crash model
        m2 = app.update(m1, Click(id="inc", scope=()))
        assert isinstance(m2, Model)
        assert m2.count == 2


class TestUpdateCrash:
    """Update crash raises RuntimeError, leaving model untouched."""

    def test_raises(self, app: CrashTestApp, model: Model) -> None:
        with pytest.raises(RuntimeError, match="deliberate update crash"):
            app.update(model, Click(id="crash-update", scope=()))

    def test_model_preserved(self, app: CrashTestApp) -> None:
        m = Model(count=42)
        with pytest.raises(RuntimeError):
            app.update(m, Click(id="crash-update", scope=()))
        # The original model is untouched (frozen dataclass)
        assert m.count == 42


class TestViewCrash:
    """Arming view_crash_armed causes view to raise."""

    def test_arm_sets_flag(self, app: CrashTestApp, model: Model) -> None:
        result = app.update(model, Click(id="crash-view", scope=()))
        assert isinstance(result, Model)
        assert result.view_crash_armed is True

    def test_view_raises_when_armed(self, app: CrashTestApp) -> None:
        armed = Model(view_crash_armed=True)
        with pytest.raises(RuntimeError, match="deliberate view crash"):
            app.view(armed)

    def test_view_ok_when_not_armed(self, app: CrashTestApp, model: Model) -> None:
        tree = app.view(model)
        assert tree["type"] == "window"


class TestReturnNone:
    """The return-none button exercises the no-return path."""

    def test_returns_model(self, app: CrashTestApp, model: Model) -> None:
        # The handler has a fallback return, so it returns the model
        result = app.update(model, Click(id="return-none", scope=()))
        assert isinstance(result, Model)


class TestUnknownEvent:
    """Unknown events pass through the catch-all."""

    def test_catch_all(self, app: CrashTestApp, model: Model) -> None:
        result = app.update(model, Click(id="nonexistent", scope=()))
        assert result is model


class TestRustCrashButtons:
    """Rust crash buttons produce correct model/command changes."""

    def test_panic_render_button(self, app: CrashTestApp, model: Model) -> None:
        result = app.update(model, Click(id="panic-render", scope=()))
        assert isinstance(result, Model)

    def test_panic_command_button(self, app: CrashTestApp, model: Model) -> None:
        result = app.update(model, Click(id="panic-command", scope=()))
        assert isinstance(result, tuple)
        m, cmd = result
        assert isinstance(m, Model)
        assert cmd.type == "extension_command"
        assert cmd.payload["op"] == "panic"


class TestViewStructure:
    """View produces a valid tree."""

    def test_window_node(self, app: CrashTestApp, model: Model) -> None:
        tree = app.view(model)
        assert tree["id"] == "main"
        assert tree["type"] == "window"

    def test_contains_counter(self, app: CrashTestApp, model: Model) -> None:
        tree = app.view(model)
        # Walk children looking for the counter value text
        all_ids = _collect_ids(tree)
        assert "counter-value" in all_ids
        assert "inc" in all_ids
        assert "dec" in all_ids

    def test_contains_crash_buttons(self, app: CrashTestApp, model: Model) -> None:
        tree = app.view(model)
        all_ids = _collect_ids(tree)
        assert "crash-update" in all_ids
        assert "crash-view" in all_ids
        assert "return-none" in all_ids

    def test_contains_crasher_widget(self, app: CrashTestApp, model: Model) -> None:
        tree = app.view(model)
        all_ids = _collect_ids(tree)
        assert "crash-widget" in all_ids


def _collect_ids(node: dict) -> set[str]:
    """Recursively collect all non-None IDs from a UI tree."""
    ids: set[str] = set()
    if node.get("id") is not None:
        ids.add(node["id"])
    for child in node.get("children", []):
        ids |= _collect_ids(child)
    return ids
