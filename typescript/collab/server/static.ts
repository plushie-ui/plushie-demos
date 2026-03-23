/**
 * Mode 1: Static file server for client-side WASM.
 *
 * Serves the bundled app and WASM files. Each browser tab runs
 * independently -- no shared state, no server-side app logic.
 *
 * Prerequisites:
 *   pnpm build:browser     (bundles app for the browser)
 *   Copy plushie_renderer_wasm.js and plushie_renderer_wasm_bg.wasm into static/
 *
 * Usage:
 *   npx tsx server/static.ts
 *   open http://localhost:8080/standalone.html
 */

import { createServer } from "node:http"
import { serveStatic } from "./static-files.js"

const PORT = 8080

const server = createServer((req, res) => {
  serveStatic(req, res)
})

server.listen(PORT, "127.0.0.1", () => {
  console.log(`Static server:  http://127.0.0.1:${PORT}`)
  console.log(`Standalone app: http://127.0.0.1:${PORT}/standalone.html`)
})
