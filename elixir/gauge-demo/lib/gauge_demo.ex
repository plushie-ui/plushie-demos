defmodule GaugeDemo do
  @moduledoc """
  Temperature gauge demo - native Rust widget for Plushie.

  This project demonstrates how to build a native Rust widget and use
  it from an Elixir Plushie app. The two main modules are:

  - `GaugeDemo.GaugeExtension` - widget definition (props, commands,
    Rust crate references). The macro generates the struct, setters,
    Widget protocol implementation, and command functions.

  - `GaugeDemo.TemperatureMonitor` - Plushie app module implementing
    init/update/view/settings. Demonstrates the optimistic update
    pattern: `target_temp` updates immediately while `temperature`
    waits for Rust confirmation via `{:gauge, :value_changed}` events.

  ## Running

      mix plushie.gui GaugeDemo.TemperatureMonitor

  Requires a custom binary built with `mix plushie.build` that includes
  the gauge native widget. See the README for full setup instructions.
  """
end
