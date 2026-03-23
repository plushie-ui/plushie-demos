/**
 * Data Explorer -- browse, search, sort, and paginate structured data.
 *
 * Demonstrates: Data.query pipeline, Table widget with sorting,
 * keyboard shortcuts, file open effect, and SEA standalone packaging.
 */

import { app, Command, Data, Subscription, isTimer, isClick } from "plushie"
import {
  Window,
  Column,
  Row,
  Text,
  Button,
  TextInput,
  PickList,
  Table,
  Container,
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
  selectedName: string | null
}

export function init(): Model {
  return {
    records: COUNTRIES,
    search: "",
    sortField: "name",
    sortDir: "asc",
    page: 1,
    pageSize: 10,
    selectedName: null,
  }
}

// -- Helpers ----------------------------------------------------------------

function formatNumber(n: number): string {
  return n.toLocaleString("en-US")
}

function queryRecords(model: Model) {
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
  page: 1, // reset to first page on search
  selectedName: null,
})

const clearSearch = (s: Model): Model => ({
  ...s,
  search: "",
  page: 1,
  selectedName: null,
})

const handleSort = (s: Model, e: { column: unknown }): Model => {
  const col = e.column as string
  if (col === s.sortField) {
    // Toggle direction
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

  const selected = model.selectedName
    ? model.records.find((c) => c.name === model.selectedName) ?? null
    : null

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
          <Button
            id="prev"
            onClick={prevPage}
            disabled={model.page <= 1}
          >
            Previous
          </Button>
          <Button
            id="next"
            onClick={nextPage}
            disabled={model.page >= totalPages}
          >
            Next
          </Button>
          <PickList
            id="page_size"
            options={["5", "10", "25", "50"]}
            selected={String(model.pageSize)}
            onSelect={setPageSize}
          />
        </Row>

        {/* Detail panel */}
        {selected !== null && (
          <Container id="detail" padding={12}>
            <Column spacing={4}>
              <Text id="detail_name" size={16}>
                {selected.name}
              </Text>
              <Text id="detail_info" size={13} color="#666666">
                {`Capital: ${selected.capital}`}
              </Text>
              <Text id="detail_continent" size={13} color="#666666">
                {`Continent: ${selected.continent}`}
              </Text>
              <Text id="detail_pop" size={13} color="#666666">
                {`Population: ${formatNumber(selected.population)}`}
              </Text>
              <Text id="detail_area" size={13} color="#666666">
                {`Area: ${formatNumber(selected.area)} km\u00B2`}
              </Text>
            </Column>
          </Container>
        )}
      </Column>
    </Window>
  )
}

// -- App --------------------------------------------------------------------

export default app<Model>({
  init: init(),
  view,
})
