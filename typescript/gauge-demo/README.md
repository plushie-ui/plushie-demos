# Gauge Demo

A native Rust widget extension for plushie, built with the TypeScript
SDK. Demonstrates:

- Defining a custom widget type (`gauge`) in TypeScript
- Implementing `WidgetExtension` in Rust
- Extension commands (`set_value`, `animate_to`)
- Extension config via `settings.extensionConfig`
- Building a custom binary with `npx plushie build`
- Testing extension widgets through the real binary

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
`node_modules/.plushie/build/target/debug/gauge-demo-plushie` with
the gauge extension registered.

## Run

```sh
npx plushie run src/app.tsx
```

## Test

Unit tests (extension definition, commands) run without the binary.
Integration tests require the extension binary built above.

```sh
pnpm test            # run all tests
```

Integration tests are skipped automatically if the binary hasn't
been built.

## Project structure

```
src/
  gauge.ts              # TypeScript extension definition
  app.tsx               # App using the gauge widget
test/
  gauge.test.ts         # Unit tests: config, builder, commands
  app.test.ts           # Integration tests: full app via custom binary
native/
  gauge/
    Cargo.toml          # Rust crate for the extension
    src/
      lib.rs            # WidgetExtension implementation
plushie.extensions.json # Build configuration
vitest.config.ts        # Test runner config (JSX transform)
```

## How it works

The gauge widget is a native Rust extension that renders using iced
widgets. The TypeScript side defines the widget's props, events, and
commands via `defineExtensionWidget`. The Rust side implements
`WidgetExtension` to render the gauge and handle commands.

The `npx plushie build` command reads `plushie.extensions.json`,
generates a Cargo workspace with a custom `main.rs` that registers
the gauge extension, and builds the binary.

At runtime, the TypeScript SDK communicates with this custom binary.
The gauge widget appears in the view tree like any built-in widget.
Extension commands bypass the tree diff/patch cycle and go directly
to the Rust extension's `handle_command` method.

The app uses **optimistic updates** -- button handlers update the
model immediately for responsive UI and send extension commands to
sync the Rust-side state. This is the recommended pattern for
extension commands that originate from the TypeScript side.
