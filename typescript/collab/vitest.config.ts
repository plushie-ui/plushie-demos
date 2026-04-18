import { defineConfig } from "vitest/config"
import { resolve } from "node:path"

// Point tests at the locally-built plushie-renderer.
process.env["PLUSHIE_BINARY_PATH"] ??= resolve(
  __dirname,
  "../../../plushie-rust/target/release/plushie-renderer",
)

export default defineConfig({
  oxc: {
    jsx: "automatic",
    jsxImportSource: "plushie",
  },
  test: {
    testTimeout: 15000,
    hookTimeout: 15000,
  },
})
