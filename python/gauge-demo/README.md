# Gauge Demo

Temperature monitor built with plushie and a native Rust gauge widget
extension. The gauge is rendered by Rust/iced; the app logic lives in
Python.

## Setup

```sh
python -m venv .venv
source .venv/bin/activate
pip install -e /path/to/plushie-python"[dev]"
pip install -e .
```

## Download or build the binary

Download a precompiled binary (no extensions):

```sh
python -m plushie download
```

Or build from source with the gauge extension:

```sh
python -m plushie build --release
```

This reads the `[[tool.plushie.extensions]]` config from `pyproject.toml`
and generates a custom binary with the gauge widget registered.

The stock (downloaded) binary does not include the gauge extension --
it only has built-in widgets. The custom binary produced by
`plushie build` links the gauge Rust crate and registers it at startup,
making the `"gauge"` widget type available on the wire.

## Run

```sh
python -m plushie run gauge_demo.app:TemperatureMonitor
```

## Test

```sh
pytest -v
```

Unit tests cover the extension definition, builder functions, app update
logic, and view tree structure. No renderer binary needed -- these are
pure Python tests.

Integration tests (when added) require the extension binary built above.
They are skipped automatically if the binary is not available.

## Project structure

```
src/
  gauge_demo/
    gauge.py            # Python extension definition
    app.py              # App using the gauge widget
tests/
  conftest.py           # Shared fixtures, binary detection
  test_gauge.py         # Unit tests: definition, builder, commands
  test_app.py           # App tests: update logic, view tree, gauge props
native/
  gauge/
    Cargo.toml          # Rust crate for the extension
    src/
      lib.rs            # WidgetExtension implementation
pyproject.toml          # Build configuration + extension declarations
```

## How it works

The gauge widget is a native Rust extension that renders using iced
widgets. The Python side defines the widget's props, events, and
commands via `ExtensionDef`. The Rust side implements
`WidgetExtension` to render the gauge and handle commands.

`python -m plushie build` reads `[[tool.plushie.extensions]]` from
`pyproject.toml`, generates a Cargo workspace with a custom `main.rs`
that registers the gauge extension, and builds the binary.

At runtime, the Python SDK communicates with this custom binary over
msgpack. The gauge widget appears in the view tree like any built-in
widget. Extension commands bypass the tree diff/patch cycle and go
directly to the Rust extension's `handle_command` method.

### Extension command wire path

When the user clicks "High (90)", the following happens:

1. Python `update()` returns `(new_model, set_gauge_value("temp", 90.0))`
2. The runtime encodes the `extension_command` as msgpack
3. The custom binary receives the command
4. Rust `GaugeExtension::handle_command` processes `set_value`
5. The gauge re-renders with the new value
6. Rust emits `value_changed` event back over the wire
7. Python `update()` receives the event and updates `model.temperature`

### Optimistic updates

Button handlers update `target_temp` in the model immediately for
responsive UI and send extension commands to sync the Rust-side state.
The `temperature` field only updates when the Rust extension confirms
the change via a `value_changed` event. This is the recommended
pattern for extension commands that originate from the Python side.
