/**
 * Integration tests for the sparkline dashboard app.
 *
 * These tests run the full app through the custom-built binary that
 * includes the sparkline Rust extension. Every interaction goes through
 * the wire protocol: TypeScript -> msgpack -> custom binary (with
 * sparkline extension) -> msgpack -> TypeScript.
 *
 * Prerequisites:
 *   PLUSHIE_SOURCE_PATH=~/projects/plushie npx plushie build
 */

import { existsSync } from "node:fs"
import { resolve } from "node:path"
import { afterAll, beforeAll, describe, expect, test } from "vitest"
import { createSession, stopPool } from "plushie/testing"
import type { TestSession } from "plushie/testing"
import dashboardApp from "../src/app.js"
import type { Model } from "../src/app.js"

const binaryPath = resolve(
  "node_modules",
  ".plushie",
  "build",
  "target",
  "debug",
  "sparkline-dashboard-plushie",
)
const hasBinary = existsSync(binaryPath)
const integration = hasBinary ? describe : describe.skip

// Tests are sequential within the describe block -- each test builds
// on the state left by the previous one (shared session, no reset).
integration("sparkline dashboard app", () => {
  let session: TestSession<Model>

  beforeAll(async () => {
    session = await createSession(dashboardApp, { binary: binaryPath })
    await session.start()
  })

  afterAll(() => {
    session?.stop()
    stopPool()
  })

  // -- Initial state ------------------------------------------------

  test("model starts with empty samples and running", () => {
    const m = session.model()
    expect(m.cpuSamples).toEqual([])
    expect(m.memSamples).toEqual([])
    expect(m.netSamples).toEqual([])
    expect(m.running).toBe(true)
    expect(m.tickCount).toBe(0)
  })

  // -- Window and widget tree ---------------------------------------

  test("main window is the root node", () => {
    const tree = session.tree()
    expect(tree).not.toBeNull()
    expect(tree!.type).toBe("window")
    expect(tree!.id).toBe("main")
  })

  test("all expected widgets exist", async () => {
    await session.assertExists("title")
    await session.assertExists("toggle_running")
    await session.assertExists("clear")
    await session.assertExists("status")
    await session.assertExists("cpu_spark")
    await session.assertExists("mem_spark")
    await session.assertExists("net_spark")
    await session.assertExists("cpu_label")
    await session.assertExists("mem_label")
    await session.assertExists("net_label")
  })

  test("title text renders correctly", async () => {
    await session.assertText("title", "System Monitor")
  })

  // -- Sparkline extension widgets ----------------------------------

  test("sparkline widgets have the custom extension type", async () => {
    const cpu = await session.find("cpu_spark")
    const mem = await session.find("mem_spark")
    const net = await session.find("net_spark")

    // "sparkline" is NOT a built-in widget type -- it only exists
    // because our Rust extension registered it via type_names
    expect(cpu!.type).toBe("sparkline")
    expect(mem!.type).toBe("sparkline")
    expect(net!.type).toBe("sparkline")
  })

  test("sparkline carries typed props on the wire", async () => {
    const cpu = await session.find("cpu_spark")
    expect(cpu!.props["data"]).toEqual([])
    expect(cpu!.props["color"]).toBe("#4CAF50")
    expect(cpu!.props["fill"]).toBe(true)
    expect(cpu!.props["stroke_width"]).toBe(2.0)
    expect(cpu!.props["height"]).toBe(60.0)

    const net = await session.find("net_spark")
    expect(net!.props["color"]).toBe("#FF9800")
    expect(net!.props["fill"]).toBe(false)
  })

  test("sample count text shows zero initially", async () => {
    await session.assertText("status", "0 samples")
  })

  // -- Toggle pause/resume ------------------------------------------

  test("toggle pauses the dashboard", async () => {
    await session.click("toggle_running")
    expect(session.model().running).toBe(false)
  })

  test("toggle resumes the dashboard", async () => {
    await session.click("toggle_running")
    expect(session.model().running).toBe(true)
  })

  // -- Clear resets samples -----------------------------------------

  test("clear resets all samples and tick count", async () => {
    await session.click("clear")

    const m = session.model()
    expect(m.cpuSamples).toEqual([])
    expect(m.memSamples).toEqual([])
    expect(m.netSamples).toEqual([])
    expect(m.tickCount).toBe(0)
  })

  // -- Sequential stateful journey ----------------------------------
  // Simulate a timer event by injecting it, then verify the full
  // chain: model update -> view re-render -> wire props.

  test("timer tick adds samples and increments tick count", async () => {
    await session.inject({ kind: "timer", tag: "sample", timestamp: 0 })

    const m = session.model()
    expect(m.cpuSamples.length).toBe(1)
    expect(m.memSamples.length).toBe(1)
    expect(m.netSamples.length).toBe(1)
    expect(m.tickCount).toBe(1)
  })

  test("sample count text updates after tick", async () => {
    await session.assertText("status", "1 samples")
  })

  test("wire-level sparkline props contain data after tick", async () => {
    const cpu = await session.find("cpu_spark")
    expect(cpu!.props["data"]).toHaveLength(1)
    expect(typeof cpu!.props["data"][0]).toBe("number")
    expect(cpu!.props["color"]).toBe("#4CAF50")
    expect(cpu!.props["fill"]).toBe(true)
  })

  test("second tick accumulates samples", async () => {
    await session.inject({ kind: "timer", tag: "sample", timestamp: 500 })

    const m = session.model()
    expect(m.cpuSamples.length).toBe(2)
    expect(m.tickCount).toBe(2)

    const cpu = await session.find("cpu_spark")
    expect(cpu!.props["data"]).toHaveLength(2)
  })

  test("clear after ticks resets everything", async () => {
    await session.click("clear")

    const m = session.model()
    expect(m.cpuSamples).toEqual([])
    expect(m.memSamples).toEqual([])
    expect(m.netSamples).toEqual([])
    expect(m.tickCount).toBe(0)

    const cpu = await session.find("cpu_spark")
    expect(cpu!.props["data"]).toEqual([])
  })

  // -- Pause suppresses timer events --------------------------------

  test("timer events are ignored when paused", async () => {
    await session.click("toggle_running")
    expect(session.model().running).toBe(false)

    await session.inject({ kind: "timer", tag: "sample", timestamp: 1000 })

    const m = session.model()
    expect(m.cpuSamples).toEqual([])
    expect(m.tickCount).toBe(0)

    // Resume for subsequent tests
    await session.click("toggle_running")
    expect(session.model().running).toBe(true)
  })
})
