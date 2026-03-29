# frozen_string_literal: true

require "plushie"

# Gauge custom widget -- renders a numeric gauge with label and color.
#
# Demonstrates widget commands and Rust-side state management via
# ExtensionCaches. The Ruby side sends set_value and animate_to commands;
# the Rust side tracks state between command receipt and next render.
class GaugeExtension
  include Plushie::Widget

  widget :gauge, kind: :native_widget

  rust_crate "native/gauge"
  rust_constructor "gauge::GaugeExtension::new()"

  prop :value, :number, default: 0
  prop :min, :number, default: 0
  prop :max, :number, default: 100
  prop :color, :color, default: "#3498db"
  prop :label, :string, default: ""
  prop :width, :length, default: 200
  prop :height, :length, default: 200

  command :set_value, value: :number
  command :animate_to, value: :number
end
