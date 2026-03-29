//// Gauge extension widget definition.
////
//// Defines the native gauge widget type and its commands. The gauge is
//// rendered by a Rust crate that displays a value as a coloured
//// percentage label inside a fixed-size container.
////
//// ## Usage
////
//// ```gleam
//// import gauge_demo/gauge
//// import plushie/prop/color
//// import plushie/prop/length.{Fixed}
////
//// let assert Ok(red) = color.from_hex("#e74c3c")
////
//// // Build a gauge node in your view
//// gauge.gauge("temp", 42.0, [
////   gauge.color(red),
////   gauge.label("42C"),
////   gauge.min(0.0),
////   gauge.max(100.0),
////   gauge.width(Fixed(200.0)),
////   gauge.height(Fixed(200.0)),
//// ])
////
//// // Send commands from update
//// gauge.set_value("temp", 90.0)
//// gauge.animate_to("temp", 75.0)
//// ```

import gleam/list
import gleam/result
import plushie/command.{type Command}
import plushie/native_widget
import plushie/node.{type Node, FloatVal, StringVal}
import plushie/prop/color.{type Color}
import plushie/prop/length.{type Length}

/// Extension definition for the gauge widget.
///
/// Declares 7 typed props and 2 commands that map to the Rust crate's
/// `WidgetExtension` implementation in `native/gauge/src/lib.rs`.
pub const def = native_widget.NativeDef(
  kind: "gauge",
  rust_crate: "native/gauge",
  rust_constructor: "gauge::GaugeExtension::new()",
  props: [
    native_widget.NumberProp("value"),
    native_widget.NumberProp("min"),
    native_widget.NumberProp("max"),
    native_widget.ColorProp("color"),
    native_widget.StringProp("label"),
    native_widget.LengthProp("width"),
    native_widget.LengthProp("height"),
  ],
  commands: [
    native_widget.CommandDef("set_value", [native_widget.NumberParam("value")]),
    native_widget.CommandDef("animate_to", [native_widget.NumberParam("value")]),
  ],
)

// -- Attribute type ----------------------------------------------------------

/// Attribute for configuring a gauge widget.
///
/// Pass these to `gauge()` to override defaults. Unspecified attributes
/// use sensible defaults (min=0, max=100, 200x200px, no label, blue).
pub type GaugeAttr {
  Min(Float)
  Max(Float)
  GaugeColor(Color)
  Label(String)
  GaugeWidth(Length)
  GaugeHeight(Length)
}

// -- Attribute constructors --------------------------------------------------

/// Set the minimum value (default: 0.0).
pub fn min(value: Float) -> GaugeAttr {
  Min(value)
}

/// Set the maximum value (default: 100.0).
pub fn max(value: Float) -> GaugeAttr {
  Max(value)
}

/// Set the gauge colour.
pub fn color(c: Color) -> GaugeAttr {
  GaugeColor(c)
}

/// Set the centre label text (default: empty).
pub fn label(text: String) -> GaugeAttr {
  Label(text)
}

/// Set the gauge width (default: Fixed(200.0)).
pub fn width(w: Length) -> GaugeAttr {
  GaugeWidth(w)
}

/// Set the gauge height (default: Fixed(200.0)).
pub fn height(h: Length) -> GaugeAttr {
  GaugeHeight(h)
}

// -- Builder -----------------------------------------------------------------

/// Default colour for the gauge (#3498db, a calm blue).
const default_color_hex = "#3498db"

/// Build a gauge widget node.
///
/// `id` and `value` are required. All other properties can be set via
/// `GaugeAttr` values, with sensible defaults if omitted.
pub fn gauge(id: String, value: Float, attrs: List(GaugeAttr)) -> Node {
  let assert Ok(default_color) = color.from_hex(default_color_hex)

  native_widget.build(def, id, [
    #("value", FloatVal(value)),
    #("min", FloatVal(resolve(attrs, extract_min, 0.0))),
    #("max", FloatVal(resolve(attrs, extract_max, 100.0))),
    #(
      "color",
      color.to_prop_value(resolve(attrs, extract_color, default_color)),
    ),
    #("label", StringVal(resolve(attrs, extract_label, ""))),
    #(
      "width",
      length.to_prop_value(resolve(attrs, extract_width, length.Fixed(200.0))),
    ),
    #(
      "height",
      length.to_prop_value(resolve(attrs, extract_height, length.Fixed(200.0))),
    ),
  ])
}

// -- Commands ----------------------------------------------------------------

/// Send a set_value command to a gauge widget.
///
/// Updates the Rust-side value immediately. Used for discrete changes
/// (button clicks) where the new value is known.
pub fn set_value(node_id: String, value: Float) -> Command(msg) {
  native_widget.command(def, node_id, "set_value", [
    #("value", FloatVal(value)),
  ])
}

/// Send an animate_to command to a gauge widget.
///
/// Tells the Rust side to transition toward a target value. Used for
/// continuous changes (slider drags) where the value may keep changing.
pub fn animate_to(node_id: String, value: Float) -> Command(msg) {
  native_widget.command(def, node_id, "animate_to", [
    #("value", FloatVal(value)),
  ])
}

// -- Attr resolution ---------------------------------------------------------

/// Extract the first matching value from an attr list, or use a default.
fn resolve(
  attrs: List(GaugeAttr),
  extract: fn(GaugeAttr) -> Result(a, Nil),
  default: a,
) -> a {
  attrs
  |> list.find_map(extract)
  |> result.unwrap(default)
}

fn extract_min(attr: GaugeAttr) -> Result(Float, Nil) {
  case attr {
    Min(v) -> Ok(v)
    _ -> Error(Nil)
  }
}

fn extract_max(attr: GaugeAttr) -> Result(Float, Nil) {
  case attr {
    Max(v) -> Ok(v)
    _ -> Error(Nil)
  }
}

fn extract_color(attr: GaugeAttr) -> Result(Color, Nil) {
  case attr {
    GaugeColor(c) -> Ok(c)
    _ -> Error(Nil)
  }
}

fn extract_label(attr: GaugeAttr) -> Result(String, Nil) {
  case attr {
    Label(s) -> Ok(s)
    _ -> Error(Nil)
  }
}

fn extract_width(attr: GaugeAttr) -> Result(Length, Nil) {
  case attr {
    GaugeWidth(l) -> Ok(l)
    _ -> Error(Nil)
  }
}

fn extract_height(attr: GaugeAttr) -> Result(Length, Nil) {
  case attr {
    GaugeHeight(l) -> Ok(l)
    _ -> Error(Nil)
  }
}
