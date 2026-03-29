# frozen_string_literal: true

require "plushie"
require_relative "sparkline_extension"

# Register the widget for custom builds.
Plushie.configure do |config|
  config.widgets = [SparklineExtension]
end

# Live dashboard with sparkline charts for simulated system metrics.
class Dashboard
  include Plushie::App

  Model = Plushie::Model.define(
    :cpu_samples,
    :mem_samples,
    :net_samples,
    :running,
    :tick_count
  )

  MAX_SAMPLES = 100

  def init(_opts)
    Model.new(
      cpu_samples: [],
      mem_samples: [],
      net_samples: [],
      running: true,
      tick_count: 0
    )
  end

  def update(model, event)
    case event
    in Event::Timer[tag: :sample] if model.running
      cpu = rand(30..69) + Math.sin(model.tick_count * 0.1) * 15
      mem = rand(40..49) + (model.tick_count * 0.05)
      mem = mem % 80 + 20 # oscillate between 20-100
      net = rand(100)

      model.with(
        cpu_samples: (model.cpu_samples + [cpu.round(1)]).last(MAX_SAMPLES),
        mem_samples: (model.mem_samples + [mem.round(1)]).last(MAX_SAMPLES),
        net_samples: (model.net_samples + [net.round(1)]).last(MAX_SAMPLES),
        tick_count: model.tick_count + 1
      )

    in Event::Widget[type: :click, id: "toggle_running"]
      model.with(running: !model.running)

    in Event::Widget[type: :click, id: "clear"]
      model.with(
        cpu_samples: [],
        mem_samples: [],
        net_samples: [],
        tick_count: 0
      )

    else
      model
    end
  end

  def subscribe(model)
    subs = []
    subs << Subscription.every(500, :sample) if model.running
    subs
  end

  def view(model)
    window("main", title: "Sparkline Dashboard") do
      column("root", padding: 20, spacing: 16) do
        text("title", "System Monitor", size: 24)

        # Controls
        row("controls", spacing: 12) do
          button("toggle_running", model.running ? "Pause" : "Resume")
          button("clear", "Clear")
          text("status", "#{model.cpu_samples.length} samples",
            size: 14, color: "#888888")
        end

        # Sparkline charts
        sparkline_card("cpu", "CPU Usage", model.cpu_samples,
          color: "#4CAF50", fill: true)
        sparkline_card("mem", "Memory", model.mem_samples,
          color: "#2196F3", fill: true)
        sparkline_card("net", "Network I/O", model.net_samples,
          color: "#FF9800", fill: false)
      end
    end
  end

  private

  def sparkline_card(id, label, data, color:, fill:)
    container("#{id}_card", padding: 12) do
      column("#{id}_content", spacing: 4) do
        row("#{id}_header", spacing: 8) do
          text("#{id}_label", label, size: 14, color: "#666666")
          if data.any?
            text("#{id}_value", data.last.to_s,
              size: 14, color: color)
          end
        end

        # Insert sparkline extension widget
        _plushie_leaf("sparkline", "#{id}_spark",
          data: data, color: color, stroke_width: 2.0,
          fill: fill, height: 60.0)
      end
    end
  end
end
