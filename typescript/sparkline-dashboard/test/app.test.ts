/**
 * Integration tests for the sparkline dashboard app.
 *
 * These tests run the full app through the custom-built binary that
 * includes the sparkline Rust extension. Every interaction goes
 * through the wire protocol.
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
integration("sparkline dashboard", () => {
  let session: TestSession<Model>

  beforeAll(async () => {
    session = await createSession(dashboardApp, { binary: binaryPath })
    await session.start()
  })

  afterAll(() => {
    session?.stop()
    stopPool()
  })

  // ── Initial state ──────────────────────────────────────────────

  test("model starts with empty samples and running", () => {
    const m = session.model()
    expect(m.cpuSamples).toEqual([])
    expect(m.memSamples).toEqual([])
    expect(m.netSamples).toEqual([])
    expect(m.running).toBe(true)
    expect(m.tickCount).toBe(0)
  })

  // ── Window and widget tree ─────────────────────────────────────

  test("main window is the root node", () => {
    const tree = session.tree()
    expect(tree).not.toBeNull()
    expect(tree!.type).toBe("window")
    expect(tree!.id).toBe("main")
  })

  test("title renders correctly", async () => {
    await session.assertText("title", "System Monitor")
  })

  test("control widgets exist", async () => {
    await session.assertExists("toggle_running")
    await session.assertExists("clear")
    await session.assertExists("status")
  })

  test("sparkline card widgets exist", async () => {
    await session.assertExists("cpu_spark")
    await session.assertExists("mem_spark")
    await session.assertExists("net_spark")
    await session.assertExists("cpu_label")
    await session.assertExists("mem_label")
    await session.assertExists("net_label")
  })

  // ── Sparkline extension widgets ────────────────────────────────

  test("sparkline widgets have the custom extension type", async () => {
    const cpu = await session.find("cpu_spark")
    const mem = await session.find("mem_spark")
    const net = await session.find("net_spark")

    expect(cpu!.type).toBe("sparkline")
    expect(mem!.type).toBe("sparkline")
    expect(net!.type).toBe("sparkline")
  })

  test("sparklines carry correct props on the wire", async () => {
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

  // ── Timer simulation ───────────────────────────────────────────

  test("timer tick adds samples", () => {
    session.timer("sample")

    const m = session.model()
    expect(m.cpuSamples).toHaveLength(1)
    expect(m.memSamples).toHaveLength(1)
    expect(m.netSamples).toHaveLength(1)
    expect(m.tickCount).toBe(1)
  })

  test("samples are numbers in valid ranges", () => {
    const m = session.model()
    expect(m.cpuSamples[0]).toBeTypeOf("number")
    expect(m.memSamples[0]).toBeTypeOf("number")
    expect(m.netSamples[0]).toBeTypeOf("number")
  })

  test("sparkline wire props contain data after tick", async () => {
    const cpu = await session.find("cpu_spark")
    expect(cpu!.props["data"]).toHaveLength(1)
  })

  test("second tick accumulates samples", () => {
    session.timer("sample")

    const m = session.model()
    expect(m.cpuSamples).toHaveLength(2)
    expect(m.memSamples).toHaveLength(2)
    expect(m.netSamples).toHaveLength(2)
    expect(m.tickCount).toBe(2)
  })

  // ── Toggle pause/resume ────────────────────────────────────────

  test("toggle pauses the dashboard", async () => {
    await session.click("toggle_running")
    expect(session.model().running).toBe(false)
  })

  test("timer events are ignored when paused", () => {
    session.timer("sample")

    const m = session.model()
    // Still 2 samples from before pausing
    expect(m.cpuSamples).toHaveLength(2)
    expect(m.tickCount).toBe(2)
  })

  test("toggle resumes the dashboard", async () => {
    await session.click("toggle_running")
    expect(session.model().running).toBe(true)
  })

  test("timer works again after resuming", () => {
    session.timer("sample")

    expect(session.model().cpuSamples).toHaveLength(3)
    expect(session.model().tickCount).toBe(3)
  })

  // ── Clear ──────────────────────────────────────────────────────

  test("clear resets all samples and tick count", async () => {
    await session.click("clear")

    const m = session.model()
    expect(m.cpuSamples).toEqual([])
    expect(m.memSamples).toEqual([])
    expect(m.netSamples).toEqual([])
    expect(m.tickCount).toBe(0)
  })

  test("sparkline data cleared on wire", async () => {
    const cpu = await session.find("cpu_spark")
    expect(cpu!.props["data"]).toEqual([])
  })

  // ── Sample cap ─────────────────────────────────────────────────

  test("samples cap at MAX_SAMPLES (100)", () => {
    // Simulate 105 ticks
    for (let i = 0; i < 105; i++) {
      session.timer("sample")
    }

    const m = session.model()
    expect(m.cpuSamples).toHaveLength(100)
    expect(m.memSamples).toHaveLength(100)
    expect(m.netSamples).toHaveLength(100)
    expect(m.tickCount).toBe(105)
  })
})
