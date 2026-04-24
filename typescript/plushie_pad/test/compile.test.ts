import { describe, expect, test } from "vitest"

import { compileAndRender } from "../src/compile.js"

describe("compileAndRender", () => {
  test("returns ok with a UINode for valid source", () => {
    const source = `ui.text("hello", { id: "t" })`
    const result = compileAndRender(source)
    expect(result.ok).toBe(true)
    if (result.ok) {
      expect(result.node.type).toBe("text")
      expect(result.node.id).toBe("t")
    }
  })

  test("reports a message for a syntax error", () => {
    const result = compileAndRender(`ui.text(`)
    expect(result.ok).toBe(false)
    if (!result.ok) {
      expect(result.message.length).toBeGreaterThan(0)
    }
  })

  test("reports a message when the expression is not a node", () => {
    const result = compileAndRender(`42`)
    expect(result.ok).toBe(false)
    if (!result.ok) {
      expect(result.message).toContain("UINode")
    }
  })

  test("reports the inner error when a referenced binding is missing", () => {
    const result = compileAndRender(`unknownBinding()`)
    expect(result.ok).toBe(false)
    if (!result.ok) {
      expect(result.message.length).toBeGreaterThan(0)
    }
  })
})
