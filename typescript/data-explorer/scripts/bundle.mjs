/**
 * Bundle the data explorer for SEA packaging.
 *
 * Produces a single CJS file at dist/app.cjs that can be embedded
 * in a Node.js Single Executable Application.
 */

import { build } from "esbuild"

await build({
  entryPoints: ["src/app.tsx"],
  bundle: true,
  format: "cjs",
  outfile: "dist/app.cjs",
  platform: "node",
  target: "node20",
  jsx: "automatic",
  jsxImportSource: "plushie",
  // Inline all dependencies (plushie SDK + countries data)
  packages: "bundle",
})

console.log("Built dist/app.cjs")
