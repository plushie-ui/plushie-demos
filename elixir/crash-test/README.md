# Crash Test

Crash resilience demo exercising three failure paths: Elixir-side
exceptions (`RuntimeError` in `update/2` and `view/1`) and a Rust-side
panic (in `handle_command`). A working counter proves the app keeps
functioning through all crashes.

Demonstrates:

- Runtime error handling in `update/2` (model rollback)
- Runtime error handling in `view/1` (previous tree preserved)
- `catch_unwind` panic isolation in the renderer
- The red placeholder widget shown after an extension panic
- Three isolation boundaries working independently

See also the [Ruby](../../ruby/crash-lab/),
[TypeScript](../../typescript/crash-test/), and
[Python](../../python/crash-test/) versions of this demo.

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

```sh
export PLUSHIE_SOURCE_PATH=~/projects/plushie-renderer
mix plushie.build
```

## Run

```sh
mix plushie.gui CrashTest.App
```

## Test

```sh
export PLUSHIE_SOURCE_PATH=~/projects/plushie-renderer
mix plushie.build
mix test
```

The test suite uses the real custom renderer binary for the native
crash widget. Build it first, then run `mix test`.

## Project structure

```
lib/
  crash_test.ex                 # Top-level module docs
  crash_test/
    app.ex                      # Plushie.App with crash buttons + counter
    crash_extension.ex          # Native extension that can be panicked
test/
  crash_test/
    app_test.exs                # App logic + crash behavior tests
    crash_extension_test.exs    # Extension metadata + command tests
native/
  crash_widget/
    Cargo.toml                  # Rust crate manifest
    src/lib.rs                  # Green box widget + deliberate panic
```

## How it works

### Three isolation boundaries

**1. Elixir `update/2` crash**

Clicking "Crash update/2" raises a `RuntimeError` inside the event
handler. The Plushie runtime catches it and rolls back the model to
its pre-exception state -- as if the click never happened. The counter
keeps working.

**2. Elixir `view/1` crash**

Clicking "Crash view/1" sets a flag in the model that causes the next
`view/1` call to raise. The runtime catches it, shows the previous
tree, and rolls back the model (clearing the flag). This makes it a
one-shot crash -- the app recovers on the next event.

**3. Rust extension panic**

Clicking "Panic extension" sends a command to the Rust extension's
`handle_command`, which calls `panic!()`. The renderer isolates it
via `catch_unwind` and replaces the widget with a red placeholder.
The extension stays broken for the rest of the session, but the rest
of the app continues normally.

### The working counter

The increment/decrement buttons work through all three crash types.
This is the proof that the app is alive and the isolation boundaries
are working.
