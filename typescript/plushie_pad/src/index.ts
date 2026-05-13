/**
 * Plushie Pad entry point.
 *
 * Kicks off the app. The launcher script in `bin/plushie-pad.js`
 * just invokes this file via `tsx`.
 */

import { padApp } from "./app.js"

if (process.env["VITEST"] !== "true") {
  void padApp.run()
}
