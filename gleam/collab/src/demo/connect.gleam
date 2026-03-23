//// Mode 4: Socket transport for reverse startup.
////
//// The plushie renderer binary creates a Unix socket via `--listen`,
//// then spawns this Gleam process via `--exec`. The process connects
//// back to the renderer over the socket. This is the socket-based
//// equivalent of the stdio mode.
////
//// Run: ./bin/native_rust.sh
////   (which runs: plushie --listen --exec "gleam run -m demo/connect")

import demo/collab
import plushie/connect

pub fn main() {
  connect.run(collab.app(), connect.default_opts())
}
