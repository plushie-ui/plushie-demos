# Crash Lab

Error resilience demo for [Plushie](https://github.com/plushie-ui/plushie-ruby).
Deliberately crashes things and shows how the framework recovers.

## What it demonstrates

**Rust extension panic**: The crash widget has a `panic` command that
deliberately calls `panic!()` in the Rust handler. The renderer's
`catch_unwind` catches it, marks the extension as "poisoned", and
shows a red error placeholder. Other widgets keep working. Remove the
widget from the tree and re-add it to recover.

**Ruby update error**: Clicking "Raise in Update" raises a RuntimeError
in the update handler. The runtime catches it, preserves the previous
model, and keeps processing events. The counter still increments.

**Ruby view error**: Clicking "Raise in View" sets a flag that causes
the view method to raise. The runtime preserves the previous rendered
tree -- including the "Recover" button. Click it to clear the flag
and restore normal rendering.

## Prerequisites

- Ruby 3.2+
- Rust toolchain ([rustup](https://rustup.rs/))
- Plushie SDK (path dependency to `../../../plushie-ruby`)

## Setup

    bundle install

## Build the custom renderer

    bundle exec rake plushie:build

## Run

    bundle exec ruby lib/crash_lab.rb

## Test

    bundle exec rake test

## How recovery works

### Extension panic recovery

The renderer wraps all extension calls in `catch_unwind`. When a panic
happens, the extension is "poisoned" -- `render()` returns a red error
placeholder, and `handle_event`/`handle_command` calls are skipped.
Poisoned state is keyed by node ID. Removing the widget from the tree
(toggling `extension_alive`) and re-adding it creates a fresh node
with no poisoned state.

### Ruby error recovery

The runtime rescues `StandardError` in both `update` and `view`:

- **update error**: previous model preserved, event discarded
- **view error**: previous tree preserved, model already updated

This means after a view error, the model has the error flag set but
the old view (with the Recover button) is still showing. Clicking
Recover goes through update (which works), clears the flag, and the
next view call succeeds.

## Project structure

```
lib/
  crash_extension.rb       # Extension declaration (label prop, panic command)
  crash_lab.rb             # App with intentional error triggers
native/
  crash_widget/
    Cargo.toml             # Rust crate depending on plushie-ext
    src/lib.rs             # WidgetExtension with panic in handle_command
test/
  crash_extension_test.rb  # Extension metadata tests
  crash_lab_test.rb        # App tests including error/recovery sequences
```
