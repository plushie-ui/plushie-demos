# Plushie Pad (Rust)

A small experiment gallery for the Plushie Rust SDK. Launching the
pad opens one window split into four panes:

- **Sidebar** - list of experiments, one button each.
- **Source** - the Rust source of the selected experiment, read-only.
- **Preview** - the selected experiment's live view.
- **Event log** - a rolling window of the most recent events that
  reached the pad's `update`.

Clicking a sidebar entry switches experiments. Interacting with the
preview fires real events, which the pad routes to the current
experiment and echoes into the event log.

## Build and run

```
cargo build
cargo run
```

The pad uses a path dependency on the sibling plushie-rust checkout:

```toml
plushie = "0.7.1"
```

For local SDK development, temporarily point that dependency at a
sibling `plushie-rust` checkout.

## Standalone postcheck

Rust direct mode links the renderer into the app process, so a release
build is already the standalone runtime artifact for this demo. The
language-level package postcheck builds the release binary, starts headless
Weston when no display is available, and runs the app from a temporary
working directory:

```sh
cd ..
just package-postcheck
```

The current pad embeds its source snippets with `include_str!` and does
not need adjacent runtime assets.

## Why a gallery and not a live editor?

The Elixir, Gleam, Ruby, and TypeScript pads all compile user-typed
code at runtime: you edit an experiment in the pad, hit Save, and the
new version takes effect without restarting. Rust has no standard
`eval`, and the two genuine options for runtime compilation both drag
in heavy machinery:

1. Shell out to `cargo build -p experiment` and `dlopen` the resulting
   shared library with `libloading`. Full fidelity, but every save
   triggers a real Rust build and needs a working toolchain on the
   end user's machine.
2. Interpret a declarative experiment format (YAML, JSON, custom).
   Loses the "real code" pedagogy; teaches a one-off format that
   exists only inside the pad.

This pad takes a third path: a **pre-compiled experiment gallery**.
Every experiment lives in its own file under `src/experiments/` and
ships its own source via `include_str!`. Switching between them at
runtime is just swapping which `Experiment` the pad's view delegates
to. Editing an experiment means editing the file and rebuilding the
pad. The teaching story still works because the interesting parts
(widget builders, event routing, model updates) live inside the
experiments and not in the compile-save loop.

Future versions may layer option 1 on top as an opt-in.

## Adding a new experiment

1. Create `src/experiments/<name>.rs` with a `pub struct` plus an
   `impl Experiment` block. `source()` should return
   `include_str!("<name>.rs")` so the source pane renders the real
   file.
2. Add `pub mod <name>;` to `src/experiments/mod.rs`.
3. Add one `Box::new(<name>::YourType::default())` entry to
   `build_gallery()`.

A minimal template:

```rust
use plushie::prelude::*;
use super::Experiment;

#[derive(Default)]
pub struct MyExperiment;

impl Experiment for MyExperiment {
    fn name(&self) -> &'static str { "my_experiment" }
    fn source(&self) -> &'static str { include_str!("my_experiment.rs") }

    fn view(&self) -> View {
        text("Hello from my experiment").into()
    }
}
```

Experiments that need to react to events implement `update(&mut self,
event: &Event) -> bool`. Return `true` if the event changed state.
The pad forwards every event scoped under the `preview` container to
the current experiment, so IDs declared inside `view` are addressed
as `preview/your_id` on the wire; inside `update`, `event.widget_match()`
gives you the local ID back with no scope prefix.

## Files

```
Cargo.toml
README.md
src/
  main.rs                # fn main() -> plushie::Result
  app.rs                 # PadApp, Model, Elm loop
  experiments/
    mod.rs               # Experiment trait, build_gallery()
    hello.rs             # text + button
    counter.rs           # stateful counter
    list.rs              # dynamic list with scoped deletes
    canvas.rs            # basic canvas shapes
    form.rs              # text_input, checkbox, slider
  ui/
    mod.rs
    sidebar.rs
    source_view.rs
    preview.rs
    event_log.rs
```
