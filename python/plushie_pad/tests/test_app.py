"""Pad tests driven through the real renderer via AppFixture."""

from __future__ import annotations

import pytest
from plushie.testing import AppFixture

from plushie_pad.app import Pad


@pytest.fixture
def app(plushie_pool):
    with AppFixture(Pad, plushie_pool) as fixture:
        yield fixture


def test_default_experiment_loads(app):
    app.assert_exists("pad#editor")
    assert app.model.selected == "hello"
    assert "Hello, Plushie!" in app.model.editor_source


def test_edit_marks_dirty(app):
    app.type_text("pad#editor", "\n# added a comment\n")
    assert app.model.dirty is True


def test_save_clears_dirty(app):
    app.type_text("pad#editor", "\n# added\n")
    app.click("pad#save")
    assert app.model.dirty is False
