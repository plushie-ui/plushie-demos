//// Plushie Pad entry point.
////
//// Runs the pad against the local renderer binary. The pad lets you
//// type Erlang source, compile it at runtime via the BEAM's standard
//// compiler, and preview the rendered widget tree. See the guides for
//// a full walkthrough.

import gleam/io
import plushie
import plushie_pad/app as pad_app

pub fn main() {
  case plushie.start(pad_app.app(), plushie.default_start_opts()) {
    Ok(rt) -> plushie.wait(rt)
    Error(err) ->
      io.println_error(
        "plushie_pad failed to start: " <> plushie.start_error_to_string(err),
      )
  }
}
