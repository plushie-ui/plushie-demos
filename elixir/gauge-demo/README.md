# Gauge Demo

Temperature monitor built with Plushie and a native Rust gauge widget
extension. The gauge is rendered by Rust/iced; the app logic lives in
Elixir.

Demonstrates:

- Defining a native extension with `use Plushie.Extension, :native_widget`
- Extension commands (`set_value`, `animate_to`)
- Extension events (`value_changed` from Rust back to Elixir)
- Optimistic updates with confirmed state
- Extension config via `settings/0`
- Building a custom binary with `mix plushie.build`

## Prerequisites

- [Elixir](https://elixir-lang.org/) (1.15+)
- [Erlang/OTP](https://www.erlang.org/) (26+)
- [Rust](https://rustup.rs/) (for building the extension binary)
- [plushie-elixir](https://github.com/plushie-ui/plushie-elixir) SDK
  (path dependency at `../../../plushie-elixir`)

## Setup

```sh
mix deps.get
```

## Build the extension binary

Requires the [plushie renderer source](https://github.com/plushie-ui/plushie-renderer)
checked out locally:

```sh
export PLUSHIE_SOURCE_PATH=~/projects/plushie-renderer
mix plushie.build
```

This reads the extension list from `config/config.exs`, generates a
Cargo workspace with a custom `main.rs` that registers the gauge
extension, and builds the binary.

The stock (downloaded) binary does not include the gauge extension --
it only has built-in widgets. The custom binary produced by
`mix plushie.build` links the gauge Rust crate and registers it at
startup, making the `"gauge"` widget type available on the wire.

## Run

```sh
mix plushie.gui GaugeDemo.TemperatureMonitor
```

## Test

```sh
mix test
```

All tests are unit tests that verify the extension definition, app
logic, and view tree structure without a running renderer. No binary
needed.

## Project structure

```
lib/
  gauge_demo.ex                 # Top-level module
  gauge_demo/
    gauge_extension.ex          # Extension definition (props, commands, Rust refs)
    temperature_monitor.ex      # App module (init/update/view/settings)
test/
  test_helper.exs               # Test setup
  gauge_demo/
    gauge_extension_test.exs    # Extension metadata, struct, commands
    temperature_monitor_test.exs  # App logic, view tree, state journey
native/
  gauge/
    Cargo.toml                  # Rust crate manifest
    src/
      lib.rs                    # WidgetExtension implementation
config/
  config.exs                    # Extension registration + build config
```

## How it works

The gauge widget is a native Rust extension rendered using iced widgets.
The Elixir side defines the widget's props and commands via
`use Plushie.Extension, :native_widget`. The Rust side implements
`WidgetExtension` to render the gauge and handle commands.

`mix plushie.build` reads the extension list from application config,
generates a Cargo workspace with a `main.rs` that registers each
extension via `.extension()` calls, and compiles the binary. At runtime,
the Elixir SDK communicates with this custom binary over MessagePack.
The gauge widget appears in the view tree like any built-in widget.

### Extension command wire path

When the user clicks "High (90 C)":

1. Elixir `update/2` returns `{model, Gauge.set_value("temp", 90.0)}`
2. The runtime encodes the `extension_command` as MessagePack
3. The custom binary receives the command
4. Rust `GaugeExtension::handle_command` processes `set_value`
5. Rust updates internal state and emits `value_changed` event
6. Elixir `update/2` receives `%Widget{type: "value_changed"}` and
   updates `model.temperature`

### Optimistic updates

The app separates two temperature fields:

- **`target_temp`** -- updated immediately in button/slider handlers
  for responsive UI (optimistic)
- **`temperature`** -- updated only when the Rust extension confirms
  via a `value_changed` event (confirmed)

This demonstrates the recommended pattern for extension commands:
update what you can optimistically, and let the extension confirm
the actual state change via events.
