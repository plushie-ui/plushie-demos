# frozen_string_literal: true

require "plushie"
require_relative "gauge_extension"

Plushie.configure do |config|
  config.widgets = [GaugeExtension]
  config.widget_config = {
    "gauge" => {"arc_width" => 8, "tick_count" => 10}
  }
end

# Temperature monitor using a native Rust gauge widget.
#
# Demonstrates widget commands and widget events: button
# handlers send set_value commands to the Rust widget, which
# confirms the change by emitting a value_changed event back.
# The app updates temperature and history only when the widget
# confirms.
#
# The slider sends animate_to (target only, no confirmation).
class TemperatureMonitor
  include Plushie::App

  Model = Plushie::Model.define(
    :temperature,
    :target_temp,
    :history
  )

  MAX_HISTORY = 50

  def init(_opts)
    Model.new(temperature: 20.0, target_temp: 20.0, history: [20.0])
  end

  def update(model, event)
    case event
    # Widget event: Rust confirms value change
    in Event::Widget[type: :value_changed, id: "temp", data:]
      new_temp = data["value"].to_f
      model.with(
        temperature: new_temp,
        history: append_history(model.history, new_temp)
      )

    # Slider: update target only, send animate_to (no confirmation)
    in Event::Widget[type: :slide, id: "target", value:]
      target = value
      [
        model.with(target_temp: target),
        Command.widget_command("temp", "animate_to", {value: target})
      ]

    # Reset: update target, send set_value (Rust confirms via value_changed)
    in Event::Widget[type: :click, id: "reset"]
      [
        model.with(target_temp: 20.0),
        Command.widget_command("temp", "set_value", {value: 20.0})
      ]

    # High: update target, send set_value (Rust confirms via value_changed)
    in Event::Widget[type: :click, id: "high"]
      [
        model.with(target_temp: 90.0),
        Command.widget_command("temp", "set_value", {value: 90.0})
      ]

    else
      model
    end
  end

  def view(model)
    color = status_color(model.temperature)
    status = temperature_status(model.temperature)

    window("main", title: "Temperature Gauge") do
      column("root", padding: 24, spacing: 16, align_x: "center") do
        text("title", "Temperature Monitor", size: 24)

        _plushie_leaf("gauge", "temp",
          value: model.temperature,
          min: 0, max: 100,
          color: color,
          label: "#{model.temperature.round}\u00B0C",
          width: 200, height: 200)

        text("status", "Status: #{status}", color: color)

        text("reading",
          "Current: #{model.temperature.round}\u00B0C | " \
          "Target: #{model.target_temp.round}\u00B0C")

        slider("target", [0, 100], model.target_temp)

        row("buttons", spacing: 8) do
          button("reset", "Reset (20\u00B0C)")
          button("high", "High (90\u00B0C)")
        end

        text("history",
          "History: #{model.history.map { |t| "#{t.round}\u00B0" }.join(", ")}",
          size: 12, color: "#999999")
      end
    end
  end

  private

  def temperature_status(temp)
    if temp >= 80 then "Critical"
    elsif temp >= 60 then "Warning"
    elsif temp >= 40 then "Normal"
    else "Cool"
    end
  end

  def status_color(temp)
    if temp >= 80 then "#e74c3c"
    elsif temp >= 60 then "#e67e22"
    elsif temp >= 40 then "#27ae60"
    else "#3498db"
    end
  end

  def append_history(history, value)
    (history + [value]).last(MAX_HISTORY)
  end
end
