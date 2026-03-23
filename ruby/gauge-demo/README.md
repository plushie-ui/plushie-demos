# Gauge Demo

Temperature monitor built with [Plushie](https://github.com/plushie-ui/plushie-ruby)
and a custom Rust gauge extension.

Demonstrates:

- Native Rust widget extensions via `include Plushie::Extension`
- Extension commands (`set_value`, `animate_to`)
- Rust-side state management with `ExtensionCaches`
- Optimistic updates (model updates immediately, command syncs Rust state)
- Elm architecture (init/update/view)

## Prerequisites

- Ruby 3.2+
- Rust toolchain ([rustup](https://rustup.rs/))
- Plushie SDK (path dependency to `../../../plushie-ruby`)

## Setup

    bundle install

## Build the custom renderer

The gauge widget is a native Rust extension. Build a custom renderer
binary that includes it:

    bundle exec rake plushie:build

For a release (optimized) build:

    bundle exec rake plushie:build[release]

## Run

    bundle exec ruby lib/temperature_monitor.rb

## Test

    bundle exec rake test

Unit tests run without the binary. They test extension metadata,
model behaviour, command generation, and view tree structure.

## How it works

The app has two halves:

**Ruby side** (`lib/gauge_extension.rb`): declares the gauge widget
type, its props (value, min, max, color, label, width, height), and
two commands (set_value, animate_to).

**Rust side** (`native/gauge/src/lib.rs`): implements `WidgetExtension`
with `prepare()`, `render()`, and `handle_command()`. Uses
`ExtensionCaches` to track per-node state between command receipt and
the next render pass.

**Optimistic updates**: when the user clicks Reset or High, the Ruby
update handler returns both a new model AND an extension command. The
model updates immediately for responsive UI. The command flows through
the wire protocol to the Rust extension, keeping its internal state
in sync. No event is echoed back from Rust to avoid race conditions
with rapid clicks.

## Project structure

```
lib/
  gauge_extension.rb       # Extension declaration (props, commands, Rust crate)
  temperature_monitor.rb   # Elm architecture app (init/update/view)
native/
  gauge/
    Cargo.toml             # Rust crate depending on plushie-core
    src/lib.rs             # WidgetExtension: prepare, render, handle_command
test/
  gauge_extension_test.rb  # Extension metadata and build output tests
  temperature_monitor_test.rb  # App behaviour, commands, and view tests
```
