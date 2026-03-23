# frozen_string_literal: true

require "plushie"

# Sparkline widget extension -- renders a line chart from sample data.
#
# Follows the Plushie extensions guide worked example. The Ruby side
# declares the widget type, props, and commands. The Rust side (in
# native/sparkline/) handles the canvas rendering.
class SparklineExtension
  include Plushie::Extension

  widget :sparkline, kind: :native_widget

  rust_crate "native/sparkline"
  rust_constructor "sparkline::SparklineExtension::new()"

  prop :data, :any, default: []
  prop :color, :color, default: "#4CAF50"
  prop :stroke_width, :number, default: 2.0
  prop :fill, :boolean, default: false
  prop :height, :number, default: 60.0
end
