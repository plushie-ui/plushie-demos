//// Notes app entry point.
////
//// A note-taking app demonstrating custom message types, multi-view
//// routing, undo/redo, search filtering, and keyboard shortcuts.
//// No Rust extension needed -- runs with the stock plushie binary.

import gleam/io
import notes/app
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
