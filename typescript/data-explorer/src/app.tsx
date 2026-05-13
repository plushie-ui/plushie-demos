/**
 * Data Explorer - browse, search, sort, and paginate structured data.
 *
 * Demonstrates: Data.query pipeline, Table widget with sorting,
 * PickList for page size, and SEA standalone packaging.
 */

import { app, Data } from "plushie"
import type { DeepReadonly, Handler, WidgetEvent } from "plushie"
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

// Model

export interface Model {
  records: readonly Country[]
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

// Helpers

function formatNumber(n: number): string {
  return n.toLocaleString("en-US")
}

/** Run the full query pipeline against the current model. */
export function queryRecords(model: DeepReadonly<Model>) {
  const search =
    model.search.length > 0
      ? { fields: ["name", "capital", "continent"], query: model.search }
      : undefined

  return Data.query(model.records, {
    ...(search === undefined ? {} : { search }),
    sort: { field: model.sortField, direction: model.sortDir },
    page: model.page,
    pageSize: model.pageSize,
  })
}

// Handlers

const appHandler = (handler: Handler<Model>): Handler<unknown> =>
  handler as unknown as Handler<unknown>

const setSearch: Handler<Model> = (s, e) => ({
  ...s,
  search: String(e.value ?? ""),
  page: 1,
})

const clearSearch: Handler<Model> = (s) => ({
  ...s,
  search: "",
  page: 1,
})

const handleSort: Handler<Model> = (s, e) => {
  const col = String(eventField(e, "column") ?? "")
  if (col === s.sortField) {
    return { ...s, sortDir: s.sortDir === "asc" ? "desc" : "asc", page: 1 }
  }
  return { ...s, sortField: col, sortDir: "asc", page: 1 }
}

const prevPage: Handler<Model> = (s) => ({
  ...s,
  page: Math.max(1, s.page - 1),
})

const nextPage: Handler<Model> = (s) => {
  const { total } = queryRecords(s)
  const maxPage = Math.ceil(total / s.pageSize)
  return { ...s, page: Math.min(maxPage, s.page + 1) }
}

const setPageSize: Handler<Model> = (s, e) => ({
  ...s,
  pageSize: Number(e.value),
  page: 1,
})

function eventField(event: WidgetEvent, key: string): unknown {
  return event.data?.[key] ?? event.value
}

// View

export function view(model: DeepReadonly<Model>) {
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
      <Column padding={16} spacing={12} width="fill">
        {/* Search bar */}
        <Row spacing={8} width="fill">
          <TextInput
            id="search"
            value={model.search}
            placeholder="Search countries..."
            width="fill"
            onInput={appHandler(setSearch)}
          />
          {model.search.length > 0 && (
            <Button id="clear_search" onClick={appHandler(clearSearch)}>
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
          width="fill"
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
          onSort={appHandler(handleSort)}
          header={true}
          separator={true}
        />

        {/* Pagination */}
        <Row spacing={8}>
          <Button id="prev" onClick={appHandler(prevPage)}>
            Previous
          </Button>
          <Button id="next" onClick={appHandler(nextPage)}>
            Next
          </Button>
          <PickList
            id="page_size"
            options={["5", "10", "25", "50"]}
            selected={String(model.pageSize)}
            onSelect={appHandler(setPageSize)}
          />
        </Row>
      </Column>
    </Window>
  )
}

// App

const _app = app<Model>({
  init: init(),
  update: (model) => model,
  view,
})
export default _app
if (process.env["VITEST"] !== "true") {
  void _app.run()
}
