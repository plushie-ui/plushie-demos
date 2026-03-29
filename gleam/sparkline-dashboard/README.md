# Sparkline Dashboard

Live system monitor with three sparkline charts for CPU, memory, and
network metrics. Demonstrates a render-only Rust canvas native widget,
timer subscriptions, and simulated live data.

## Prerequisites

- [Gleam](https://gleam.run/) (v1.0+)
- [Erlang/OTP](https://www.erlang.org/) (26+)
- [Rust](https://rustup.rs/) (1.92+, for building the custom binary)

## Setup

```bash
gleam deps download
bin/build
```

This builds a custom plushie binary with the sparkline native widget
compiled in and installs it to
`build/plushie/bin/sparkline-dashboard-plushie`. The widget crate
and renderer are fetched from crates.io automatically.

```bash
PLUSHIE_SOURCE_PATH=/path/to/plushie-renderer bin/build
```

## Run

```bash
PLUSHIE_BINARY_PATH=build/plushie/bin/sparkline-dashboard-plushie gleam run -m sparkline_dashboard
```

## Test

Tests cover the native widget definition, widget builder, app logic
(init/update/subscribe/view), metric generation, and edge cases. No
custom binary needed -- all tests exercise pure Gleam code.

```bash
gleam test
```

## How it works

### Architecture

The sparkline is a **render-only** native widget: it has no commands or
events. Data flows in one direction -- from Gleam model to Rust canvas.

```
Gleam (app logic)                Rust (sparkline rendering)
-----------------                --------------------------
Model: cpu/mem/net samples       canvas::Program::draw()
       running, tick_count         normalise data to bounds
                                   stroke line path
subscribe() -> timer 500ms         optionally fill under curve
update() generates samples
view() passes data as props
```

### Timer subscriptions

The `subscribe` callback is conditional: it returns a 500ms timer
subscription when running, and an empty list when paused. This
cleanly disarms the timer at the subscription level rather than
filtering events in update.

### Simulated metrics

Three generators produce values in realistic ranges:

- **CPU**: random base (30-70) with sine wave overlay (amplitude 15)
- **Memory**: oscillating pattern via modular arithmetic (range 20-100)
- **Network**: pure random (0-100)

Samples are capped at 100 per metric to bound memory usage.

### Sparkline widget

The builder follows the same typed `SparklineAttr` list pattern as the
gauge-demo:

```gleam
sparkline.sparkline("cpu_spark", cpu_samples, [
  sparkline.color(green),
  sparkline.fill(True),
  sparkline.stroke_width(2.0),
  sparkline.height(60.0),
])
```

Only `id` and `data` are required; all other props have defaults.

### Project structure

```
src/
  sparkline_dashboard.gleam       # Entry point (main)
  sparkline_dashboard/
    sparkline.gleam               # Native widget def, builder
    app.gleam                     # Model, Elm loop, metrics
test/
  sparkline_dashboard/
    sparkline_test.gleam          # Native widget def and builder tests
    app_test.gleam                # App behaviour tests
native/sparkline/
  Cargo.toml                     # Rust crate manifest
  src/lib.rs                     # Canvas-based WidgetExtension
bin/
  build                          # Custom binary build script
  preflight                      # CI checks (format, build, test)
```

## Cross-language comparison

The same demo exists in other languages:

| Language | Location |
|----------|----------|
| TypeScript | [typescript/sparkline-dashboard](../../typescript/sparkline-dashboard/) |
| Ruby | [ruby/sparkline-dashboard](../../ruby/sparkline-dashboard/) |
| Python | [python/sparkline-dashboard](../../python/sparkline-dashboard/) |

The Rust native widget code is identical across all languages. Only the
host SDK code differs.
