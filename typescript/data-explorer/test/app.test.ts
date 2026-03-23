/**
 * Unit tests for the data explorer app.
 *
 * Tests the Data.query pipeline, view rendering, and update logic
 * directly. No binary needed.
 */

import { describe, expect, test } from "vitest"
import { Data } from "plushie"
import { COUNTRIES } from "../src/countries.js"
import { init, view } from "../src/app.js"
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

// -- Init -------------------------------------------------------------------

describe("init", () => {
  test("returns model with all countries loaded", () => {
    const m = init()
    expect(m.records).toHaveLength(50)
    expect(m.search).toBe("")
    expect(m.sortField).toBe("name")
    expect(m.sortDir).toBe("asc")
    expect(m.page).toBe(1)
    expect(m.pageSize).toBe(10)
  })
})

// -- View -------------------------------------------------------------------

describe("view", () => {
  test("returns a window node", () => {
    const tree = view(init())
    expect(tree.type).toBe("window")
    expect(tree.id).toBe("main")
  })

  test("table widget exists", () => {
    const tree = view(init())
    const table = findNode(tree, "data")
    expect(table).not.toBeNull()
    expect(table!.type).toBe("table")
  })

  test("search input exists", () => {
    const tree = view(init())
    const search = findNode(tree, "search")
    expect(search).not.toBeNull()
  })

  test("pagination buttons exist", () => {
    const tree = view(init())
    expect(findNode(tree, "prev")).not.toBeNull()
    expect(findNode(tree, "next")).not.toBeNull()
  })

  test("page size picker exists", () => {
    const tree = view(init())
    expect(findNode(tree, "page_size")).not.toBeNull()
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

// -- Helpers ----------------------------------------------------------------

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
