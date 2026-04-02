defmodule SparklineDashboard do
  @moduledoc """
  Live system monitor demo - native Rust sparkline widget for Plushie.

  This project demonstrates how to build a render-only native Rust
  extension widget and drive it with timer subscriptions. The two
  main modules are:

  - `SparklineDashboard.SparklineExtension` - native widget definition
    (props only, no commands or events). The macro generates the struct,
    setters, Widget protocol implementation, and Buildable callbacks.

  - `SparklineDashboard.Dashboard` - Plushie app module implementing
    init/update/view/subscribe. Uses `Plushie.Subscription.every/2`
    to generate simulated metrics every 500ms, with pause/resume
    and clear controls.

  ## Running

      mix plushie.gui SparklineDashboard.Dashboard

  Requires a custom binary built with `mix plushie.build` that includes
  the sparkline Rust extension. See the README for full setup instructions.
  """
end
