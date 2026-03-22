//// Mode 3: Native desktop app started from Gleam.
////
//// The standard way to run a Plushie app. Gleam spawns the plushie
//// renderer binary as a child process via an Erlang Port. The binary
//// opens a native window and communicates over the port's stdin/stdout.
////
//// Run: ./bin/native_gleam.sh

import gleam/erlang/process
import plushie
import demo/collab

pub fn main() {
  let _ = plushie.start(collab.app(), plushie.default_start_opts())
  process.sleep_forever()
}
