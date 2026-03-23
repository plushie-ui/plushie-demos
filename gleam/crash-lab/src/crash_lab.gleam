//// Crash lab entry point.
////
//// Error resilience demonstration showing Rust panic isolation
//// and Gleam crash recovery. Uses a custom binary with the
//// crash_widget extension.

import crash_lab/app
import gleam/io
import plushie

pub fn main() {
  case plushie.start(app.app(), plushie.default_start_opts()) {
    Ok(rt) -> plushie.wait(rt)
    Error(err) ->
      io.println_error(
        "Failed to start: " <> plushie.start_error_to_string(err),
      )
  }
}
