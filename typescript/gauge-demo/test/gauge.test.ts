/**
 * Unit tests for the gauge native widget definition and builder functions.
 *
 * Verifies the TypeScript side: widget builders produce correct UINode
 * shapes, command constructors return proper Command objects, and the
 * config matches what plushie.extensions.json expects.
 *
 * No binary needed -- pure TypeScript logic.
 */

import { describe, expect, test } from "vitest"
import { Gauge, GaugeCmds, gaugeConfig } from "../src/gauge.js"

// -- Config -----------------------------------------------------------------

describe("gaugeConfig", () => {
  test("type is gauge", () => {
    expect(gaugeConfig.type).toBe("gauge")
  })

  test("declares all props with correct types", () => {
    expect(gaugeConfig.props).toEqual({
      value: "number",
      min: "number",
      max: "number",
      color: "color",
      label: "string",
      width: "length",
      height: "length",
    })
  })

  test("declares value_changed event", () => {
    expect(gaugeConfig.events).toEqual(["value_changed"])
  })

  test("declares widget commands", () => {
    expect(gaugeConfig.commands).toEqual(["set_value", "animate_to"])
  })

  test("points to the Rust crate", () => {
    expect(gaugeConfig.rustCrate).toBe("native/gauge")
    expect(gaugeConfig.rustConstructor).toBe("gauge::GaugeExtension::new()")
  })
})

// -- Widget builder ---------------------------------------------------------

describe("Gauge widget builder", () => {
  test("produces node with correct type and id", () => {
    const node = Gauge("my-gauge", { value: 50 })
    expect(node.type).toBe("gauge")
    expect(node.id).toBe("my-gauge")
  })

  test("passes all props to the node", () => {
    const node = Gauge("g1", {
      value: 72,
      min: 0,
      max: 100,
      color: "#ff0000",
      label: "72%",
    })
    expect(node.props["value"]).toBe(72)
    expect(node.props["min"]).toBe(0)
    expect(node.props["max"]).toBe(100)
    expect(node.props["color"]).toBe("#ff0000")
    expect(node.props["label"]).toBe("72%")
  })

  test("auto-generates ID for empty string", () => {
    const node = Gauge("", { value: 0 })
    expect(node.id).toMatch(/^auto:/)
  })

  test("is a leaf widget (no children)", () => {
    const node = Gauge("g1", { value: 0 })
    expect(node.children).toEqual([])
  })

  test("returns a frozen object", () => {
    const node = Gauge("g1", { value: 0 })
    expect(Object.isFrozen(node)).toBe(true)
  })

  test("node has only structural keys", () => {
    const node = Gauge("g1", { value: 0 })
    expect(Object.keys(node).sort()).toEqual(
      ["children", "id", "props", "type"].sort(),
    )
  })

  test("strips handler props from wire output", () => {
    const node = Gauge("g1", {
      value: 50,
      onValueChanged: () => ({}),
    })
    // Handler registered internally, not on the wire
    expect(node.props["onValueChanged"]).toBeUndefined()
    expect(node.props["value"]).toBe(50)
  })
})

// -- Commands ---------------------------------------------------------------

describe("GaugeCmds", () => {
  test("set_value produces an extension_command", () => {
    const cmd = GaugeCmds.set_value("g1", { value: 42 })
    expect(cmd.type).toBe("extension_command")
    expect(cmd.payload).toEqual({
      node_id: "g1",
      op: "set_value",
      payload: { value: 42 },
    })
  })

  test("animate_to produces an extension_command", () => {
    const cmd = GaugeCmds.animate_to("g1", { value: 90 })
    expect(cmd.type).toBe("extension_command")
    expect(cmd.payload).toEqual({
      node_id: "g1",
      op: "animate_to",
      payload: { value: 90 },
    })
  })

  test("commands carry the COMMAND symbol", () => {
    const cmd = GaugeCmds.set_value("g1", { value: 0 })
    const COMMAND = Symbol.for("plushie.command")
    expect((cmd as Record<symbol, unknown>)[COMMAND]).toBe(true)
  })

  test("commands are frozen", () => {
    const cmd = GaugeCmds.animate_to("g1", { value: 50 })
    expect(Object.isFrozen(cmd)).toBe(true)
  })

  test("payload has standard three-key shape", () => {
    const cmd = GaugeCmds.set_value("g1", { value: 0 })
    expect(Object.keys(cmd.payload).sort()).toEqual(
      ["node_id", "op", "payload"].sort(),
    )
  })

  test("different node IDs target correctly", () => {
    const a = GaugeCmds.set_value("gauge-a", { value: 10 })
    const b = GaugeCmds.set_value("gauge-b", { value: 20 })
    expect(a.payload["node_id"]).toBe("gauge-a")
    expect(b.payload["node_id"]).toBe("gauge-b")
  })
})
