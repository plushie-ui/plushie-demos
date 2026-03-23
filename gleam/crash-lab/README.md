# Crash Lab

Error resilience demonstration showing how plushie catches failures at
every level: Rust extension panics, Gleam update panics, and Gleam view
panics. The counter survives all three.

## Prerequisites

- [Gleam](https://gleam.run/) (v1.0+)
- [Erlang/OTP](https://www.erlang.org/) (26+)
- [Rust](https://rustup.rs/) (1.92+, for building the custom binary)

## Setup

```bash
gleam deps download
bin/build
```

The build script fetches the renderer and extension SDK from crates.io.

## Run

```bash
PLUSHIE_BINARY_PATH=build/plushie/bin/crash-lab-plushie gleam run -m crash_lab
```

## Test

```bash
gleam test
```

## What it demonstrates

A counter (proof of life) and a native Rust extension widget, with
buttons that deliberately trigger failures at three different levels.
The counter survives every one.

### 1. Extension panic (Rust side)

Click **Panic Extension**. The Rust extension's `handle_command`
calls `panic!()`. The renderer catches it via `catch_unwind` and
marks the extension as poisoned. The widget is replaced with a red
error placeholder, but the app continues running.

**Recovery:** Click **Remove Widget** to take the poisoned widget
out of the tree, then **Restore Widget** to re-add it as a fresh
instance.

### 2. Update panic (Gleam side)

Click **Panic Update**. The `update` function hits `panic`. The
runtime catches it via `try_call` (Erlang's exception handling),
logs the error, preserves the model, and discards the event.

**The counter keeps its value.** The next click works normally.

### 3. View panic (Gleam side)

Click **Break View**. The `update` succeeds (sets a flag), but the
next `view` call panics. The runtime catches it and keeps displaying
the previous rendered tree -- which still contains the **Recover**
button. Click it to clear the flag; the next view render succeeds.

**The counter keeps its value.** Even though the view crashed, the
model was never lost.

### The lesson

| Failure | Caught by | Model survives? | View survives? |
|---------|-----------|-----------------|----------------|
| Extension panic | Rust `catch_unwind` | Yes | Widget replaced |
| Update panic | Erlang `try_call` | Yes | Unchanged |
| View panic | Erlang `try_call` | Yes | Previous tree kept |

Plushie never loses your model state. Panics at any level are
isolated and recovered from automatically.

## Project structure

```
src/
  crash_lab.gleam             # Entry point
  crash_lab/
    crashable.gleam           # Extension def, builder, panic command
    app.gleam                 # Model, init, update, view
test/
  crash_lab/
    crashable_test.gleam      # Extension def and builder tests
    app_test.gleam            # Update, view, recovery sequence tests
native/crash_widget/
  Cargo.toml                  # Rust crate manifest
  src/lib.rs                  # Extension that panics on command
bin/
  build                       # Custom binary build script
  preflight                   # CI checks
```

## Cross-language comparison

| Language | Location |
|----------|----------|
| Ruby | [ruby/crash-lab](../../ruby/crash-lab/) |
