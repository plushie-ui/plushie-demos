/**
 * Tests for the crash test app.
 *
 * Pure function tests verify the handler behaviors (including that
 * the throwing handlers actually throw). Integration tests verify
 * the app keeps running after crashes.
 */

import { existsSync } from "node:fs"
import { resolve } from "node:path"
import { afterAll, beforeAll, describe, expect, test } from "vitest"
import { createSession, stopPool } from "plushie/testing"
import type { TestSession } from "plushie/testing"
import crashApp from "../src/app.js"
import {
  init,
  view,
  increment,
  decrement,
  triggerPanic,
  triggerHandlerThrow,
  triggerViewThrow,
  reset,
} from "../src/app.js"
import type { Model } from "../src/app.js"
import { CrashBox, CrashBoxCmds, crashBoxConfig } from "../src/crash-box.js"

// -- Helpers ----------------------------------------------------------------

function unwrap(result: Model | [Model, unknown]): [Model, unknown | null] {
  if (Array.isArray(result)) return [result[0], result[1]]
  return [result, null]
}

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

// ═══════════════════════════════════════════════════════════════════════════
// Extension definition
// ═══════════════════════════════════════════════════════════════════════════

describe("crashBoxConfig", () => {
  test("type is crash_box", () => {
    expect(crashBoxConfig.type).toBe("crash_box")
  })

  test("declares panic command", () => {
    expect(crashBoxConfig.commands).toEqual(["panic"])
  })

  test("has label and color props", () => {
    expect(crashBoxConfig.props).toEqual({
      label: "string",
      color: "color",
    })
  })
})

describe("CrashBox builder", () => {
  test("produces node with correct type", () => {
    const node = CrashBox("cb1", { label: "OK", color: "#2ecc71" })
    expect(node.type).toBe("crash_box")
    expect(node.id).toBe("cb1")
    expect(node.props["label"]).toBe("OK")
  })
})

describe("CrashBoxCmds", () => {
  test("panic command has correct structure", () => {
    const cmd = CrashBoxCmds.panic("cb1")
    expect(cmd.type).toBe("extension_command")
    expect(cmd.payload).toEqual({
      node_id: "cb1",
      op: "panic",
      payload: {},
    })
  })
})

// ═══════════════════════════════════════════════════════════════════════════
// App logic
// ═══════════════════════════════════════════════════════════════════════════

describe("init", () => {
  test("starts with count 0", () => expect(init().count).toBe(0))
  test("throwInView is false", () => expect(init().throwInView).toBe(false))
  test("status is Ready", () => expect(init().status).toBe("Ready"))
})

describe("handlers", () => {
  test("increment increases count", () => {
    expect(increment(init()).count).toBe(1)
  })

  test("decrement decreases count", () => {
    expect(decrement(init()).count).toBe(-1)
  })

  test("triggerPanic returns model and command", () => {
    const [model, cmd] = unwrap(triggerPanic(init()))
    expect(model.status).toContain("panic")
    expect(cmd).not.toBeNull()
    expect((cmd as Record<string, unknown>)["type"]).toBe("extension_command")
  })

  test("triggerHandlerThrow actually throws", () => {
    expect(() => triggerHandlerThrow(init())).toThrow("intentional error in handler")
  })

  test("triggerViewThrow sets the flag", () => {
    const model = triggerViewThrow(init())
    expect(model.throwInView).toBe(true)
  })

  test("reset clears the flag", () => {
    const model = reset({ ...init(), throwInView: true })
    expect(model.throwInView).toBe(false)
    expect(model.status).toBe("Recovered")
  })
})

describe("view", () => {
  test("renders normally when throwInView is false", () => {
    const tree = view(init())
    expect(tree.type).toBe("window")
    expect(tree.id).toBe("main")
  })

  test("throws when throwInView is true", () => {
    const model = { ...init(), throwInView: true }
    expect(() => view(model)).toThrow("intentional error in view")
  })

  test("has counter widget", () => {
    const tree = view(init())
    expect(findNode(tree, "count")).not.toBeNull()
  })

  test("has crash_box native widget", () => {
    const tree = view(init())
    const box = findNode(tree, "crash-widget")
    expect(box).not.toBeNull()
    expect(box!.type).toBe("crash_box")
  })

  test("has all crash buttons", () => {
    const tree = view(init())
    expect(findNode(tree, "panic")).not.toBeNull()
    expect(findNode(tree, "throw_handler")).not.toBeNull()
    expect(findNode(tree, "throw_view")).not.toBeNull()
    expect(findNode(tree, "reset")).not.toBeNull()
  })

  test("status text shows model status", () => {
    const tree = view({ ...init(), status: "Something happened" })
    const status = findNode(tree, "status")
    expect(status).not.toBeNull()
  })
})

describe("recovery sequence", () => {
  test("counter works after handler throw", () => {
    // triggerHandlerThrow throws -- the runtime catches it and
    // keeps the previous model. We simulate this by just not
    // calling the handler, then verifying increment still works.
    const before = init()
    // Handler throws -- model stays at `before`
    expect(() => triggerHandlerThrow(before)).toThrow()
    // Counter still works
    const after = increment(before)
    expect(after.count).toBe(1)
  })

  test("reset recovers from view throw", () => {
    // Set the flag
    const broken = triggerViewThrow(init())
    expect(broken.throwInView).toBe(true)
    expect(() => view(broken)).toThrow()

    // Reset clears it
    const recovered = reset(broken)
    expect(recovered.throwInView).toBe(false)

    // View works again
    const tree = view(recovered)
    expect(tree.type).toBe("window")
  })

  test("counter accumulates through the recovery", () => {
    let model = init()
    model = increment(model) // count = 1
    model = increment(model) // count = 2
    model = triggerViewThrow(model) // throwInView = true, count still 2
    // view() would throw here, but handlers still work
    model = increment(model) // count = 3
    model = reset(model) // throwInView = false
    model = increment(model) // count = 4
    expect(model.count).toBe(4)
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
  "crash-test-plushie",
)
const hasBinary = existsSync(binaryPath)
const integration = hasBinary ? describe : describe.skip

// Tests are sequential -- shared session.
integration("crash test (integration)", () => {
  let session: TestSession<Model>

  beforeAll(async () => {
    session = await createSession(crashApp, { binary: binaryPath })
    await session.start()
  })

  afterAll(() => {
    session?.stop()
    stopPool()
  })

  test("initial state", () => {
    expect(session.model().count).toBe(0)
    expect(session.model().throwInView).toBe(false)
  })

  test("counter works", async () => {
    await session.click("inc")
    await session.click("inc")
    expect(session.model().count).toBe(2)
  })

  test("crash_box widget exists on wire", async () => {
    const box = await session.find("crash-widget")
    expect(box).not.toBeNull()
    expect(box!.type).toBe("crash_box")
  })

  test("counter works after panic command", async () => {
    // Send the panic command to the Rust widget
    await session.click("panic")

    // The crash_box is now poisoned, but the counter still works
    await session.click("inc")
    expect(session.model().count).toBe(3)
  })

  test("counter works after handler throw", async () => {
    // The runtime catches the throw and keeps the previous model
    await session.click("throw_handler")

    // Count unchanged (handler threw, model reverted)
    expect(session.model().count).toBe(3)

    // But the app is still alive
    await session.click("inc")
    expect(session.model().count).toBe(4)
  })

  test("view throw freezes UI but handlers still run", async () => {
    await session.click("throw_view")
    expect(session.model().throwInView).toBe(true)

    // Counter handler still runs even though view throws
    await session.click("inc")
    expect(session.model().count).toBe(5)
  })

  test("reset recovers from view throw", async () => {
    await session.click("reset")
    expect(session.model().throwInView).toBe(false)
    expect(session.model().status).toBe("Recovered")
  })
})
