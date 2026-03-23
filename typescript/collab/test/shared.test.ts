/**
 * Unit tests for the shared state manager.
 *
 * Tests the collaborative state logic: connect, disconnect,
 * event handling, broadcasting, and per-client dark mode.
 */

import { describe, expect, test, vi } from "vitest"
import { Shared } from "../src/shared.js"
import type { Model } from "../src/collab.js"

function createShared() {
  return new Shared()
}

describe("Shared", () => {
  // -- Connect/disconnect ---------------------------------------------------

  test("starts with no clients", () => {
    const shared = createShared()
    expect(shared.clientCount).toBe(0)
  })

  test("connect registers a client and sends initial model", () => {
    const shared = createShared()
    const received: Model[] = []
    shared.connect((m) => received.push(m))

    expect(shared.clientCount).toBe(1)
    expect(received).toHaveLength(1)
    expect(received[0]!.count).toBe(0)
    expect(received[0]!.status).toBe("1 connected")
  })

  test("disconnect removes the client", () => {
    const shared = createShared()
    const id = shared.connect(() => {})
    shared.disconnect(id)

    expect(shared.clientCount).toBe(0)
  })

  test("status updates on connect and disconnect", () => {
    const shared = createShared()
    const received: Model[] = []

    const id1 = shared.connect((m) => received.push(m))
    expect(received.at(-1)!.status).toBe("1 connected")

    const id2 = shared.connect((m) => received.push(m))
    // Both clients get the broadcast
    expect(received.at(-1)!.status).toBe("2 connected")

    shared.disconnect(id1)
    expect(received.at(-1)!.status).toBe("1 connected")
  })

  // -- Event handling -------------------------------------------------------

  test("click inc increments the counter", () => {
    const shared = createShared()
    const received: Model[] = []
    const id = shared.connect((m) => received.push(m))

    shared.handleEvent(id, { family: "click", id: "inc" })
    expect(received.at(-1)!.count).toBe(1)

    shared.handleEvent(id, { family: "click", id: "inc" })
    expect(received.at(-1)!.count).toBe(2)
  })

  test("click dec decrements the counter", () => {
    const shared = createShared()
    const received: Model[] = []
    const id = shared.connect((m) => received.push(m))

    shared.handleEvent(id, { family: "click", id: "dec" })
    expect(received.at(-1)!.count).toBe(-1)
  })

  test("input name updates the name", () => {
    const shared = createShared()
    const received: Model[] = []
    const id = shared.connect((m) => received.push(m))

    shared.handleEvent(id, { family: "input", id: "name", value: "Alice" })
    expect(received.at(-1)!.name).toBe("Alice")
  })

  test("input notes updates the notes", () => {
    const shared = createShared()
    const received: Model[] = []
    const id = shared.connect((m) => received.push(m))

    shared.handleEvent(id, { family: "input", id: "notes", value: "Hello" })
    expect(received.at(-1)!.notes).toBe("Hello")
  })

  test("unknown events are ignored", () => {
    const shared = createShared()
    const received: Model[] = []
    const id = shared.connect((m) => received.push(m))

    const before = received.length
    shared.handleEvent(id, { family: "click", id: "nonexistent" })
    // No new broadcast (model unchanged)
    expect(received.length).toBe(before)
  })

  // -- Broadcasting ---------------------------------------------------------

  test("events broadcast to all clients", () => {
    const shared = createShared()
    const client1: Model[] = []
    const client2: Model[] = []

    const id1 = shared.connect((m) => client1.push(m))
    shared.connect((m) => client2.push(m))

    shared.handleEvent(id1, { family: "click", id: "inc" })

    // Both clients see count = 1
    expect(client1.at(-1)!.count).toBe(1)
    expect(client2.at(-1)!.count).toBe(1)
  })

  // -- Per-client dark mode -------------------------------------------------

  test("dark mode toggle is per-client", () => {
    const shared = createShared()
    const client1: Model[] = []
    const client2: Model[] = []

    const id1 = shared.connect((m) => client1.push(m))
    shared.connect((m) => client2.push(m))

    // Client 1 toggles dark mode
    shared.handleEvent(id1, { family: "toggle", id: "theme" })

    // Client 1 sees dark mode on
    expect(client1.at(-1)!.darkMode).toBe(true)
    // Client 2 is NOT affected
    expect(client2.at(-1)!.darkMode).toBe(false)
  })

  test("dark mode toggle does not broadcast to other clients", () => {
    const shared = createShared()
    const sendSpy1 = vi.fn()
    const sendSpy2 = vi.fn()

    const id1 = shared.connect(sendSpy1)
    shared.connect(sendSpy2)

    // Reset call counts after connect
    sendSpy1.mockClear()
    sendSpy2.mockClear()

    // Client 1 toggles dark mode
    shared.handleEvent(id1, { family: "toggle", id: "theme" })

    // Only client 1 received a snapshot
    expect(sendSpy1).toHaveBeenCalledTimes(1)
    expect(sendSpy2).toHaveBeenCalledTimes(0)
  })
})
