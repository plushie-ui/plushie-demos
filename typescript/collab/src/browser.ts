/**
 * Browser entry point for client-side WASM mode.
 *
 * Bundled by esbuild and loaded by standalone.html. Creates a
 * WasmTransport and runs the collab app entirely in the browser --
 * no server-side app logic.
 */

import { init, view } from "./collab.js"
import type { Model } from "./collab.js"

// Re-export for the HTML page to call after loading WASM
export { init, view }
export type { Model }
