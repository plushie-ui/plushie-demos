"""Tests for the Collab app logic.

Tests the app directly (no renderer needed) by calling init/update/view
and inspecting the results. Verifies the Elm architecture contract:
init produces correct defaults, update handles all event types, view
returns a well-structured tree with the expected widget IDs.
"""

from __future__ import annotations

from dataclasses import replace

from collab_demo.collab import Collab, Model
from plushie.events import Click, Input, Toggle
from plushie.tree import find, normalize, text_of


def _app() -> Collab:
    return Collab()


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------


class TestInit:
    """Initial state from init()."""

    def test_default_name(self) -> None:
        model = _app().init()
        assert model.name == ""

    def test_default_notes(self) -> None:
        model = _app().init()
        assert model.notes == ""

    def test_default_count(self) -> None:
        model = _app().init()
        assert model.count == 0

    def test_default_dark_mode(self) -> None:
        model = _app().init()
        assert model.dark_mode is False

    def test_default_status(self) -> None:
        model = _app().init()
        assert model.status == ""


# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------


class TestUpdate:
    """Event handling in update()."""

    def test_increment(self) -> None:
        app = _app()
        model = app.init()
        result = app.update(model, Click(id="inc"))
        assert result.count == 1

    def test_decrement(self) -> None:
        app = _app()
        model = app.init()
        result = app.update(model, Click(id="dec"))
        assert result.count == -1

    def test_increment_from_nonzero(self) -> None:
        app = _app()
        model = replace(Model(), count=5)
        result = app.update(model, Click(id="inc"))
        assert result.count == 6

    def test_input_name(self) -> None:
        app = _app()
        model = app.init()
        result = app.update(model, Input(id="name", value="Alice"))
        assert result.name == "Alice"

    def test_input_notes(self) -> None:
        app = _app()
        model = app.init()
        result = app.update(model, Input(id="notes", value="hello world"))
        assert result.notes == "hello world"

    def test_toggle_theme_on(self) -> None:
        app = _app()
        model = app.init()
        result = app.update(model, Toggle(id="theme", value=True))
        assert result.dark_mode is True

    def test_toggle_theme_off(self) -> None:
        app = _app()
        model = replace(Model(), dark_mode=True)
        result = app.update(model, Toggle(id="theme", value=False))
        assert result.dark_mode is False

    def test_unknown_event_returns_model_unchanged(self) -> None:
        app = _app()
        model = app.init()
        result = app.update(model, Click(id="nonexistent"))
        assert result is model

    def test_update_preserves_other_fields(self) -> None:
        """Incrementing count should not touch name or notes."""
        app = _app()
        model = replace(Model(), name="Bob", notes="stuff", count=3)
        result = app.update(model, Click(id="inc"))
        assert result.count == 4
        assert result.name == "Bob"
        assert result.notes == "stuff"


# ---------------------------------------------------------------------------
# View
# ---------------------------------------------------------------------------


class TestView:
    """View tree structure and widget IDs."""

    def test_has_window(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        assert tree["type"] == "window"

    def test_has_header(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        node = find(tree, "header")
        assert node is not None
        assert text_of(node) == "Plushie Demo"

    def test_has_status(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        node = find(tree, "status")
        assert node is not None

    def test_has_name_input(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        node = find(tree, "name")
        assert node is not None
        assert node["type"] == "text_input"

    def test_has_notes_input(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        node = find(tree, "notes")
        assert node is not None
        assert node["type"] == "text_input"

    def test_has_inc_button(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        node = find(tree, "inc")
        assert node is not None
        assert node["type"] == "button"

    def test_has_dec_button(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        node = find(tree, "dec")
        assert node is not None
        assert node["type"] == "button"

    def test_has_count_text(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        node = find(tree, "count")
        assert node is not None
        assert text_of(node) == "Count: 0"

    def test_has_theme_checkbox(self) -> None:
        app = _app()
        tree = normalize(app.view(app.init()))
        node = find(tree, "theme")
        assert node is not None
        assert node["type"] == "checkbox"

    def test_count_reflects_model(self) -> None:
        app = _app()
        model = replace(Model(), count=42)
        tree = normalize(app.view(model))
        node = find(tree, "count")
        assert node is not None
        assert text_of(node) == "Count: 42"

    def test_theme_changes_with_dark_mode(self) -> None:
        app = _app()
        # Light mode
        model_light = Model()
        tree_light = normalize(app.view(model_light))
        themer_light = find(tree_light, "theme-root")
        assert themer_light is not None
        assert themer_light["props"].get("theme") == "light"

        # Dark mode
        model_dark = replace(Model(), dark_mode=True)
        tree_dark = normalize(app.view(model_dark))
        themer_dark = find(tree_dark, "theme-root")
        assert themer_dark is not None
        assert themer_dark["props"].get("theme") == "dark"

    def test_name_value_in_input(self) -> None:
        app = _app()
        model = replace(Model(), name="Charlie")
        tree = normalize(app.view(model))
        node = find(tree, "name")
        assert node is not None
        assert node["props"]["value"] == "Charlie"

    def test_status_text_shown(self) -> None:
        app = _app()
        model = replace(Model(), status="3 connected")
        tree = normalize(app.view(model))
        node = find(tree, "status")
        assert node is not None
        assert text_of(node) == "3 connected"


# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------


class TestSettings:
    """Settings returned by the app."""

    def test_default_event_rate(self) -> None:
        app = _app()
        s = app.settings()
        assert s["default_event_rate"] == 30

    def test_returns_dict(self) -> None:
        app = _app()
        s = app.settings()
        assert isinstance(s, dict)
