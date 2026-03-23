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

## Run

```sh
python -m plushie run gauge_demo.app:TemperatureMonitor
```

## Test

```sh
pytest -v
```

Tests cover the extension definition, builder functions, app update
logic, and view tree structure. No renderer binary needed -- these are
pure unit tests.
