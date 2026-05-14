//// Renderer-parent entry point for the gauge demo package.

import gauge_demo/app
import plushie/app as plushie_app
import plushie/connect

pub fn main() {
  let application = plushie_app.simple(app.init, app.update, app.view)
  connect.run(application, connect.default_opts())
}
