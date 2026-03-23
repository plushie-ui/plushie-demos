//// Sparkline dashboard entry point.
////
//// Live system monitor with three sparkline charts for CPU, memory,
//// and network metrics. Demonstrates a render-only Rust canvas
//// extension, timer subscriptions, and simulated live data.

import gleam/io
import plushie
import plushie/app as plushie_app
import sparkline_dashboard/app

pub fn main() {
  let application =
    plushie_app.simple(app.init, app.update, app.view)
    |> plushie_app.with_subscriptions(app.subscribe)

  case plushie.start(application, plushie.default_start_opts()) {
    Ok(rt) -> plushie.wait(rt)
    Error(err) ->
      io.println_error(
        "Failed to start: " <> plushie.start_error_to_string(err),
      )
  }
}
