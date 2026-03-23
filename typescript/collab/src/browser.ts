/**
 * Browser entry point for client-side WASM mode.
 *
 * This module is bundled by esbuild for browser use. The standalone
 * HTML page loads the WASM renderer and this bundle to run the collab
 * app entirely in the browser.
 *
 * NOTE: Client-side WASM requires the SDK's Runtime to be
 * browser-compatible. The standalone.html shows the pattern; full
 * Runtime-in-browser support is tracked in the SDK.
 */

export { init, update, view } from "./collab.js"
export type { Model } from "./collab.js"
