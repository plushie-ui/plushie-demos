"""Sparkline native widget definition and builder function.

Defines the native sparkline widget: a line chart rendered by Rust/iced.
The Python side declares the props; the Rust side handles canvas rendering.

This is a render-only native widget -- no commands or events.
"""

from __future__ import annotations

from plushie.native_widget import NativeWidgetDef, PropDef, build_node

sparkline_def = NativeWidgetDef(
    kind="sparkline",
    rust_crate="native/sparkline",
    rust_constructor="sparkline::SparklineExtension::new()",
    props=[
        PropDef("data", "any"),
        PropDef("color", "color"),
        PropDef("stroke_width", "number"),
        PropDef("fill", "bool"),
        PropDef("height", "number"),
    ],
    commands=[],
)


def sparkline(
    id: str,
    *,
    data: tuple[float, ...] | list[float] = (),
    color: str = "#4CAF50",
    stroke_width: float = 2.0,
    fill: bool = False,
    height: float = 60.0,
) -> dict:
    """Build a sparkline widget node.

    Args:
        id: Unique widget identifier.
        data: Sample data points to render.
        color: Line/fill color.
        stroke_width: Line width in pixels.
        fill: Whether to fill the area under the line.
        height: Widget height in pixels.
    """
    return build_node(
        sparkline_def,
        id,
        {
            "data": list(data),
            "color": color,
            "stroke_width": stroke_width,
            "fill": fill,
            "height": height,
        },
    )
