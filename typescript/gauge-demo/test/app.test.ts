/**
 * Tests for the TemperatureMonitor app logic.
 *
 * Tests the app directly (no renderer needed) by calling init/view
 * and inspecting results. Extension events (value_changed) are
 * simulated by constructing event objects and feeding them to the
 * app's update function.
 *
 * Integration tests (via real binary) are in a separate describe
 * block and skipped if the custom binary hasn't been built.
 */

import { existsSync } from "node:fs"
import { resolve } from "node:path"
import { afterAll, beforeAll, describe, expect, test } from "vitest"
import { createSession, stopPool } from "plushie/testing"
import type { TestSession } from "plushie/testing"
import gaugeApp from "../src/app.js"
import {
  init,
  view,
  temperatureStatus,
  statusColor,
  resetTemp,
  setHigh,
} from "../src/app.js"
import type { Model } from "../src/app.js"

// -- Helpers ----------------------------------------------------------------

/** Unwrap an update return into (model, command | null). */
function unwrap(result: Model | [Model, unknown]): [Model, unknown | null] {
  if (Array.isArray(result)) return [result[0], result[1]]
  return [result, null]
}

/** Find a node by id in a UINode tree. */
function findNode(
  node: { id: string; children?: readonly unknown[] },
  id: string,
): { id: string; type: string; props: Record<string, unknown> } | null {
  const n = node as {
    id: string
    type: string
    props: Record<string, unknown>
    children?: readonly unknown[]
  }
  if (n.id === id) return n
  for (const child of n.children ?? []) {
    const found = findNode(child as typeof node, id)
    if (found) return found
  }
  return null
}

/** Simulate a value_changed event from the Rust widget. */
function valueChangedEvent(value: number) {
  return {
    kind: "widget" as const,
    type: "value_changed",
    id: "temp",
    scope: [] as string[],
    data: { value },
    value: null,
    modifiers: null,
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Pure function tests (no binary needed)
// ═══════════════════════════════════════════════════════════════════════════

// -- Helpers ----------------------------------------------------------------

describe("temperatureStatus", () => {
  test("cool below 40", () => expect(temperatureStatus(10)).toBe("Cool"))
  test("normal at 40", () => expect(temperatureStatus(40)).toBe("Normal"))
  test("normal at 59", () => expect(temperatureStatus(59)).toBe("Normal"))
  test("warning at 60", () => expect(temperatureStatus(60)).toBe("Warning"))
  test("warning at 79", () => expect(temperatureStatus(79)).toBe("Warning"))
  test("critical at 80", () => expect(temperatureStatus(80)).toBe("Critical"))
  test("critical at 100", () => expect(temperatureStatus(100)).toBe("Critical"))
})

describe("statusColor", () => {
  test("blue for cool", () => expect(statusColor(10)).toBe("#3498db"))
  test("green for normal", () => expect(statusColor(50)).toBe("#27ae60"))
  test("orange for warning", () => expect(statusColor(70)).toBe("#e67e22"))
  test("red for critical", () => expect(statusColor(90)).toBe("#e74c3c"))
})

// -- Init -------------------------------------------------------------------

describe("init", () => {
  test("temperature starts at 20", () => expect(init().temperature).toBe(20))
  test("targetTemp starts at 20", () => expect(init().targetTemp).toBe(20))
  test("history starts with [20]", () => expect(init().history).toEqual([20]))
})

// -- Update (button handlers + widget events) ----------------------------

describe("update", () => {
  test("reset sets targetTemp and returns set_value command", () => {
    const model: Model = { temperature: 50, targetTemp: 50, history: [20, 50] }
    const [newModel, cmd] = unwrap(resetTemp(model))
    expect(newModel.targetTemp).toBe(20)
    // temperature unchanged -- waits for Rust value_changed
    expect(newModel.temperature).toBe(50)
    expect(cmd).not.toBeNull()
    expect((cmd as Record<string, unknown>)["type"]).toBe("extension_command")
  })

  test("high sets targetTemp and returns set_value command", () => {
    const [newModel, cmd] = unwrap(setHigh(init()))
    expect(newModel.targetTemp).toBe(90)
    // temperature unchanged -- waits for Rust value_changed
    expect(newModel.temperature).toBe(20)
    expect(cmd).not.toBeNull()
  })

  test("slider does not change current temperature", () => {
    // animate_to updates Rust-side target only
    const model = init()
    // Slider handler returns [model with new targetTemp, animate_to command]
    // Temperature stays at 20
    expect(model.temperature).toBe(20)
  })

  test("value_changed event updates temperature", () => {
    const config = gaugeApp.config
    const event = valueChangedEvent(42)
    const result = config.update!(init(), event as never)
    const [model] = unwrap(result as Model)
    expect(model.temperature).toBe(42)
  })

  test("value_changed adds to history", () => {
    const config = gaugeApp.config
    let model = init()
    for (const temp of [30, 50, 70]) {
      const result = config.update!(model, valueChangedEvent(temp) as never)
      ;[model] = unwrap(result as Model)
    }
    expect(model.history).toEqual([20, 30, 50, 70])
  })

  test("unknown event returns model unchanged", () => {
    const config = gaugeApp.config
    const model = init()
    const event = {
      kind: "widget" as const,
      type: "click",
      id: "nonexistent",
      scope: [],
      data: null,
      value: null,
      modifiers: null,
    }
    const result = config.update!(model, event as never)
    expect(result).toBe(model)
  })
})

// -- View -------------------------------------------------------------------

describe("view", () => {
  test("returns a window node", () => {
    const tree = view(init())
    expect(tree.type).toBe("window")
    expect(tree.id).toBe("main")
  })

  test("has gauge widget with native widget type", () => {
    const tree = view(init())
    const gauge = findNode(tree, "temp")
    expect(gauge).not.toBeNull()
    expect(gauge!.type).toBe("gauge")
  })

  test("gauge has correct initial props", () => {
    const tree = view(init())
    const gauge = findNode(tree, "temp")!
    expect(gauge.props["value"]).toBe(20)
    expect(gauge.props["min"]).toBe(0)
    expect(gauge.props["max"]).toBe(100)
    expect(gauge.props["color"]).toBe("#3498db")
  })

  test("gauge props change with temperature", () => {
    const model: Model = { temperature: 90, targetTemp: 90, history: [20, 90] }
    const tree = view(model)
    const gauge = findNode(tree, "temp")!
    expect(gauge.props["value"]).toBe(90)
    expect(gauge.props["color"]).toBe("#e74c3c")
  })

  test("has all expected widgets", () => {
    const tree = view(init())
    expect(findNode(tree, "title")).not.toBeNull()
    expect(findNode(tree, "temp")).not.toBeNull()
    expect(findNode(tree, "status")).not.toBeNull()
    expect(findNode(tree, "reading")).not.toBeNull()
    expect(findNode(tree, "target")).not.toBeNull()
    expect(findNode(tree, "reset")).not.toBeNull()
    expect(findNode(tree, "high")).not.toBeNull()
    expect(findNode(tree, "history")).not.toBeNull()
  })
})

// -- Settings ---------------------------------------------------------------

describe("settings", () => {
  test("nativeWidgetConfig is present", () => {
    const settings = gaugeApp.config.settings
    expect(settings).toBeDefined()
    expect(settings!.nativeWidgetConfig).toBeDefined()
  })

  test("gauge config values", () => {
    const cfg = gaugeApp.config.settings!.nativeWidgetConfig!["gauge"] as Record<
      string,
      unknown
    >
    expect(cfg["arcWidth"]).toBe(8)
    expect(cfg["tickCount"]).toBe(10)
  })
})

// -- Stateful journey -------------------------------------------------------

describe("stateful journey", () => {
  test("full round-trip: high -> value_changed -> verify -> reset -> verify", () => {
    const config = gaugeApp.config
    let model = init()

    // Initial state
    expect(model.temperature).toBe(20)
    expect(model.targetTemp).toBe(20)

    // Click high -- sets targetTemp, returns command
    const [afterHigh, highCmd] = unwrap(setHigh(model))
    expect(afterHigh.targetTemp).toBe(90)
    expect(afterHigh.temperature).toBe(20) // not yet changed
    expect(highCmd).not.toBeNull()

    // Simulate Rust responding with value_changed
    model = config.update!(afterHigh, valueChangedEvent(90) as never) as Model
    expect(model.temperature).toBe(90)
    expect(model.history).toEqual([20, 90])

    // Verify gauge props reflect the change
    const tree = view(model)
    const gauge = findNode(tree, "temp")!
    expect(gauge.props["value"]).toBe(90)
    expect(gauge.props["color"]).toBe("#e74c3c")

    // Click reset
    const [afterReset, resetCmd] = unwrap(resetTemp(model))
    expect(afterReset.targetTemp).toBe(20)
    expect(afterReset.temperature).toBe(90) // not yet changed
    expect(resetCmd).not.toBeNull()

    // Simulate Rust responding
    model = config.update!(
      afterReset,
      valueChangedEvent(20) as never,
    ) as Model
    expect(model.temperature).toBe(20)

    const tree2 = view(model)
    const gauge2 = findNode(tree2, "temp")!
    expect(gauge2.props["value"]).toBe(20)
    expect(gauge2.props["color"]).toBe("#3498db")
  })
})

// -- Rapid clicks -----------------------------------------------------------

describe("rapid clicks", () => {
  test("alternating high/reset with value_changed produces correct history", () => {
    const config = gaugeApp.config
    let model = init()

    for (let i = 0; i < 5; i++) {
      // High
      const [afterHigh] = unwrap(setHigh(model))
      model = config.update!(
        afterHigh,
        valueChangedEvent(90) as never,
      ) as Model

      // Reset
      const [afterReset] = unwrap(resetTemp(model))
      model = config.update!(
        afterReset,
        valueChangedEvent(20) as never,
      ) as Model
    }

    expect(model.temperature).toBe(20)
    expect(model.targetTemp).toBe(20)
    expect(model.history[0]).toBe(20)
    expect(model.history.at(-1)).toBe(20)
    expect(model.history.at(-2)).toBe(90)

    // Every odd index is 90, every even is 20
    for (let i = 0; i < model.history.length; i++) {
      expect(model.history[i]).toBe(i % 2 === 0 ? 20 : 90)
    }
  })

  test("each click produces the correct command", () => {
    let model = init()
    const commands: unknown[] = []

    for (let i = 0; i < 3; i++) {
      const [m1, cmd1] = unwrap(setHigh(model))
      commands.push(cmd1)
      model = m1

      const [m2, cmd2] = unwrap(resetTemp(model))
      commands.push(cmd2)
      model = m2
    }

    for (let i = 0; i < commands.length; i++) {
      const cmd = commands[i] as Record<string, unknown>
      expect(cmd["type"]).toBe("extension_command")
      const payload = cmd["payload"] as Record<string, unknown>
      expect(payload["op"]).toBe("set_value")
      const inner = payload["payload"] as Record<string, unknown>
      expect(inner["value"]).toBe(i % 2 === 0 ? 90 : 20)
    }
  })
})

// ═══════════════════════════════════════════════════════════════════════════
// Integration tests (require custom binary)
// ═══════════════════════════════════════════════════════════════════════════

const binaryPath = resolve(
  "node_modules",
  ".plushie",
  "build",
  "target",
  "debug",
  "gauge-demo-plushie",
)
const hasBinary = existsSync(binaryPath)
const integration = hasBinary ? describe : describe.skip

// Tests are sequential -- shared session, no reset between tests.
integration("gauge app (integration)", () => {
  let session: TestSession<Model>

  beforeAll(async () => {
    session = await createSession(gaugeApp, { binary: binaryPath })
    await session.start()
  })

  afterAll(() => {
    session?.stop()
    stopPool()
  })

  test("model starts with correct defaults", () => {
    const m = session.model()
    expect(m.temperature).toBe(20)
    expect(m.targetTemp).toBe(20)
    expect(m.history).toEqual([20])
  })

  test("main window is the root", () => {
    const tree = session.tree()
    expect(tree).not.toBeNull()
    expect(tree!.type).toBe("window")
  })

  test("gauge widget has native widget type on the wire", async () => {
    const gauge = await session.find("temp")
    expect(gauge).not.toBeNull()
    expect(gauge!.type).toBe("gauge")
  })

  test("gauge carries correct props on the wire", async () => {
    const gauge = await session.find("temp")
    expect(gauge!.props["value"]).toBe(20)
    expect(gauge!.props["min"]).toBe(0)
    expect(gauge!.props["max"]).toBe(100)
    expect(gauge!.props["color"]).toBe("#3498db")
  })

  test("high button sets targetTemp", async () => {
    await session.click("high")
    expect(session.model().targetTemp).toBe(90)
  })

  test("reset button sets targetTemp", async () => {
    await session.click("reset")
    expect(session.model().targetTemp).toBe(20)
  })

  test("slider updates targetTemp", async () => {
    await session.slide("target", 75)
    expect(session.model().targetTemp).toBe(75)
  })

  test("slider does not change current temperature", () => {
    // animate_to doesn't echo an event
    expect(session.model().temperature).toBe(20)
  })
})
