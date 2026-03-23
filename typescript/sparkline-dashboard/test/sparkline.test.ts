/**
 * Unit tests for the sparkline extension definition.
 *
 * These verify the TypeScript side of the extension: widget builders
 * produce correct UINode shapes, config matches what
 * plushie.extensions.json expects.
 *
 * No binary needed -- pure TypeScript logic.
 */

import { describe, expect, test } from "vitest"
import { Sparkline, sparklineConfig } from "../src/sparkline.js"

describe("sparklineConfig", () => {
  test("has the correct type name", () => {
    expect(sparklineConfig.type).toBe("sparkline")
  })

  test("declares all expected props", () => {
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
})

describe("Sparkline widget builder", () => {
  test("produces a UINode with correct type", () => {
    const node = Sparkline("my-spark", { data: [1, 2, 3] })
    expect(node.type).toBe("sparkline")
    expect(node.id).toBe("my-spark")
  })

  test("passes props to the node", () => {
    const node = Sparkline("s1", {
      data: [10, 20, 30],
      color: "#ff0000",
      stroke_width: 3.0,
      fill: true,
      height: 80.0,
    })
    expect(node.props["data"]).toEqual([10, 20, 30])
    expect(node.props["color"]).toBe("#ff0000")
    expect(node.props["stroke_width"]).toBe(3.0)
    expect(node.props["fill"]).toBe(true)
    expect(node.props["height"]).toBe(80.0)
  })

  test("auto-generates an ID when given empty string", () => {
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
