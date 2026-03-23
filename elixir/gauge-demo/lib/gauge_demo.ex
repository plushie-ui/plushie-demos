defmodule GaugeDemo do
  @moduledoc """
  Temperature gauge demo -- native Rust widget extension for Plushie.

  This project demonstrates how to build a native Rust extension widget
  and use it from an Elixir Plushie app. The two main modules are:

  - `GaugeDemo.GaugeExtension` -- extension definition (props, commands,
    Rust crate references). The macro generates the struct, setters,
    Widget protocol implementation, and command functions.

  - `GaugeDemo.TemperatureMonitor` -- Plushie app module implementing
    init/update/view/settings. Demonstrates the optimistic update
    pattern: `target_temp` updates immediately while `temperature`
    waits for Rust confirmation via `value_changed` events.

  ## Running

      mix plushie.gui GaugeDemo.TemperatureMonitor

  Requires a custom binary built with `mix plushie.build` that includes
  the gauge Rust extension. See the README for full setup instructions.
  """
end
