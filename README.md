# plushie-demos

Example applications for [Plushie](https://github.com/plushie-ui/plushie-rust),
organized by language.

## Elixir

| Demo | Description |
|------|-------------|
| [collab](elixir/collab/) | Collaborative scratchpad, multiple transport modes |
| [gauge-demo](elixir/gauge-demo/) | Native Rust widget with commands |
| [sparkline-dashboard](elixir/sparkline-dashboard/) | Render-only Rust widget with canvas |
| [notes](elixir/notes/) | Pure Elixir widgets + state helpers |
| [crash-test](elixir/crash-test/) | Error resilience and crash recovery |
| [examples](https://github.com/plushie-ui/plushie-elixir/tree/main/examples) | Single-file apps in the SDK repo |

See the [Elixir demos README](elixir/README.md) for setup and details.

## Gleam

| Demo | Description |
|------|-------------|
| [collab](gleam/collab/) | Collaborative scratchpad, multiple transport modes |
| [gauge-demo](gleam/gauge-demo/) | Native Rust widget with commands |
| [sparkline-dashboard](gleam/sparkline-dashboard/) | Render-only Rust widget with canvas |
| [notes](gleam/notes/) | Pure Gleam widgets + custom message types |
| [crash-lab](gleam/crash-lab/) | Error resilience and crash recovery |

See the [Gleam demos README](gleam/README.md) for setup and details.

## Python

| Demo | Description |
|------|-------------|
| [data-explorer](python/data-explorer/) | Data query pipeline with standalone packaging |
| [collab](python/collab/) | Collaborative scratchpad, multiple transport modes |
| [crash-test](python/crash-test/) | Error resilience and crash recovery |
| [gauge-demo](python/gauge-demo/) | Native Rust widget with commands |
| [sparkline-dashboard](python/sparkline-dashboard/) | Render-only Rust widget with canvas |
| [examples](https://github.com/plushie-ui/plushie-python/tree/main/examples) | Single-file apps in the SDK repo |

See the [Python demos README](python/README.md) for setup and details.

## TypeScript

| Demo | Description |
|------|-------------|
| [data-explorer](typescript/data-explorer/) | Data query pipeline + SEA standalone packaging |
| [collab](typescript/collab/) | Collaborative scratchpad, native, SSH, WebSocket, and WASM |
| [crash-test](typescript/crash-test/) | Error resilience and crash recovery |
| [gauge-demo](typescript/gauge-demo/) | Native Rust widget with commands |
| [sparkline-dashboard](typescript/sparkline-dashboard/) | Render-only Rust widget with canvas |
| [examples](https://github.com/plushie-ui/plushie-typescript/tree/main/examples) | Single-file apps in the SDK repo |

See the [TypeScript demos README](typescript/README.md) for setup and details.

## Standalone Packaging Proofs

The canonical first native-widget packaging proof is
[elixir/gauge-demo](elixir/gauge-demo/). Its package script builds a
custom renderer with the gauge Rust crate linked into the payload, so
the proof does not rely on a stock renderer.

## Ruby

| Demo | Description |
|------|-------------|
| [notes](ruby/notes/) | Pure Ruby widgets + state helpers |
| [crash-lab](ruby/crash-lab/) | Error resilience and crash recovery |
| [collab](ruby/collab/) | Collaborative scratchpad, multiple transport modes |
| [gauge-demo](ruby/gauge-demo/) | Native Rust widget with commands |
| [sparkline-dashboard](ruby/sparkline-dashboard/) | Render-only Rust widget with canvas |
| [examples](https://github.com/plushie-ui/plushie-ruby/tree/main/examples) | Single-file apps in the SDK repo |

See the [Ruby demos README](ruby/README.md) for setup and details.
