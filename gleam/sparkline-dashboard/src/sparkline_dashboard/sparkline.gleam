//// Sparkline extension widget definition.
////
//// Defines a render-only native widget that draws a line chart using
//// iced's canvas. The sparkline has no commands or events -- it purely
//// visualises a data array passed as a prop.
////
//// ## Usage
////
//// ```gleam
//// import sparkline_dashboard/sparkline
//// import plushie/prop/color
////
//// let assert Ok(green) = color.from_hex("#4CAF50")
////
//// sparkline.sparkline("cpu_spark", cpu_samples, [
////   sparkline.color(green),
////   sparkline.fill(True),
////   sparkline.stroke_width(2.0),
////   sparkline.height(60.0),
//// ])
//// ```

import gleam/list
import gleam/result
import plushie/extension
import plushie/node.{type Node, BoolVal, FloatVal, ListVal}
import plushie/prop/color.{type Color}

/// Extension definition for the sparkline widget.
///
/// Declares 5 typed props and no commands (render-only). The Rust crate
/// in `native/sparkline/src/lib.rs` renders the line chart on an iced
/// canvas.
pub const def = extension.ExtensionDef(
  kind: "sparkline",
  rust_crate: "native/sparkline",
  rust_constructor: "sparkline::SparklineExtension::new()",
  props: [
    extension.ListProp("data", "number"),
    extension.ColorProp("color"),
    extension.NumberProp("stroke_width"),
    extension.BooleanProp("fill"),
    extension.NumberProp("height"),
  ],
  commands: [],
)

// -- Attribute type ----------------------------------------------------------

/// Attribute for configuring a sparkline widget.
///
/// Pass these to `sparkline()` to override defaults. Unspecified
/// attributes use sensible defaults (green, stroke 2px, no fill, 60px).
pub type SparklineAttr {
  SparklineColor(Color)
  StrokeWidth(Float)
  Fill(Bool)
  SparklineHeight(Float)
}

// -- Attribute constructors --------------------------------------------------

/// Set the line colour (default: #4CAF50 green).
pub fn color(c: Color) -> SparklineAttr {
  SparklineColor(c)
}

/// Set the line stroke width in pixels (default: 2.0).
pub fn stroke_width(w: Float) -> SparklineAttr {
  StrokeWidth(w)
}

/// Enable or disable fill under the curve (default: False).
pub fn fill(enabled: Bool) -> SparklineAttr {
  Fill(enabled)
}

/// Set the widget height in pixels (default: 60.0).
pub fn height(h: Float) -> SparklineAttr {
  SparklineHeight(h)
}

// -- Builder -----------------------------------------------------------------

/// Default colour for the sparkline (#4CAF50, Material green).
const default_color_hex = "#4caf50"

/// Build a sparkline widget node.
///
/// `id` and `data` are required. The data array is encoded as a
/// `ListVal` of `FloatVal` on the wire. All other properties can be
/// set via `SparklineAttr` values, with sensible defaults if omitted.
pub fn sparkline(
  id: String,
  data: List(Float),
  attrs: List(SparklineAttr),
) -> Node {
  let assert Ok(default_color) = color.from_hex(default_color_hex)

  extension.build(def, id, [
    #("data", ListVal(list.map(data, FloatVal))),
    #(
      "color",
      color.to_prop_value(resolve(attrs, extract_color, default_color)),
    ),
    #("stroke_width", FloatVal(resolve(attrs, extract_stroke_width, 2.0))),
    #("fill", BoolVal(resolve(attrs, extract_fill, False))),
    #("height", FloatVal(resolve(attrs, extract_height, 60.0))),
  ])
}

// -- Attr resolution ---------------------------------------------------------

fn resolve(
  attrs: List(SparklineAttr),
  extract: fn(SparklineAttr) -> Result(a, Nil),
  default: a,
) -> a {
  attrs
  |> list.find_map(extract)
  |> result.unwrap(default)
}

fn extract_color(attr: SparklineAttr) -> Result(Color, Nil) {
  case attr {
    SparklineColor(c) -> Ok(c)
    _ -> Error(Nil)
  }
}

fn extract_stroke_width(attr: SparklineAttr) -> Result(Float, Nil) {
  case attr {
    StrokeWidth(w) -> Ok(w)
    _ -> Error(Nil)
  }
}

fn extract_fill(attr: SparklineAttr) -> Result(Bool, Nil) {
  case attr {
    Fill(b) -> Ok(b)
    _ -> Error(Nil)
  }
}

fn extract_height(attr: SparklineAttr) -> Result(Float, Nil) {
  case attr {
    SparklineHeight(h) -> Ok(h)
    _ -> Error(Nil)
  }
}
