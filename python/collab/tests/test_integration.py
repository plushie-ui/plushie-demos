"""AppFixture integration tests for the Collab app.

Tests the app through the plushie testing framework, which provides
a synchronous test driver with click/type_text/toggle helpers. These
tests exercise the full init -> update -> view -> normalize cycle.
"""

from __future__ import annotations

import pytest

from collab_demo.collab import Collab
from plushie.tree import find, normalize, text_of


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _skip_without_pool(plushie_pool: object) -> None:  # noqa: ARG001
    """Marker -- the fixture itself handles skipping."""


# ---------------------------------------------------------------------------
# Standalone (no renderer) tests using direct app calls
# ---------------------------------------------------------------------------


class TestStandalone:
    """Integration tests that exercise init/update/view without a renderer."""

    def test_click_increment(self) -> None:
        from plushie.events import Click

        app = Collab()
        model = app.init()
        model = app.update(model, Click(id="inc"))
        tree = normalize(app.view(model))
        node = find(tree, "count")
        assert node is not None
        assert text_of(node) == "Count: 1"

    def test_click_decrement(self) -> None:
        from plushie.events import Click

        app = Collab()
        model = app.init()
        model = app.update(model, Click(id="dec"))
        tree = normalize(app.view(model))
        node = find(tree, "count")
        assert node is not None
        assert text_of(node) == "Count: -1"

    def test_type_name(self) -> None:
        from plushie.events import Input

        app = Collab()
        model = app.init()
        model = app.update(model, Input(id="name", value="Alice"))
        tree = normalize(app.view(model))
        node = find(tree, "name")
        assert node is not None
        assert node["props"]["value"] == "Alice"

    def test_type_notes(self) -> None:
        from plushie.events import Input

        app = Collab()
        model = app.init()
        model = app.update(model, Input(id="notes", value="some notes"))
        tree = normalize(app.view(model))
        node = find(tree, "notes")
        assert node is not None
        assert node["props"]["value"] == "some notes"

    def test_toggle_theme(self) -> None:
        from plushie.events import Toggle

        app = Collab()
        model = app.init()
        model = app.update(model, Toggle(id="theme", value=True))
        tree = normalize(app.view(model))
        themer = find(tree, "theme-root")
        assert themer is not None
        assert themer["props"]["theme"] == "dark"

    def test_view_structure(self) -> None:
        """Window > themer > container > column with expected children."""
        app = Collab()
        tree = normalize(app.view(app.init()))

        assert tree["type"] == "window"
        assert tree["id"] == "main"

        # Themer is first child of window
        themer = tree["children"][0]
        assert themer["type"] == "themer"

        # Container is first child of themer
        bg = themer["children"][0]
        assert bg["type"] == "container"

    def test_multiple_increments(self) -> None:
        from plushie.events import Click

        app = Collab()
        model = app.init()
        for _ in range(5):
            model = app.update(model, Click(id="inc"))
        tree = normalize(app.view(model))
        node = find(tree, "count")
        assert node is not None
        assert text_of(node) == "Count: 5"

    def test_inc_then_dec(self) -> None:
        from plushie.events import Click

        app = Collab()
        model = app.init()
        model = app.update(model, Click(id="inc"))
        model = app.update(model, Click(id="inc"))
        model = app.update(model, Click(id="dec"))
        tree = normalize(app.view(model))
        node = find(tree, "count")
        assert node is not None
        assert text_of(node) == "Count: 1"


# ---------------------------------------------------------------------------
# AppFixture tests (require plushie_pool)
# ---------------------------------------------------------------------------


@pytest.mark.renderer
class TestAppFixture:
    """Integration tests using AppFixture (requires plushie renderer)."""

    @pytest.fixture(autouse=True)
    def _require_pool(self, plushie_pool: object) -> None:
        self._pool = plushie_pool

    def test_click_inc(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(Collab, self._pool) as app:
            app.click("#inc")
            assert app.model.count == 1

    def test_click_dec(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(Collab, self._pool) as app:
            app.click("#dec")
            assert app.model.count == -1

    def test_type_name(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(Collab, self._pool) as app:
            app.type_text("#name", "Bob")
            assert app.model.name == "Bob"

    def test_type_notes(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(Collab, self._pool) as app:
            app.type_text("#notes", "hello")
            assert app.model.notes == "hello"

    def test_toggle_theme(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(Collab, self._pool) as app:
            app.toggle("#theme")
            assert app.model.dark_mode is True

    def test_view_has_expected_widgets(self) -> None:
        from plushie.testing import AppFixture

        with AppFixture(Collab, self._pool) as app:
            assert app.tree is not None
            assert find(app.tree, "header") is not None
            assert find(app.tree, "status") is not None
            assert find(app.tree, "name") is not None
            assert find(app.tree, "notes") is not None
            assert find(app.tree, "inc") is not None
            assert find(app.tree, "dec") is not None
            assert find(app.tree, "count") is not None
            assert find(app.tree, "theme") is not None
