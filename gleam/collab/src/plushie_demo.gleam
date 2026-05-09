//// Collaborative scratchpad demo entry point.
////
//// Mode 3: native desktop app started from Gleam.
//// Gleam spawns the plushie renderer as a child process, which opens
//// a native window and communicates over stdin/stdout.

import demo/collab
import plushie

pub fn main() {
  let assert Ok(rt) = plushie.start(collab.app(), plushie.default_start_opts())
  plushie.wait(rt)
}
