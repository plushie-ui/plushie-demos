//// Gauge demo entry point.
////
//// Temperature monitor with a native Rust gauge extension widget.
//// Demonstrates extension commands, optimistic updates, and the
//// extension build workflow.

import gauge_demo/app
import gleam/io
import plushie
import plushie/app as plushie_app

pub fn main() {
  let application = plushie_app.simple(app.init, app.update, app.view)

  case plushie.start(application, plushie.default_start_opts()) {
    Ok(rt) -> plushie.wait(rt)
    Error(err) ->
      io.println_error(
        "Failed to start: " <> plushie.start_error_to_string(err),
      )
  }
}
