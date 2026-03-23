# Crash Lab

Error resilience demonstration showing how plushie isolates failures
at different levels: Rust extension panic isolation vs Gleam runtime
crash recovery.

## Prerequisites

- [Gleam](https://gleam.run/) (v1.0+)
- [Erlang/OTP](https://www.erlang.org/) (26+)
- [Rust](https://rustup.rs/) (1.92+, for building the custom binary)
- [plushie-renderer](https://github.com/plushie-ui/plushie-renderer) source checkout
- [plushie-iced](https://github.com/plushie-ui/plushie-iced) source checkout (sibling of renderer)

## Setup

```bash
gleam deps download
bin/build
```

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
buttons that deliberately trigger failures at two different levels.

### Extension panic (Rust side)

Click **Panic Extension**. The Rust extension's `handle_command`
calls `panic!()`. The renderer catches it via `catch_unwind` and
marks the extension as poisoned. The widget is replaced with a red
error placeholder.

**The counter still works.** The Gleam model is unaffected -- the
panic was isolated inside the Rust process.

**Recovery:** Click **Remove Widget** to take the poisoned widget out
of the tree. Click **Restore Widget** to re-add it as a fresh
instance with no poisoned state. The widget renders normally again.

### Gleam panic (host side)

Click **Panic Gleam Update**. The `update` function hits
`panic as "intentional Gleam crash"`. The runtime process crashes.
The OTP supervisor restarts it, calling `init()` again.

**The counter resets to 0.** The model lived in the runtime process
and died with it. This is the cost of a host-side crash.

### The lesson

| Failure level | Isolation | Model survives? |
|--------------|-----------|-----------------|
| Rust extension panic | `catch_unwind`, widget replaced | Yes |
| Gleam runtime panic | Supervisor restart | No (reset to init) |

Your model is safe from Rust extension failures. It is NOT safe
from Gleam panics -- keep your update function total.

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
