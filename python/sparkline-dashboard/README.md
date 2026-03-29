# Sparkline Dashboard

Live system monitor dashboard built with plushie and a native Rust
sparkline widget. The sparkline is rendered by Rust/iced; the app
logic lives in Python.

Demonstrates:

- Native Rust widget (render-only, no commands or events)
- Canvas-based custom rendering on the Rust side (`canvas::Program`)
- Timer subscriptions for live data updates
- Elm architecture (init/update/view/subscribe)

See also the [Ruby](../../ruby/sparkline-dashboard/) and
[TypeScript](../../typescript/sparkline-dashboard/) versions of this demo.

## Setup

```sh
python -m venv .venv
source .venv/bin/activate
pip install -e /path/to/plushie-python"[dev]"
pip install -e .
```

## Build the binary

The sparkline widget is a native Rust widget. Build a custom
renderer binary that includes it:

```sh
python -m plushie build --release
```

This reads `[[tool.plushie.extensions]]` from `pyproject.toml` and
generates a custom binary with the sparkline widget registered.

> **Note:** `python -m plushie download` will refuse to download a
> precompiled binary when native widgets are configured -- the stock
> binary doesn't include custom widget crates.

## Run

```sh
python -m plushie run sparkline_dashboard.app:Dashboard
```

## Test

```sh
pytest -v
```

Unit tests cover the native widget definition, builder function, app
update logic, and view tree structure. No renderer binary needed --
these are pure Python tests.

## Project structure

```
src/
  sparkline_dashboard/
    sparkline.py        # Native widget definition (NativeWidgetDef)
    app.py              # Dashboard app with timer subs and sparklines
tests/
  conftest.py           # Shared fixtures, binary detection
  test_sparkline.py     # Unit tests: definition, builder
  test_app.py           # App tests: update logic, view tree, wire props
native/
  sparkline/
    Cargo.toml          # Rust crate for the widget
    src/
      lib.rs            # WidgetExtension implementation (canvas rendering)
pyproject.toml          # Build configuration + widget declarations
```

## How it works

The dashboard has two halves:

**Python side** (`src/sparkline_dashboard/sparkline.py`): defines the
sparkline widget type, its props (data, color, stroke_width, fill,
height), and the Rust crate that renders it. The app
(`src/sparkline_dashboard/app.py`) uses timer subscriptions to generate
simulated metrics every 500ms.

**Rust side** (`native/sparkline/src/lib.rs`): implements
`WidgetExtension` to render a canvas-based line chart from the props.
Uses iced's `canvas::Program` trait for custom drawing. When `fill` is
true, it renders a semi-transparent area under the line.

Each tick generates three simulated values:

- **CPU**: random values (30-70 range) with a sine wave overlay
- **Memory**: oscillating between 20-100 using modular arithmetic
- **Network I/O**: pure random values (0-100)

Samples are capped at 100 per metric. The view passes the sample
arrays as props to the sparkline widgets. The Rust renderer reads the
data array and draws the chart. Pause/resume toggles the timer
subscription; clear resets all samples.

### Wire path

This is a render-only native widget. The full wire path:

1. Python timer tick fires `TimerTick(tag="sample")`
2. `update()` generates simulated samples and adds them to the model
3. `view()` passes the sample tuples as sparkline `data` props
4. The runtime diffs the tree and sends patches to the binary
5. Rust `SparklineExtension::render()` reads the data array
6. iced `canvas::Program` draws the line chart

There is no reverse path (no events from the widget). This is the
simplest native widget pattern: pure props in, rendered pixels out.
