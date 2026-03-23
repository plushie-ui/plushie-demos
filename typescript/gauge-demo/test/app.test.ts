/**
 * Integration tests for the gauge demo app.
 *
 * These tests run the full app through the custom-built binary that
 * includes the gauge Rust extension. Every interaction goes through
 * the wire protocol: TypeScript -> msgpack -> custom binary (with
 * gauge extension) -> msgpack -> TypeScript.
 *
 * Prerequisites:
 *   PLUSHIE_SOURCE_PATH=~/projects/plushie npx plushie build
 */

import { existsSync } from "node:fs"
import { resolve } from "node:path"
import { afterAll, beforeAll, describe, expect, test } from "vitest"
import { createSession, stopPool } from "plushie/testing"
import type { TestSession } from "plushie/testing"
import gaugeApp from "../src/app.js"
import type { Model } from "../src/app.js"

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

integration("gauge app", () => {
  let session: TestSession<Model>

  beforeAll(async () => {
    session = await createSession(gaugeApp, { binary: binaryPath })
    await session.start()
  })

  afterAll(() => {
    session?.stop()
    stopPool()
  })

  // ── Initial state ──────────────────────────────────────────────

  test("model starts with correct defaults", () => {
    const m = session.model()
    expect(m.temperature).toBe(20)
    expect(m.targetTemp).toBe(20)
    expect(m.history).toEqual([20])
  })

  // ── Window and widget tree ─────────────────────────────────────

  test("main window is the root node", () => {
    const tree = session.tree()
    expect(tree).not.toBeNull()
    expect(tree!.type).toBe("window")
    expect(tree!.id).toBe("main")
  })

  test("all expected widgets exist", async () => {
    await session.assertExists("title")
    await session.assertExists("temp")
    await session.assertExists("status")
    await session.assertExists("reading")
    await session.assertExists("target")
    await session.assertExists("reset")
    await session.assertExists("high")
    await session.assertExists("history")
  })

  test("title text renders correctly", async () => {
    await session.assertText("title", "Temperature Monitor")
  })

  // ── Gauge extension widget ─────────────────────────────────────

  test("gauge widget has the custom extension type", async () => {
    const gauge = await session.find("temp")
    expect(gauge).not.toBeNull()
    // "gauge" is NOT a built-in widget type -- it only exists because
    // our Rust extension registered it via WidgetExtension::type_names
    expect(gauge!.type).toBe("gauge")
  })

  test("gauge carries typed props on the wire", async () => {
    const gauge = await session.find("temp")
    expect(gauge!.props["value"]).toBe(20)
    expect(gauge!.props["min"]).toBe(0)
    expect(gauge!.props["max"]).toBe(100)
    expect(gauge!.props["color"]).toBe("#3498db")
  })

  // ── High button ────────────────────────────────────────────────
  // Sends GaugeCmds.set_value("temp", { value: 90 }) to the Rust
  // extension's handle_command via the wire protocol.

  test("high button updates model to 90", async () => {
    await session.click("high")

    const m = session.model()
    expect(m.temperature).toBe(90)
    expect(m.targetTemp).toBe(90)
  })

  test("gauge props reflect high temperature", async () => {
    const gauge = await session.find("temp")
    expect(gauge!.props["value"]).toBe(90)
    expect(gauge!.props["color"]).toBe("#e74c3c")
  })

  test("history records the high change", () => {
    expect(session.model().history).toEqual([20, 90])
  })

  // ── Reset button ───────────────────────────────────────────────
  // Sends GaugeCmds.set_value("temp", { value: 20 })

  test("reset button restores defaults", async () => {
    await session.click("reset")

    const m = session.model()
    expect(m.temperature).toBe(20)
    expect(m.targetTemp).toBe(20)
  })

  test("gauge props reflect reset temperature", async () => {
    const gauge = await session.find("temp")
    expect(gauge!.props["value"]).toBe(20)
    expect(gauge!.props["color"]).toBe("#3498db")
  })

  test("history records full sequence", () => {
    expect(session.model().history).toEqual([20, 90, 20])
  })

  // ── Slider interaction ─────────────────────────────────────────
  // Sends GaugeCmds.animate_to("temp", { value: ... }) which
  // updates Rust-side target but doesn't change TypeScript temperature.

  test("slider updates target temperature", async () => {
    await session.slide("target", 75)
    expect(session.model().targetTemp).toBe(75)
  })

  test("slider does not change current temperature", () => {
    // animate_to updates Rust-side state without emitting an event
    expect(session.model().temperature).toBe(20)
  })

  // ── Rapid interactions ─────────────────────────────────────────

  test("rapid clicks maintain consistency", async () => {
    await session.click("high")
    await session.click("reset")
    await session.click("high")
    await session.click("reset")

    const m = session.model()
    expect(m.temperature).toBe(20)
    expect(m.targetTemp).toBe(20)
    expect(m.history.at(-1)).toBe(20)
    expect(m.history.at(-2)).toBe(90)
  })

  // ── Extension command on the wire ──────────────────────────────

  test("extension command reaches the renderer without error", async () => {
    // The full path: click handler returns [newModel, extensionCommand]
    // -> Runtime sends extension_command over msgpack
    // -> Custom binary receives it
    // -> Rust GaugeExtension::handle_command processes it
    // No crash, no error -- the command is accepted by the Rust side.
    await session.click("high")

    // The model updated optimistically from the handler
    expect(session.model().temperature).toBe(90)

    // The gauge widget on the wire has the updated value
    const gauge = await session.find("temp")
    expect(gauge!.props["value"]).toBe(90)
    expect(gauge!.props["label"]).toBe("90\u00B0C")
  })

  test("animate_to command accepted without error", async () => {
    await session.slide("target", 42)
    expect(session.model().targetTemp).toBe(42)
  })
})
