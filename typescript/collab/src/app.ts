/**
 * Desktop entry point for the collaborative scratchpad app.
 */

import { app } from "plushie"
import { init, view } from "./collab.js"
import type { Model } from "./collab.js"

const collabApp = app<Model>({
  init: init(),
  update: (model) => model as Model,
  settings: { defaultEventRate: 30 },
  view,
})

export default collabApp

if (process.env["VITEST"] !== "true") {
  void collabApp.run()
}
