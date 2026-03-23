/**
 * Unit tests for the sparkline extension definition.
 *
 * Verifies the TypeScript side produces correct widget nodes and
 * config metadata.
 *
 * No binary needed.
 */

import { describe, expect, test } from "vitest"
import { Sparkline, sparklineConfig } from "../src/sparkline.js"

describe("sparklineConfig", () => {
  test("type is sparkline", () => {
    expect(sparklineConfig.type).toBe("sparkline")
  })

  test("declares all props with correct types", () => {
    expect(sparklineConfig.props).toEqual({
      data: { list: "number" },
      color: "color",
      stroke_width: "number",
      fill: "boolean",
      height: "number",
    })
  })

  test("points to the Rust crate", () => {
    expect(sparklineConfig.rustCrate).toBe("native/sparkline")
    expect(sparklineConfig.rustConstructor).toBe(
      "sparkline::SparklineExtension::new()",
    )
  })

  test("has no declared commands (render-only extension)", () => {
    expect(sparklineConfig.commands).toBeUndefined()
  })

  test("has no declared events", () => {
    expect(sparklineConfig.events).toBeUndefined()
  })

  test("is not a container", () => {
    expect(sparklineConfig.container).toBeUndefined()
  })
})

describe("Sparkline widget builder", () => {
  test("produces node with correct type and id", () => {
    const node = Sparkline("s1", { data: [1, 2, 3] })
    expect(node.type).toBe("sparkline")
    expect(node.id).toBe("s1")
  })

  test("passes data array as prop", () => {
    const node = Sparkline("s1", { data: [10, 20, 30] })
    expect(node.props["data"]).toEqual([10, 20, 30])
  })

  test("passes all declared props", () => {
    const node = Sparkline("s1", {
      data: [1, 2],
      color: "#FF0000",
      stroke_width: 3.0,
      fill: true,
      height: 80.0,
    })
    expect(node.props["color"]).toBe("#FF0000")
    expect(node.props["stroke_width"]).toBe(3.0)
    expect(node.props["fill"]).toBe(true)
    expect(node.props["height"]).toBe(80.0)
  })

  test("omits undefined props from wire output", () => {
    const node = Sparkline("s1", {})
    expect(Object.keys(node.props)).toEqual([])
  })

  test("empty data array passes through", () => {
    const node = Sparkline("s1", { data: [] })
    expect(node.props["data"]).toEqual([])
  })

  test("auto-generates ID for empty string", () => {
    const node = Sparkline("", { data: [] })
    expect(node.id).toMatch(/^auto:/)
  })

  test("is a leaf widget (no children)", () => {
    const node = Sparkline("s1", { data: [] })
    expect(node.children).toEqual([])
  })

  test("returns a frozen object", () => {
    const node = Sparkline("s1", { data: [] })
    expect(Object.isFrozen(node)).toBe(true)
  })
})
