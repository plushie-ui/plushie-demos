/**
 * Data Explorer -- browse, search, sort, and paginate structured data.
 *
 * Demonstrates: Data.query pipeline, Table widget with sorting,
 * PickList for page size, and SEA standalone packaging.
 */

import { app, Data } from "plushie"
import {
  Window,
  Column,
  Row,
  Text,
  Button,
  TextInput,
  PickList,
  Table,
} from "plushie/ui"
import { COUNTRIES } from "./countries.js"
import type { Country } from "./countries.js"

// -- Model ------------------------------------------------------------------

export interface Model {
  records: Country[]
  search: string
  sortField: string
  sortDir: "asc" | "desc"
  page: number
  pageSize: number
}

export function init(): Model {
  return {
    records: COUNTRIES,
    search: "",
    sortField: "name",
    sortDir: "asc",
    page: 1,
    pageSize: 10,
  }
}

// -- Helpers ----------------------------------------------------------------

function formatNumber(n: number): string {
  return n.toLocaleString("en-US")
}

/** Run the full query pipeline against the current model. */
export function queryRecords(model: Model) {
  return Data.query(model.records, {
    search:
      model.search.length > 0
        ? { fields: ["name", "capital", "continent"], query: model.search }
        : undefined,
    sort: { field: model.sortField, direction: model.sortDir },
    page: model.page,
    pageSize: model.pageSize,
  })
}

// -- Handlers ---------------------------------------------------------------

const setSearch = (s: Model, e: { value: unknown }): Model => ({
  ...s,
  search: e.value as string,
  page: 1,
})

const clearSearch = (s: Model): Model => ({
  ...s,
  search: "",
  page: 1,
})

const handleSort = (s: Model, e: { column: unknown }): Model => {
  const col = e.column as string
  if (col === s.sortField) {
    return { ...s, sortDir: s.sortDir === "asc" ? "desc" : "asc", page: 1 }
  }
  return { ...s, sortField: col, sortDir: "asc", page: 1 }
}

const prevPage = (s: Model): Model => ({
  ...s,
  page: Math.max(1, s.page - 1),
})

const nextPage = (s: Model): Model => {
  const { total } = queryRecords(s)
  const maxPage = Math.ceil(total / s.pageSize)
  return { ...s, page: Math.min(maxPage, s.page + 1) }
}

const setPageSize = (s: Model, e: { value: unknown }): Model => ({
  ...s,
  pageSize: Number(e.value),
  page: 1,
})

// -- View -------------------------------------------------------------------

export function view(model: Model) {
  const result = queryRecords(model)
  const totalPages = Math.max(1, Math.ceil(result.total / result.pageSize))

  const tableRows = result.entries.map((c) => ({
    name: c.name,
    capital: c.capital,
    continent: c.continent,
    population: formatNumber(c.population),
    area: formatNumber(c.area),
  }))

  return (
    <Window id="main" title="Data Explorer">
      <Column padding={16} spacing={12}>
        {/* Search bar */}
        <Row spacing={8}>
          <TextInput
            id="search"
            value={model.search}
            placeholder="Search countries..."
            onInput={setSearch}
          />
          {model.search.length > 0 && (
            <Button id="clear_search" onClick={clearSearch}>
              Clear
            </Button>
          )}
        </Row>

        {/* Status line */}
        <Row spacing={16}>
          <Text id="status" size={12} color="#888888">
            {result.total === model.records.length
              ? `${result.total} records`
              : `${result.total} of ${model.records.length} records`}
          </Text>
          <Text id="page_info" size={12} color="#888888">
            {`Page ${result.page} of ${totalPages}`}
          </Text>
        </Row>

        {/* Data table */}
        <Table
          id="data"
          columns={[
            { key: "name", label: "Name" },
            { key: "capital", label: "Capital" },
            { key: "continent", label: "Continent" },
            { key: "population", label: "Population" },
            { key: "area", label: "Area (km\u00B2)" },
          ]}
          rows={tableRows}
          sortBy={model.sortField}
          sortOrder={model.sortDir}
          onSort={handleSort}
          header={true}
          separator={true}
        />

        {/* Pagination */}
        <Row spacing={8}>
          <Button id="prev" onClick={prevPage}>
            Previous
          </Button>
          <Button id="next" onClick={nextPage}>
            Next
          </Button>
          <PickList
            id="page_size"
            options={["5", "10", "25", "50"]}
            selected={String(model.pageSize)}
            onSelect={setPageSize}
          />
        </Row>
      </Column>
    </Window>
  )
}

// -- App --------------------------------------------------------------------

export default app<Model>({
  init: init(),
  view,
})
