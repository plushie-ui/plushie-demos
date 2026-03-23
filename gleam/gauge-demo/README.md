# Gauge Demo

Temperature monitor with a native Rust gauge extension widget.
Demonstrates extension commands (`set_value`, `animate_to`),
the optimistic update pattern, and the custom binary build workflow.

## Prerequisites

- [Gleam](https://gleam.run/) (v1.0+)
- [Erlang/OTP](https://www.erlang.org/) (26+)
- [Rust](https://rustup.rs/) (1.92+, for building the custom binary)
- [plushie-renderer](https://github.com/plushie-ui/plushie-renderer) source checkout
- [plushie-iced](https://github.com/plushie-ui/plushie-iced) source checkout (sibling of renderer)

## Setup

Install Gleam dependencies:

```bash
gleam deps download
```

Build the custom plushie binary with the gauge extension compiled in:

```bash
bin/build
```

This creates `build/plushie/bin/gauge-demo-plushie`. The build script
looks for the plushie-renderer source at `~/projects/plushie-renderer`
by default. Override with `PLUSHIE_SOURCE_PATH`:

```bash
PLUSHIE_SOURCE_PATH=/path/to/plushie-renderer bin/build
```

## Run

```bash
PLUSHIE_BINARY_PATH=build/plushie/bin/gauge-demo-plushie gleam run -m gauge_demo
```

## Test

Tests cover the extension definition, widget builder, commands,
app logic (init/update/view), helpers, and edge cases. No custom
binary needed -- all tests exercise pure Gleam code.

```bash
gleam test
```

## How it works

### Architecture

The app follows the standard Plushie Elm loop (`init`/`update`/`view`)
with a native Rust extension widget for the gauge display.

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
send an `ExtensionCommand` to sync the Rust side. The Rust extension
does not echo events back -- this avoids race conditions when the user
clicks rapidly.

### Extension definition

The gauge widget is defined in `src/gauge_demo/gauge.gleam` using the
SDK's `ExtensionDef` type. This declares 7 typed props and 2 commands
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
    gauge.gleam               # Extension def, builder, commands
    app.gleam                 # Model, init, update, view, helpers
test/
  gauge_demo/
    gauge_test.gleam          # Extension def and builder tests
    app_test.gleam            # App behaviour tests
native/gauge/
  Cargo.toml                  # Rust crate manifest
  src/lib.rs                  # WidgetExtension implementation
bin/
  build                       # Custom binary build script
  preflight                   # CI checks (format, build, test)
```

## Cross-language comparison

The same demo exists in other languages:

| Language | Location |
|----------|----------|
| TypeScript | [typescript/gauge-demo](../../typescript/gauge-demo/) |
| Ruby | [ruby/gauge-demo](../../ruby/gauge-demo/) |
| Python | [python/gauge-demo](../../python/gauge-demo/) |

The Rust extension code is identical across all languages. Only the
host SDK code differs.
