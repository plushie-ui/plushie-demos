"""Tests for the sparkline native widget definition and builder function.

These verify the Python side of the native widget: the definition
metadata and the widget builder produce correct node shapes.

No binary needed -- pure Python logic.
"""

from __future__ import annotations

from sparkline_dashboard.sparkline import sparkline, sparkline_def
from plushie.native_widget import validate


class TestSparklineDef:
    """Validate the sparkline extension definition."""

    def test_validation_passes(self) -> None:
        errors = validate(sparkline_def)
        assert errors == []

    def test_kind(self) -> None:
        assert sparkline_def.kind == "sparkline"

    def test_rust_crate(self) -> None:
        assert sparkline_def.rust_crate == "native/sparkline"

    def test_rust_constructor(self) -> None:
        assert sparkline_def.rust_constructor == "sparkline::SparklineExtension::new()"

    def test_prop_names(self) -> None:
        names = [p.name for p in sparkline_def.props]
        assert names == ["data", "color", "stroke_width", "fill", "height"]

    def test_prop_types(self) -> None:
        types = {p.name: p.prop_type for p in sparkline_def.props}
        assert types == {
            "data": "any",
            "color": "color",
            "stroke_width": "number",
            "fill": "bool",
            "height": "number",
        }

    def test_no_commands(self) -> None:
        """Sparkline is a render-only extension -- no commands."""
        assert sparkline_def.commands == []


class TestSparklineBuilder:
    """Test the sparkline() node builder."""

    def test_builds_node_with_defaults(self) -> None:
        node = sparkline("s1")
        assert node["id"] == "s1"
        assert node["type"] == "sparkline"
        assert node["props"]["data"] == []
        assert node["props"]["color"] == "#4CAF50"
        assert node["props"]["stroke_width"] == 2.0
        assert node["props"]["fill"] is False
        assert node["props"]["height"] == 60.0

    def test_builds_node_with_custom_props(self) -> None:
        node = sparkline(
            "s2",
            data=(10, 20, 30),
            color="#FF0000",
            stroke_width=3.0,
            fill=True,
            height=80.0,
        )
        assert node["props"]["data"] == [10, 20, 30]
        assert node["props"]["color"] == "#FF0000"
        assert node["props"]["stroke_width"] == 3.0
        assert node["props"]["fill"] is True
        assert node["props"]["height"] == 80.0

    def test_data_converted_to_list(self) -> None:
        """Tuple data is converted to a list for wire transport."""
        node = sparkline("s1", data=(1.0, 2.0, 3.0))
        assert isinstance(node["props"]["data"], list)
        assert node["props"]["data"] == [1.0, 2.0, 3.0]

    def test_empty_data(self) -> None:
        node = sparkline("s1", data=())
        assert node["props"]["data"] == []

    def test_children_empty(self) -> None:
        """Sparkline is a leaf widget -- it never has children."""
        node = sparkline("s1")
        assert node["children"] == []

    def test_node_has_required_keys(self) -> None:
        """Node dict has the complete set of structural keys."""
        node = sparkline("s1")
        assert "id" in node
        assert "type" in node
        assert "props" in node
        assert "children" in node
        assert set(node.keys()) <= {"id", "type", "props", "children"}
