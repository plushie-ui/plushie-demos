/**
 * Collab app tests.
 *
 * Integration tests run through the real plushie-renderer binary in
 * headless mode. Pure function tests cover init/update/view logic.
 */

import { afterAll, beforeAll, describe, expect, test } from "vitest"
import { createSession, stopPool } from "plushie/testing"
import type { TestSession } from "plushie/testing"
import collabApp, { init, update, view } from "../src/collab.js"
import type { Model } from "../src/collab.js"

// -- Integration tests (real binary) -----------------------------------------

// Tests are sequential -- shared session, no reset between tests.
describe("collab (integration)", () => {
  let session: TestSession<Model>

  beforeAll(async () => {
    session = await createSession(collabApp, { mode: "headless" })
    await session.start()
  })

  afterAll(() => {
    session?.stop()
    stopPool()
  })

  test("model starts with correct defaults", () => {
    const m = session.model()
    expect(m.name).toBe("")
    expect(m.notes).toBe("")
    expect(m.count).toBe(0)
    expect(m.darkMode).toBe(false)
    expect(m.status).toBe("")
  })

  test("window tree exists", () => {
    const tree = session.tree()
    expect(tree).not.toBeNull()
    expect(tree!.type).toBe("window")
    expect(tree!.id).toBe("main")
  })

  test("all key widgets exist", async () => {
    await session.assertExists("title")
    await session.assertExists("name")
    await session.assertExists("inc")
    await session.assertExists("dec")
    await session.assertExists("count")
    await session.assertExists("theme")
    await session.assertExists("notes")
  })

  test("status widget absent when status is empty", async () => {
    await session.assertNotExists("status")
  })

  test("clicking inc increments count", async () => {
    await session.click("inc")
    expect(session.model().count).toBe(1)

    await session.click("inc")
    expect(session.model().count).toBe(2)
  })

  test("clicking dec decrements count", async () => {
    await session.click("dec")
    expect(session.model().count).toBe(1)
  })

  test("typing in name input updates model", async () => {
    await session.typeText("name", "Alice")
    expect(session.model().name).toBe("Alice")
  })

  test("toggling dark mode checkbox", async () => {
    await session.toggle("theme")
    expect(session.model().darkMode).toBe(true)

    await session.toggle("theme")
    expect(session.model().darkMode).toBe(false)
  })

  test("title text renders", async () => {
    await session.assertText("title", "Collaborative Scratchpad")
  })
})

// -- Pure function tests (no binary) ------------------------------------------

describe("update (pure)", () => {
  test("click inc", () => expect(update(init(), "click", "inc").count).toBe(1))
  test("click dec", () => expect(update(init(), "click", "dec").count).toBe(-1))
  test("input name", () => expect(update(init(), "input", "name", "Alice").name).toBe("Alice"))
  test("toggle theme", () => expect(update(init(), "toggle", "theme").darkMode).toBe(true))
  test("unknown event unchanged", () => {
    const m = init()
    expect(update(m, "click", "nonexistent")).toBe(m)
  })
})

describe("view (pure)", () => {
  test("returns a window node", () => {
    const tree = view(init())
    expect(tree.type).toBe("window")
    expect(tree.id).toBe("main")
  })
})
