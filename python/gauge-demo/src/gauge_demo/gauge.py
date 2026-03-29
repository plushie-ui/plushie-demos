"""Gauge native widget definition and builder functions.

Defines the native gauge widget: a circular gauge rendered by Rust/iced.
The Python side declares the props and commands; the Rust side handles
rendering and animation.
"""

from __future__ import annotations

from plushie.commands import Command
from plushie.native_widget import (
    CommandDef,
    NativeWidgetDef,
    ParamDef,
    PropDef,
    build_command,
    build_node,
)

gauge_def = NativeWidgetDef(
    kind="gauge",
    rust_crate="native/gauge",
    rust_constructor="gauge::GaugeExtension::new()",
    props=[
        PropDef("value", "number"),
        PropDef("min", "number"),
        PropDef("max", "number"),
        PropDef("color", "color"),
        PropDef("label", "string"),
        PropDef("width", "length"),
        PropDef("height", "length"),
    ],
    commands=[
        CommandDef("set_value", [ParamDef("value", "number")]),
        CommandDef("animate_to", [ParamDef("value", "number")]),
    ],
)


def gauge(
    id: str,
    *,
    value: float = 0,
    min: float = 0,
    max: float = 100,
    color: str = "#3498db",
    label: str = "",
    width: float = 200,
    height: float = 200,
    event_rate: int | None = None,
) -> dict:
    """Build a gauge widget node.

    Args:
        id: Unique widget identifier.
        value: Current gauge value.
        min: Minimum value.
        max: Maximum value.
        color: Arc/fill color.
        label: Center label text.
        width: Widget width.
        height: Widget height.
        event_rate: Optional event throttle in Hz.
    """
    props: dict = {
        "value": value,
        "min": min,
        "max": max,
        "color": color,
        "label": label,
        "width": width,
        "height": height,
    }
    if event_rate is not None:
        props["event_rate"] = event_rate
    return build_node(gauge_def, id, props)


def set_gauge_value(node_id: str, value: float) -> Command:
    """Set the gauge to a value immediately."""
    return build_command(gauge_def, node_id, "set_value", {"value": value})


def animate_gauge_to(node_id: str, value: float) -> Command:
    """Animate the gauge to a target value."""
    return build_command(gauge_def, node_id, "animate_to", {"value": value})
