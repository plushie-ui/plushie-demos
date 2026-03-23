# crash-test

Demonstrates plushie's crash resilience at both the Python and Rust layers.

## What it does

The app provides buttons that deliberately crash in various ways:

**Python-side crashes:**
- **Crash update** -- `update()` raises `RuntimeError`. The runtime
  catches it and preserves the previous model.
- **Crash view** -- Arms a flag so the next `view()` call raises. The
  runtime catches it and falls back to the last valid tree.
- **Return None** -- Exercises the edge case where `update()` returns
  an unexpected value.

**Rust-side crashes** (require the extension binary):
- **Panic render** -- Sets `panic_on_render=True` on the crasher
  widget. The renderer catches the panic and shows fallback content.
- **Panic command** -- Sends a command that panics inside
  `handle_command`. The renderer catches it and continues.

A working counter stays functional through all crashes, proving
the app recovers.

## Setup

```sh
python -m venv .venv
source .venv/bin/activate
pip install -e /path/to/plushie-python[dev]
pip install -e .
```

## Run

```sh
# With the standard binary (Rust crashes won't fire):
plushie run crash_test.app:CrashTestApp

# With the extension binary (after building):
plushie run crash_test.app:CrashTestApp --binary _plushie_build/crasher
```

## Build the extension binary

```sh
plushie build
```

## Test

```sh
pytest -v
```

Tests are pure Python and don't require the binary. They verify that
update crashes are caught, view crashes are caught, and the counter
keeps working through failures.

## Preflight (all checks)

```sh
./preflight
```

## Project structure

```
src/crash_test/
  __init__.py          # package marker
  crasher.py           # extension def, builder, command
  app.py               # CrashTestApp (Elm architecture)
native/crasher/
  Cargo.toml           # Rust crate deps
  src/lib.rs           # CrasherExtension (panics on demand)
tests/
  conftest.py          # shared fixtures
  test_crasher.py      # extension def and builder tests
  test_app.py          # app update/view crash recovery tests
```
