# Data Explorer

A tabular data viewer built with plushie and pandas. Open CSV, JSON,
Parquet, or Excel files and explore them with sorting, full-text search,
pagination, and per-column statistics.

The main window has a toolbar with an "Open File" button, a search bar,
a sortable data table showing the current page of rows, pagination
controls, and a collapsible stats panel when a column is selected.

## Features

- CSV, JSON, Parquet, and Excel file loading via native file dialog
- Sortable table columns (click header to sort, click again to reverse)
- Full-text search across all string columns
- Pagination (100 rows per page)
- Per-column statistics (count, nulls, unique, mean/std/min/max for
  numeric, top value for string)
- Overall summary (row count, column count, memory, null total)
- Async file loading (UI stays responsive during large loads)

## Setup

```sh
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
pip install pandas
python -m plushie download
```

## Run

```sh
python -m data_explorer
```

Or using the plushie CLI:

```sh
python -m plushie run data_explorer.app:DataExplorer
```

A sample dataset is included at `sample_data/sample.csv` for quick
exploration.

## Test

```sh
pytest -v
```

## Build standalone

Bundle the app into a self-contained executable with PyInstaller:

```sh
./build_standalone.sh
```

This downloads the plushie binary, bundles it alongside the Python app
and sample data, and produces `dist/DataExplorer/DataExplorer`. The
renderer is bundled as `plushie-renderer`, which is the bundled filename
the SDK resolver checks at runtime.

The script also emits shared launcher inputs under `dist/package/`:

- `payload/` with `bin/plushie-renderer` and `host/DataExplorer/`
- `payload.tar.zst`
- `plushie-package.toml`

The shared launcher handoff is:

```sh
bin/plushie package portable --manifest dist/package/plushie-package.toml --strict-tools
```

The generated shared launcher starts the packaged host first and sets
`PLUSHIE_BINARY_PATH` to the renderer in the payload. When
`PLUSHIE_SOCKET` is set by a separate renderer-parent proof, the same
host can connect to that socket instead of spawning its bundled
renderer.
