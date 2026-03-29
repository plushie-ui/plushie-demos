"""Tests for the gauge native widget definition and builder functions.

These verify the Python side of the native widget: widget builders
produce correct node shapes, command constructors return proper
Command objects, and the definition passes validation.

No binary needed -- pure Python logic.
"""

from __future__ import annotations

from gauge_demo.gauge import (
    animate_gauge_to,
    gauge,
    gauge_def,
    set_gauge_value,
)
from plushie.commands import Command
from plushie.native_widget import validate


class TestGaugeDef:
    """Validate the gauge native widget definition."""

    def test_validation_passes(self) -> None:
        errors = validate(gauge_def)
        assert errors == []

    def test_kind(self) -> None:
        assert gauge_def.kind == "gauge"

    def test_rust_crate(self) -> None:
        assert gauge_def.rust_crate == "native/gauge"

    def test_rust_constructor(self) -> None:
        assert gauge_def.rust_constructor == "gauge::GaugeExtension::new()"

    def test_prop_names(self) -> None:
        names = [p.name for p in gauge_def.props]
        assert names == ["value", "min", "max", "color", "label", "width", "height"]

    def test_prop_types(self) -> None:
        types = {p.name: p.prop_type for p in gauge_def.props}
        assert types == {
            "value": "number",
            "min": "number",
            "max": "number",
            "color": "color",
            "label": "string",
            "width": "length",
            "height": "length",
        }

    def test_command_names(self) -> None:
        names = [c.name for c in gauge_def.commands]
        assert names == ["set_value", "animate_to"]

    def test_command_params(self) -> None:
        """Each command declares a single 'value' param of type 'number'."""
        for cmd_def in gauge_def.commands:
            assert len(cmd_def.params) == 1
            assert cmd_def.params[0].name == "value"
            assert cmd_def.params[0].param_type == "number"


class TestGaugeBuilder:
    """Test the gauge() node builder."""

    def test_builds_node_with_defaults(self) -> None:
        node = gauge("g1")
        assert node["id"] == "g1"
        assert node["type"] == "gauge"
        assert node["props"]["value"] == 0
        assert node["props"]["min"] == 0
        assert node["props"]["max"] == 100

    def test_builds_node_with_custom_props(self) -> None:
        node = gauge("g2", value=50, min=10, max=200, color="#ff0000", label="Hot")
        assert node["props"]["value"] == 50
        assert node["props"]["min"] == 10
        assert node["props"]["max"] == 200
        assert node["props"]["color"] == "#ff0000"
        assert node["props"]["label"] == "Hot"

    def test_event_rate_omitted_by_default(self) -> None:
        node = gauge("g3")
        assert "event_rate" not in node["props"]

    def test_event_rate_included_when_set(self) -> None:
        node = gauge("g4", event_rate=30)
        assert node["props"]["event_rate"] == 30

    def test_children_empty(self) -> None:
        """Gauge is a leaf widget -- it never has children."""
        node = gauge("g5")
        assert node["children"] == []

    def test_node_has_required_keys(self) -> None:
        """Node dict has the complete set of structural keys."""
        node = gauge("g1")
        assert "id" in node
        assert "type" in node
        assert "props" in node
        assert "children" in node
        # No extra keys beyond what the wire protocol expects
        assert set(node.keys()) <= {"id", "type", "props", "children"}


class TestGaugeCommands:
    """Test the gauge command builders.

    Commands are the wire-level mechanism for controlling the Rust
    extension. The full path:

        Python click handler returns (model, Command)
        -> Runtime sends extension_command over msgpack
        -> Custom binary receives it
        -> Rust GaugeExtension::handle_command processes it
    """

    def test_set_gauge_value(self) -> None:
        cmd = set_gauge_value("temp", 42.0)
        assert isinstance(cmd, Command)
        assert cmd.type == "extension_command"
        assert cmd.payload["node_id"] == "temp"
        assert cmd.payload["op"] == "set_value"
        assert cmd.payload["payload"] == {"value": 42.0}

    def test_animate_gauge_to(self) -> None:
        cmd = animate_gauge_to("temp", 75.5)
        assert isinstance(cmd, Command)
        assert cmd.type == "extension_command"
        assert cmd.payload["node_id"] == "temp"
        assert cmd.payload["op"] == "animate_to"
        assert cmd.payload["payload"] == {"value": 75.5}

    def test_command_payload_structure(self) -> None:
        """Extension commands have the standard three-key payload shape."""
        cmd = set_gauge_value("g1", 0.0)
        payload = cmd.payload
        assert set(payload.keys()) == {"node_id", "op", "payload"}

    def test_different_node_ids(self) -> None:
        """Commands target the correct node_id, not a hardcoded value."""
        cmd_a = set_gauge_value("gauge-a", 10.0)
        cmd_b = set_gauge_value("gauge-b", 20.0)
        assert cmd_a.payload["node_id"] == "gauge-a"
        assert cmd_b.payload["node_id"] == "gauge-b"
