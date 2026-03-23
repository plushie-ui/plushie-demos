# Gauge Demo

Temperature monitor built with plushie and a native Rust gauge widget
extension. The gauge is rendered by Rust/iced; the app logic lives in
TypeScript.

Demonstrates:

- Defining a custom widget type (`gauge`) in TypeScript
- Implementing `WidgetExtension` in Rust
- Extension commands (`set_value`, `animate_to`)
- Extension events (`value_changed` from Rust back to TypeScript)
- Extension config via `settings.extensionConfig`
- Building a custom binary with `npx plushie build`
- Testing extension widgets through pure functions and the real binary

## Setup

```sh
pnpm install
```

## Build the extension binary

Requires the [plushie source](https://github.com/plushie-ui/plushie-renderer)
checked out locally:

```sh
export PLUSHIE_SOURCE_PATH=~/projects/plushie-renderer
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

```sh
pnpm test
```

Unit tests cover the extension definition, builder functions, app
update logic (with simulated extension events), view tree structure,
gauge wire props, settings, and a stateful journey test. No renderer
binary needed -- these are pure TypeScript tests.

Integration tests (when the extension binary is built) verify the
wire-level interaction: gauge type on the wire, prop encoding, button
clicks, and slider interactions. They are skipped automatically if
the binary hasn't been built.

## Project structure

```
src/
  gauge.ts              # TypeScript extension definition
  app.tsx               # App using the gauge widget
test/
  gauge.test.ts         # Unit tests: config, builder, commands
  app.test.ts           # App tests: helpers, update, view, settings, journey
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

`npx plushie build` reads `plushie.extensions.json`, generates a
Cargo workspace with a custom `main.rs` that registers the gauge
extension, and builds the binary.

### Extension command wire path

When the user clicks "High (90)", the following happens:

1. TypeScript `setHigh()` handler returns `[{...model, targetTemp: 90}, GaugeCmds.set_value("temp", {value: 90})]`
2. The runtime encodes the `extension_command` as msgpack
3. The custom binary receives the command
4. Rust `GaugeExtension::handle_command` processes `set_value`
5. The gauge re-renders with the new value
6. Rust emits `value_changed` event back over the wire
7. TypeScript `update()` receives the event and updates `model.temperature`

The `temperature` field only changes when the Rust extension confirms
the change via a `value_changed` event. Button handlers set `targetTemp`
immediately for responsive UI; the extension is the source of truth
for the actual displayed value.
