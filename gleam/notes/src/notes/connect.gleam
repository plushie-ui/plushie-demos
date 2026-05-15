//// Standalone entry point for the notes app.
////
//// Uses `PLUSHIE_SOCKET` when started by a renderer-first launcher.
//// Otherwise starts the packaged renderer through normal SDK binary
//// resolution, including `PLUSHIE_BINARY_PATH`.

import notes/app
import plushie/connect

pub fn main() {
  connect.run(app.app(), connect.default_opts())
}
