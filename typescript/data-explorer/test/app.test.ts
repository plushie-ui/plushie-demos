/**
 * Data explorer tests.
 *
 * Pure function tests verify the Data.query pipeline and dataset
 * integrity. Integration tests run the full app through the real
 * plushie-renderer binary in headless mode.
 */

import { afterAll, beforeAll, describe, expect, test } from "vitest"
import { Data } from "plushie"
import { createSession, stopPool } from "plushie/testing"
import type { TestSession } from "plushie/testing"
import { COUNTRIES } from "../src/countries.js"
import app from "../src/app.js"
import type { Model } from "../src/app.js"

// -- Data.query pipeline ----------------------------------------------------

describe("Data.query", () => {
  test("returns all records when no options", () => {
    const result = Data.query(COUNTRIES, {})
    expect(result.total).toBe(50)
    expect(result.entries).toHaveLength(25) // default pageSize
    expect(result.page).toBe(1)
  })

  test("search filters by name", () => {
    const result = Data.query(COUNTRIES, {
      search: { fields: ["name"], query: "united" },
    })
    expect(result.total).toBe(2) // United Kingdom, United States
    expect(result.entries.every((c) => c["name"]!.toString().toLowerCase().includes("united"))).toBe(true)
  })

  test("search filters by capital", () => {
    const result = Data.query(COUNTRIES, {
      search: { fields: ["capital"], query: "tokyo" },
    })
    expect(result.total).toBe(1)
    expect(result.entries[0]!["name"]).toBe("Japan")
  })

  test("search filters by continent", () => {
    const result = Data.query(COUNTRIES, {
      search: { fields: ["continent"], query: "oceania" },
    })
    expect(result.total).toBe(2) // Australia, New Zealand
  })

  test("sort by name ascending", () => {
    const result = Data.query(COUNTRIES, {
      sort: { field: "name", direction: "asc" },
      pageSize: 5,
    })
    expect(result.entries[0]!["name"]).toBe("Argentina")
  })

  test("sort by name descending", () => {
    const result = Data.query(COUNTRIES, {
      sort: { field: "name", direction: "desc" },
      pageSize: 5,
    })
    expect(result.entries[0]!["name"]).toBe("Vietnam")
  })

  test("sort by population descending", () => {
    const result = Data.query(COUNTRIES, {
      sort: { field: "population", direction: "desc" },
      pageSize: 3,
    })
    expect(result.entries[0]!["name"]).toBe("India")
    expect(result.entries[1]!["name"]).toBe("China")
    expect(result.entries[2]!["name"]).toBe("United States")
  })

  test("pagination returns correct page", () => {
    const result = Data.query(COUNTRIES, {
      sort: { field: "name", direction: "asc" },
      page: 2,
      pageSize: 10,
    })
    expect(result.page).toBe(2)
    expect(result.entries).toHaveLength(10)
    expect(result.total).toBe(50)
    // Page 2 at size 10 starts at index 10
    expect(result.entries[0]!["name"]).toBe("Czech Republic")
  })

  test("last page may have fewer entries", () => {
    const result = Data.query(COUNTRIES, {
      sort: { field: "name", direction: "asc" },
      page: 5,
      pageSize: 12,
    })
    // 50 records, 12 per page, page 5 = records 49-50 = 2 records
    expect(result.entries).toHaveLength(2)
  })

  test("search + sort + paginate compose correctly", () => {
    const result = Data.query(COUNTRIES, {
      search: { fields: ["continent"], query: "europe" },
      sort: { field: "population", direction: "desc" },
      page: 1,
      pageSize: 5,
    })
    // Europe has many countries, sorted by population desc
    expect(result.entries[0]!["name"]).toBe("Russia")
    expect(result.entries.length).toBeLessThanOrEqual(5)
    expect(result.total).toBeGreaterThan(5) // Europe has >5 countries
  })
})

// -- Countries dataset ------------------------------------------------------

describe("countries dataset", () => {
  test("has 50 records", () => {
    expect(COUNTRIES).toHaveLength(50)
  })

  test("every record has all required fields", () => {
    for (const c of COUNTRIES) {
      expect(typeof c.name).toBe("string")
      expect(typeof c.capital).toBe("string")
      expect(typeof c.continent).toBe("string")
      expect(typeof c.population).toBe("number")
      expect(typeof c.area).toBe("number")
      expect(c.name.length).toBeGreaterThan(0)
      expect(c.population).toBeGreaterThan(0)
      expect(c.area).toBeGreaterThan(0)
    }
  })

  test("names are unique", () => {
    const names = COUNTRIES.map((c) => c.name)
    expect(new Set(names).size).toBe(names.length)
  })
})

// -- Integration tests (headless renderer) ----------------------------------

describe("data explorer (integration)", () => {
  let session: TestSession<Model>

  beforeAll(async () => {
    session = await createSession(app, { mode: "headless" })
    await session.start()
  })

  afterAll(() => {
    session?.stop()
    stopPool()
  })

  // ── Initial state ──────────────────────────────────────────────

  test("model starts with correct defaults", () => {
    const m = session.model()
    expect(m.records).toHaveLength(50)
    expect(m.search).toBe("")
    expect(m.sortField).toBe("name")
    expect(m.sortDir).toBe("asc")
    expect(m.page).toBe(1)
    expect(m.pageSize).toBe(10)
  })

  // ── Window and widget tree ─────────────────────────────────────

  test("window tree exists", () => {
    const tree = session.tree()
    expect(tree).not.toBeNull()
    expect(tree!.type).toBe("window")
    expect(tree!.id).toBe("main")
  })

  test("table widget exists on the wire", async () => {
    const table = await session.find("data")
    expect(table).not.toBeNull()
    expect(table!.type).toBe("table")
  })

  test("all expected widgets exist", async () => {
    await session.assertExists("search")
    await session.assertExists("prev")
    await session.assertExists("next")
    await session.assertExists("page_size")
    await session.assertExists("status")
  })

  // ── Search ─────────────────────────────────────────────────────

  test("typing in search updates model.search", async () => {
    await session.typeText("search", "united")
    expect(session.model().search).toBe("united")
    // Search resets to page 1
    expect(session.model().page).toBe(1)
  })

  test("search filters visible status text", async () => {
    // "united" matches 2 countries
    await session.assertText("status", "2 of 50 records")
  })

  test("clearing search restores full dataset", async () => {
    await session.click("clear_search")
    expect(session.model().search).toBe("")
    await session.assertText("status", "50 records")
  })

  // ── Pagination ─────────────────────────────────────────────────

  test("clicking next advances page", async () => {
    await session.click("next")
    expect(session.model().page).toBe(2)
  })

  test("page info reflects current page", async () => {
    await session.assertText("page_info", "Page 2 of 5")
  })

  test("clicking prev goes back", async () => {
    await session.click("prev")
    expect(session.model().page).toBe(1)
  })

  test("prev does not go below page 1", async () => {
    await session.click("prev")
    expect(session.model().page).toBe(1)
  })
})
