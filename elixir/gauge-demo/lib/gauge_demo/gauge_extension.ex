defmodule GaugeDemo.GaugeExtension do
  @moduledoc """
  Gauge widget extension -- renders a numeric gauge with label and color.

  Defines a native Rust extension widget with typed props and two
  commands. The Rust side (`native/gauge/src/lib.rs`) implements
  `WidgetExtension` to render the gauge and handle commands.

  ## Props

  - `value` -- current gauge value (number)
  - `min` / `max` -- value range (number, defaults 0 / 100)
  - `color` -- arc/fill color
  - `label` -- center label text
  - `width` / `height` -- widget dimensions (length)

  ## Commands

  - `set_value(widget_id, value)` -- set gauge to a value immediately;
    the Rust side confirms by emitting a `value_changed` event
  - `animate_to(widget_id, value)` -- animate gauge toward a target
    value; no confirmation event
  """

  use Plushie.Extension, :native_widget

  widget(:gauge)

  rust_crate("native/gauge")
  rust_constructor("gauge::GaugeExtension::new()")

  prop(:value, :number)
  prop(:min, :number, default: 0)
  prop(:max, :number, default: 100)
  prop(:color, :color, default: "#3498db")
  prop(:label, :string, default: "")
  prop(:width, :length)
  prop(:height, :length)

  command(:set_value, value: :number)
  command(:animate_to, value: :number)
end
