"""Tests for the gauge extension definition and builder functions."""

from __future__ import annotations

from gauge_demo.gauge import (
    animate_gauge_to,
    gauge,
    gauge_def,
    set_gauge_value,
)
from plushie.commands import Command
from plushie.extension import validate


class TestGaugeDef:
    """Validate the gauge extension definition."""

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

    def test_command_names(self) -> None:
        names = [c.name for c in gauge_def.commands]
        assert names == ["set_value", "animate_to"]


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
        node = gauge("g5")
        assert node["children"] == []


class TestGaugeCommands:
    """Test the gauge command builders."""

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
