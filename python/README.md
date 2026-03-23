# Python Demos

Example projects using the [plushie Python SDK](https://github.com/plushie-ui/plushie-python).

## Demos

### [gauge-demo](gauge-demo/)

Temperature monitor with a native Rust gauge widget extension.
Demonstrates extension commands (`set_value`, `animate_to`),
optimistic updates, and `pyproject.toml` extension configuration.

### [sparkline-dashboard](sparkline-dashboard/)

Live system monitor with 3 sparkline charts for CPU, memory, and
network metrics. Demonstrates a render-only Rust canvas extension,
timer subscriptions, and simulated live data.

### [collab](collab/)

Collaborative scratchpad showing 4 ways to run the same app -- native
desktop, exec mode, shared-state WebSocket, and SSH. Multiple clients
share a single counter and notes in real time. Demonstrates
`IoStreamAdapter`, `StdioConnection`, WebSocket transport, SSH
subsystem, and the WASM browser renderer.

### [data-explorer](data-explorer/)

Standalone native desktop DataFrame viewer. Open CSV, JSON, Parquet,
or Excel files via the native file dialog, display in a sortable
table with search, pagination, and column statistics. Demonstrates
pandas integration, platform effects, async file loading, and
PyInstaller standalone bundling. Python-ecosystem exclusive.

### [crash-test](crash-test/)

Crash resilience demo exercising both failure paths: Python-side
exceptions (`RuntimeError` in `update()`, `view()`) and Rust-side
panics (in `render()`, `handle_command()`). A working counter proves
the app keeps functioning through all crashes. Demonstrates the
runtime's error handling, `catch_unwind` panic isolation, and the
`PLUSHIE_NO_CATCH_UNWIND` debug env var.

## Cross-language comparison

The same demos exist in other languages:

| Demo | Python | TypeScript | Ruby | Elixir | Gleam |
|---|---|---|---|---|---|
| Gauge | [gauge-demo](gauge-demo/) | [gauge-demo](../typescript/gauge-demo/) | [gauge-demo](../ruby/gauge-demo/) | [gauge-demo](../elixir/gauge-demo/) | [gauge-demo](../gleam/gauge-demo/) |
| Sparkline | [sparkline-dashboard](sparkline-dashboard/) | [sparkline-dashboard](../typescript/sparkline-dashboard/) | [sparkline-dashboard](../ruby/sparkline-dashboard/) | [sparkline-dashboard](../elixir/sparkline-dashboard/) | [sparkline-dashboard](../gleam/sparkline-dashboard/) |
| Collab | [collab](collab/) | -- | -- | [collab](../elixir/collab/) | [collab](../gleam/collab/) |

The Rust extension code is identical across languages -- only the
host SDK code differs.
