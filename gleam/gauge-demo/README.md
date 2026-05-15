# Gauge Demo

Temperature monitor with a native Rust gauge widget.
Demonstrates widget commands (`set_value`, `animate_to`),
the optimistic update pattern, and the custom binary build workflow.

## Prerequisites

- [Gleam](https://gleam.run/) (v1.0+)
- [Erlang/OTP](https://www.erlang.org/) (26+)
- [Rust](https://rustup.rs/) (1.92+, for building the custom binary)

## Setup

```bash
gleam deps download
PLUSHIE_RUST_SOURCE_PATH=/path/to/plushie-rust gleam run -m plushie/build
```

The build pipeline reads native widget configuration from `gleam.toml`,
generates a Cargo workspace, and builds a custom renderer binary with
the gauge widget compiled in.

## Run

```bash
gleam run -m gauge_demo
```

Renderer-parent startup for standalone packaging:

```bash
plushie-renderer --listen --exec-bin gleam --exec-arg run --exec-arg -m --exec-arg gauge_demo/connect
```

## Test

Tests cover the native widget definition, widget builder, commands,
app logic (init/update/view), helpers, and edge cases. No custom
binary needed; all tests exercise pure Gleam code.

```bash
gleam test
```

## Package proof

Build the custom renderer, host shipment payload, and package manifest:

```bash
PLUSHIE_RUST_SOURCE_PATH=/path/to/plushie-rust ./scripts/package.sh
```

The script writes `dist/payload.tar.zst` and
`dist/plushie-package.toml`. The payload contains a renderer rebuilt
with the `native/gauge` Rust crate linked in, and the manifest records
`renderer.kind = "custom"` with `renderer.source = "local-build"`.
By default it also copies a payload-local Erlang runtime so the
generated `bin/connect` wrapper can start without relying on plain
`erl` on `PATH` at runtime. Use `PLUSHIE_ERLANG_ROOT=/path/to/otp` to
choose a specific Erlang install. Use `PLUSHIE_BUNDLE_ERLANG=0` to skip
the runtime copy and keep the PATH-based behavior.

This is a prototype runtime bundle, not a full OTP release. It copies
the local ERTS plus `kernel`, `stdlib`, `sasl`, and `crypto`, which is
enough for this demo's shipment. `just package-artifact-postcheck` writes a
package-postcheck report with the payload archive size from the manifest and
the generated executable size. The shared archive helper rejects
symlinks, hard links, and special files before archiving. Runtime
pruning keeps OTP application directories intact, including licenses and
notices, and only narrows the copy to applications proven necessary for
the shipment.

Build the standalone launcher with:

```bash
cargo plushie package --manifest dist/plushie-package.toml --release
```

## How it works

### Architecture

The app follows the standard Plushie Elm loop (`init`/`update`/`view`)
with a native Rust widget for the gauge display.

```
Gleam (app logic)              Rust (gauge rendering)
-----------------              ----------------------
Model: temperature,            GaugeState: rust_value
       target_temp,
       history

update() handles               handle_command() receives
  slider, button events          set_value, animate_to

view() builds tree with        render() displays
  gauge node + props             percentage + coloured label
```

### Optimistic updates

Button and slider handlers update the Gleam model immediately, then
send a `WidgetCommand` to sync the Rust side. The native widget
does not echo events back, which avoids race conditions when the user
clicks rapidly.

### Native widget definition

The gauge widget is defined in `src/gauge_demo/gauge.gleam` using the
SDK's `NativeDef` type. This declares 7 typed props and 2 commands
that map to the Rust crate's `WidgetExtension` implementation.

The builder uses a typed `GaugeAttr` list for optional properties,
following the same pattern as the SDK's built-in widgets:

```gleam
gauge.gauge("temp", current_value, [
  gauge.min(0.0),
  gauge.max(100.0),
  gauge.color(status_color),
  gauge.label("42C"),
])
```

Only `id` and `value` are required; all other props have defaults.

### Project structure

```
src/
  gauge_demo.gleam            # Entry point (main)
  gauge_demo/
    gauge.gleam               # Native widget def, builder, commands
    app.gleam                 # Model, init, update, view, helpers
test/
  gauge_demo/
    gauge_test.gleam          # Native widget def and builder tests
    app_test.gleam            # App behaviour tests
native/gauge/
  Cargo.toml                  # Rust crate manifest
  src/lib.rs                  # WidgetExtension implementation
bin/
  preflight                   # CI checks (format, build, test)
scripts/
  package.sh                  # Custom-renderer standalone package proof
```

## Cross-language comparison

The same demo exists in other languages:

| Language | Location |
|----------|----------|
| TypeScript | [typescript/gauge-demo](../../typescript/gauge-demo/) |
| Ruby | [ruby/gauge-demo](../../ruby/gauge-demo/) |
| Python | [python/gauge-demo](../../python/gauge-demo/) |

The Rust native widget code is identical across all languages. Only the
host SDK code differs.
