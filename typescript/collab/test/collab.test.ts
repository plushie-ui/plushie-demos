/**
 * Unit tests for the collab app logic.
 *
 * Tests the pure init/update/view functions directly -- no binary,
 * no server, no transport.
 */

import { describe, expect, test } from "vitest"
import { init, view } from "../src/collab.js"
import type { Model } from "../src/collab.js"

describe("init", () => {
  test("returns default model", () => {
    const m = init()
    expect(m.name).toBe("")
    expect(m.notes).toBe("")
    expect(m.count).toBe(0)
    expect(m.darkMode).toBe(false)
    expect(m.status).toBe("")
  })
})

describe("view", () => {
  test("returns a window node", () => {
    const tree = view(init())
    expect(tree.type).toBe("window")
    expect(tree.id).toBe("main")
  })

  test("counter text exists", () => {
    const m: Model = { ...init(), count: 42 }
    const tree = view(m)
    const count = findNode(tree, "count")
    expect(count).not.toBeNull()
    expect(count!.type).toBe("text")
  })

  test("name input has model value", () => {
    const m: Model = { ...init(), name: "Alice" }
    const tree = view(m)
    const name = findNode(tree, "name")
    expect(name).not.toBeNull()
    expect(name!.props["value"]).toBe("Alice")
  })

  test("status text exists when set", () => {
    const m: Model = { ...init(), status: "3 connected" }
    const tree = view(m)
    const status = findNode(tree, "status")
    expect(status).not.toBeNull()
    expect(status!.type).toBe("text")
  })

  test("status text absent when empty", () => {
    const tree = view(init())
    const status = findNode(tree, "status")
    expect(status).toBeNull()
  })
})

// Recursive node search
function findNode(
  node: { id: string; children?: readonly unknown[] },
  id: string,
): { id: string; type: string; props: Record<string, unknown> } | null {
  const n = node as { id: string; type: string; props: Record<string, unknown>; children?: readonly unknown[] }
  if (n.id === id) return n
  for (const child of n.children ?? []) {
    const found = findNode(child as typeof node, id)
    if (found) return found
  }
  return null
}
