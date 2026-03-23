# Sparkline Dashboard

Live system monitor dashboard built with Plushie and a native Rust
sparkline extension. The sparkline is rendered by Rust/iced canvas;
the app logic lives in Elixir.

Demonstrates:

- Native Rust widget extension (render-only, no commands or events)
- Canvas-based custom rendering on the Rust side (`canvas::Program`)
- Timer subscriptions for live data updates
- Conditional subscriptions based on model state
- Multiple instances of the same extension widget
- Elm architecture (init/update/view/subscribe)

See also the [Ruby](../../ruby/sparkline-dashboard/),
[TypeScript](../../typescript/sparkline-dashboard/), and
[Python](../../python/sparkline-dashboard/) versions of this demo.

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
Cargo workspace with a custom `main.rs` that registers the sparkline
extension, and builds the binary.

The stock (downloaded) binary does not include the sparkline extension.
The custom binary links the sparkline Rust crate and registers it at
startup, making the `"sparkline"` widget type available on the wire.

## Run

```sh
mix plushie.gui SparklineDashboard.Dashboard
```

## Test

```sh
mix test
```

All tests are unit tests that verify the extension definition, app
logic, subscriptions, and view tree structure without a running
renderer. No binary needed.

## Project structure

```
lib/
  sparkline_dashboard.ex              # Top-level module
  sparkline_dashboard/
    sparkline_extension.ex            # Extension definition (props, Rust refs)
    dashboard.ex                      # App module (init/update/view/subscribe)
test/
  test_helper.exs                     # Test setup
  sparkline_dashboard/
    sparkline_extension_test.exs      # Extension metadata, struct, builder
    dashboard_test.exs                # App logic, subscriptions, view tree
native/
  sparkline/
    Cargo.toml                        # Rust crate manifest
    src/
      lib.rs                          # WidgetExtension + canvas::Program
config/
  config.exs                          # Extension registration + build config
```

## How it works

The dashboard has two halves:

**Elixir side** (`sparkline_extension.ex`): defines the sparkline widget
type, its props (data, color, stroke_width, fill, height), and the Rust
crate that renders it. The app (`dashboard.ex`) uses
`Plushie.Subscription.every/2` to generate simulated metrics every
500ms.

**Rust side** (`native/sparkline/src/lib.rs`): implements
`WidgetExtension` to render a canvas-based line chart from the props.
Uses iced's `canvas::Program` trait for custom drawing. When `fill` is
true, it renders a semi-transparent area under the line.

Each tick generates three simulated values:

- **CPU**: random values (30-70 range) with a sine wave overlay
- **Memory**: oscillating between 20-100 using modular arithmetic
- **Network I/O**: random integers (0-100)

Samples are capped at 100 per metric. The view passes the sample
lists as props to the sparkline extension widgets. Pause/resume
toggles the timer subscription; clear resets all samples.

### Extension wire path

This is a render-only extension (Tier A). The full wire path:

1. Timer fires `%Timer{tag: :sample}`
2. `update/2` generates simulated samples and appends them to the model
3. `view/1` passes the sample lists as sparkline `data` props
4. The runtime diffs the tree and sends patches to the binary
5. Rust `SparklineExtension::render()` reads the data array
6. iced `canvas::Program` draws the line chart

There is no reverse path (no events from the extension). This is the
simplest extension pattern: pure props in, rendered pixels out.
