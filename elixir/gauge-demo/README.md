# Gauge Demo

Temperature monitor built with Plushie and a native Rust gauge widget.
The gauge is rendered by Rust/iced; the app logic lives in Elixir.

Demonstrates:

- Defining a native widget with `use Plushie.Widget, :native_widget`
- Widget commands (`set_value`, `animate_to`)
- Widget events (`{:gauge, :value_changed}` from Rust back to Elixir)
- Optimistic updates with confirmed state
- Widget config via `settings/0`
- Building a custom binary with `mix plushie.build`

## Prerequisites

- [Elixir](https://elixir-lang.org/) (1.15+)
- [Erlang/OTP](https://www.erlang.org/) (26+)
- [Rust](https://rustup.rs/) (for building the native widget binary)
- [plushie-elixir](https://github.com/plushie-ui/plushie-elixir) SDK
  (path dependency at `../../../plushie-elixir`)

## Setup

```sh
mix deps.get
```

## Build the binary

Requires the [plushie renderer source](https://github.com/plushie-ui/plushie-renderer)
checked out locally:

```sh
export PLUSHIE_SOURCE_PATH=~/projects/plushie-renderer
mix plushie.build
```

Native widgets are auto-detected via protocol consolidation. The build
generates a Cargo workspace with a custom `main.rs` that registers the
gauge widget and compiles the binary.

The stock (downloaded) binary does not include the gauge widget - it
only has built-in widgets. The custom binary produced by
`mix plushie.build` links the gauge Rust crate and registers it at
startup, making the `"gauge"` widget type available on the wire.

## Run

```sh
mix plushie.gui GaugeDemo.TemperatureMonitor
```

## Test

```sh
export PLUSHIE_SOURCE_PATH=~/projects/plushie-renderer
mix plushie.build
mix test
```

The test suite uses the real custom renderer binary for the native
gauge widget. Build it first, then run `mix test`.

## Project structure

```
lib/
  gauge_demo.ex                 # Top-level module
  gauge_demo/
    gauge_extension.ex          # Widget definition (props, commands, Rust refs)
    temperature_monitor.ex      # App module (init/update/view/settings)
test/
  test_helper.exs               # Test setup
  gauge_demo/
    gauge_extension_test.exs    # Widget metadata, struct, commands
    temperature_monitor_test.exs  # App logic, view tree, state journey
native/
  gauge/
    Cargo.toml                  # Rust crate manifest
    src/
      lib.rs                    # WidgetExtension implementation
config/
  config.exs                    # Build config
```

## How it works

The gauge widget is a native Rust widget rendered using iced. The
Elixir side defines the widget's props and commands via
`use Plushie.Widget, :native_widget`. The Rust side implements
`WidgetExtension` to render the gauge and handle commands.

`mix plushie.build` auto-detects native widgets via protocol
consolidation, generates a Cargo workspace with a `main.rs` that
registers each native widget, and compiles the binary. At runtime,
the Elixir SDK communicates with this custom binary over MessagePack.
The gauge widget appears in the view tree like any built-in widget.

### Widget command wire path

When the user clicks "High (90 C)":

1. Elixir `update/2` returns `{model, Gauge.set_value("temp", 90.0)}`
2. The runtime encodes the `extension_command` as MessagePack
3. The custom binary receives the command
4. Rust `GaugeExtension::handle_command` processes `set_value`
5. Rust updates internal state and emits `value_changed` from window `main`
6. Elixir `update/2` receives `%WidgetEvent{type: {:gauge, :value_changed}}` and
   updates `model.temperature`

### Optimistic updates

The app separates two temperature fields:

- **`target_temp`** - updated immediately in button/slider handlers
  for responsive UI (optimistic)
- **`temperature`** - updated only when the Rust widget confirms
  via a `{:gauge, :value_changed}` event (confirmed)

This demonstrates the recommended pattern for widget commands:
update what you can optimistically, and let the widget confirm
the actual state change via events.
