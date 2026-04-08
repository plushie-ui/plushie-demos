defmodule GaugeDemo.GaugeExtension do
  @moduledoc """
  Gauge native widget - renders a numeric gauge with label and color.

  Defines a native Rust widget with typed props and two commands.
  The Rust side (`native/gauge/src/lib.rs`) implements
  `WidgetExtension` to render the gauge and handle commands.

  ## Props

  - `value` - current gauge value (number)
  - `min` / `max` - value range (number, defaults 0 / 100)
  - `color` - arc/fill color
  - `label` - center label text
  - `width` / `height` - widget dimensions (length)

  ## Commands

  - `set_value(widget_id, value)` - set gauge to a value immediately;
    the Rust side confirms by emitting a `value_changed` event
  - `animate_to(widget_id, value)` - animate gauge toward a target
    value; no confirmation event
  """

  use Plushie.Widget, :native_widget

  widget(:gauge)

  rust_crate("native/gauge")
  rust_constructor("gauge::GaugeExtension::new()")

  field(:value, :number)
  field(:min, :number, default: 0)
  field(:max, :number, default: 100)
  field(:color, :color, default: "#3498db")
  field(:label, :string, default: "")
  field(:width, :length)
  field(:height, :length)
    field :event_rate, :integer, doc: "Max events per second."
    field :a11y, Plushie.Type.A11y, doc: "Accessibility annotations."
  event(:value_changed, data: [value: :number])

  command(:set_value, value: :number)
  command(:animate_to, value: :number)
end
