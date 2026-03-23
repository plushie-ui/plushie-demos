# Sparkline Dashboard

Live system monitor dashboard built with
[plushie](https://github.com/plushie-ui/plushie-typescript) and a
custom Rust sparkline extension.

Demonstrates:

- Defining a native Rust widget extension in TypeScript
- Canvas-based custom rendering on the Rust side
- Timer subscriptions for live data updates
- Elm architecture (init/update/view/subscribe)
- Simulated system metrics with sparkline charts

## Setup

```sh
pnpm install
```

## Build the extension binary

Requires the [plushie source](https://github.com/plushie-ui/plushie)
checked out locally:

```sh
export PLUSHIE_SOURCE_PATH=~/projects/plushie
npx plushie build
```

This generates a custom binary at
`node_modules/.plushie/build/target/debug/sparkline-dashboard-plushie`
with the sparkline extension registered.

## Run

```sh
npx plushie run src/app.tsx
```

## Test

Unit tests (extension definition) run without the binary. Integration
tests require the extension binary built above.

```sh
pnpm test            # run all tests
```

Integration tests are skipped automatically if the binary hasn't
been built.

## Project structure

```
src/
  sparkline.ts           # TypeScript extension definition
  app.tsx                # Dashboard app with timer subs and sparklines
test/
  sparkline.test.ts      # Unit tests: config shape, widget builder
  app.test.ts            # Integration tests: full app via custom binary
native/
  sparkline/
    Cargo.toml           # Rust crate for the extension
    src/
      lib.rs             # WidgetExtension implementation (canvas rendering)
plushie.extensions.json  # Build configuration
vitest.config.ts         # Test runner config (JSX transform)
```

## How it works

The dashboard has two halves:

**TypeScript side** (`src/sparkline.ts`): defines the sparkline widget
type, its props (data, color, stroke_width, fill, height), and the Rust
crate that renders it. The app (`src/app.tsx`) uses timer subscriptions
to generate simulated metrics every 500ms.

**Rust side** (`native/sparkline/src/lib.rs`): implements
`WidgetExtension` to render a canvas-based line chart from the props.
Uses iced's `canvas::Program` trait for custom drawing. When `fill` is
true, it renders a semi-transparent area under the line.

Each tick generates three simulated values:

- **CPU**: random values (30-70 range) with a sine wave overlay
- **Memory**: oscillating between 20-100 using modular arithmetic
- **Network I/O**: pure random values (0-100)

Samples are capped at 100 per metric. The view passes the sample
arrays as props to the sparkline extension widgets. The Rust renderer
reads the data array and draws the chart. Pause/resume toggles the
timer subscription; clear resets all samples.
