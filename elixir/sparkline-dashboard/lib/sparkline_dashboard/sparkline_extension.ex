defmodule SparklineDashboard.SparklineExtension do
  @moduledoc """
  Sparkline widget extension -- renders a line chart from sample data.

  Defines a render-only native Rust extension widget. The Rust side
  (`native/sparkline/src/lib.rs`) implements `WidgetExtension` with
  canvas-based rendering via iced's `canvas::Program` trait.

  No commands or events -- data flows in through props, rendered
  pixels flow out. This is the simplest extension pattern (Tier A).

  ## Props

  - `data` -- sample values to plot (list of numbers)
  - `color` -- line/fill color (default `"#4CAF50"`)
  - `stroke_width` -- line thickness in pixels (number, default 2.0)
  - `fill` -- whether to fill the area under the line (boolean, default false)
  - `height` -- widget height in pixels (number, default 60.0)
  """

  use Plushie.Extension, :native_widget

  widget(:sparkline)

  rust_crate("native/sparkline")
  rust_constructor("sparkline::SparklineExtension::new()")

  prop(:data, {:list, :number}, default: [])
  prop(:color, :color, default: "#4CAF50")
  prop(:stroke_width, :number, default: 2.0)
  prop(:fill, :boolean, default: false)
  prop(:height, :number, default: 60.0)
end
