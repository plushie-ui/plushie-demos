//// Mode 4: Stdio transport for reverse startup.
////
//// The plushie renderer binary spawns this Gleam process via --exec
//// and communicates over its stdin/stdout. This is the reverse of
//// mode 3: the renderer drives the lifecycle instead of Gleam.
////
//// Run: ./bin/native_rust.sh
////   (which runs: plushie --exec "gleam run -m demo/stdio")

import gleam/erlang/process
import plushie
import demo/collab

pub fn main() {
  let opts =
    plushie.StartOpts(..plushie.default_start_opts(), transport: plushie.Stdio)
  let _ = plushie.start(collab.app(), opts)
  process.sleep_forever()
}
