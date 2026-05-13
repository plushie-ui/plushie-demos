# AGENTS.md

## Python Demos

Each child directory is an independent Python project using
`pyproject.toml`. Keep lock and packaging files local to the demo that
owns them.

## Setup

Use Python 3.12 or newer. Native widget demos also require Rust and may
need `PLUSHIE_RUST_SOURCE_PATH` for custom renderer builds.

## Commands

Run `just preflight` in `python/` to verify every Python demo.

The language preflight installs each demo in editable dev mode, runs
the demo's existing `preflight` script, and builds a custom renderer
for demos with `native/`.

For one demo:

```sh
python -m pip install -e ".[dev]"
./preflight
python -m plushie build --release
```

Only run the build command for native widget demos.
