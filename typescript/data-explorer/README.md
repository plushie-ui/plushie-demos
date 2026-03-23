# Data Explorer

Browse, search, sort, and paginate structured data in a native
desktop app. Ships with a 50-country dataset and can be packaged
as a standalone executable via Node.js SEA.

Demonstrates:

- `Data.query` pipeline (search, sort, paginate -- all composable)
- `Table` widget with sortable columns
- `PickList` for page size selection
- `TextInput` for live search filtering
- Typed data flow from dataset through query pipeline to table rows
- SEA standalone packaging (single executable, no dependencies)

## Setup

```sh
pnpm install
npx plushie download   # download the renderer binary
```

## Run

```sh
npx plushie run src/app.tsx
```

## Test

```sh
pnpm test
```

Unit tests cover the `Data.query` pipeline (search, sort, pagination,
composition), the countries dataset (completeness, uniqueness), and
the view structure.

## Package as standalone executable

Bundle the app into a single file that runs without Node.js or npm:

```sh
./scripts/package.sh
```

This produces `dist/data-explorer` (~60 MB) containing:
- The bundled TypeScript app
- The Node.js runtime
- The plushie renderer binary (as a SEA asset)

Run it:

```sh
./dist/data-explorer
```

Copy it to another machine -- no installation needed.

### How SEA packaging works

1. **Bundle** -- esbuild compiles the TSX app + dependencies into
   a single CJS file
2. **SEA config** -- declares the JS blob and plushie binary as
   embedded assets
3. **Prepare** -- `node --experimental-sea-config` creates the blob
4. **Inject** -- `postject` embeds the blob into a copy of the node
   binary
5. **Result** -- a single executable that, at runtime, extracts the
   plushie binary to a temp file and spawns it normally

### Size breakdown

| Component | Size |
|-----------|------|
| Node.js runtime | ~119 MB (Node 25) / ~70 MB (Node 22) |
| Plushie renderer | ~42 MB (release) |
| App bundle | ~177 KB |

Total varies by Node version. With Node 22 LTS + a stripped plushie
binary, expect ~90 MB. Compare: Electron (~150 MB), Tauri (~10 MB,
webview-dependent).

## Project structure

```
src/
  app.tsx               -- the data explorer app
  countries.ts          -- bundled 50-country dataset
test/
  app.test.ts           -- unit tests (Data.query, view, dataset)
scripts/
  bundle.mjs            -- esbuild config for SEA bundling
  package.sh            -- full SEA packaging pipeline
dist/                   -- build output (gitignored)
```

## The Data.query pipeline

The core of the app is one call:

```typescript
Data.query(records, {
  search: { fields: ["name", "capital", "continent"], query: searchTerm },
  sort: { field: "population", direction: "desc" },
  page: 2,
  pageSize: 10,
})
// Returns: { entries: Country[], total: number, page: number, pageSize: number }
```

The pipeline applies stages in order: filter -> search -> sort ->
paginate. Each stage is optional. The result preserves the input
type (`Country[]`), so the TypeScript compiler tracks the data shape
from the dataset through the query to the table columns.
