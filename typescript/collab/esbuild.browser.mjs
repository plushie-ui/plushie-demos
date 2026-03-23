/**
 * Bundle the collab app for browser use (mode 1: client-side WASM).
 *
 * Output: static/collab-bundle.js
 */

import { build } from "esbuild"

await build({
  entryPoints: ["src/browser.ts"],
  bundle: true,
  format: "esm",
  outfile: "static/collab-bundle.js",
  platform: "browser",
  target: "es2022",
  jsx: "automatic",
  jsxImportSource: "plushie",
  external: [],
  // Tree-shake Node.js-only code paths
  define: {
    "process.env.NODE_ENV": '"production"',
  },
})

console.log("Built static/collab-bundle.js")
