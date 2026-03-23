import { defineConfig } from "vitest/config"

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
