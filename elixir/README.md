# Elixir demos

Example Plushie applications written in Elixir using the
[plushie-elixir](https://github.com/plushie-ui/plushie-elixir) SDK.

## Prerequisites

- [Elixir](https://elixir-lang.org/) (1.15+)
- [Erlang/OTP](https://www.erlang.org/) (26+)
- [plushie](https://github.com/plushie-ui/plushie) renderer binary

## Demos

### [examples](https://github.com/plushie-ui/plushie-elixir/tree/main/examples) (in main repo)

Single-file apps covering individual features: Counter, Todo, Notes,
Clock, Shortcuts, AsyncFetch, ColorPicker, Catalog, and RatePlushie.
Good starting points for learning the API -- events, commands, canvas
drawing, theming, custom widgets.

These live in the main plushie-elixir repo and run with `mix plushie.gui`.

### [collab](collab/)

Multi-transport collaborative scratchpad. Demonstrates 5 ways to run
the exact same Plushie app:

- **WebSocket** -- shared state, multiple browser tabs see the same data
- **Native (Elixir spawns renderer)** -- standard desktop mode
- **Native (renderer spawns Elixir)** -- reverse startup via `--exec`
- **SSH server** -- shared state over SSH, interoperable with WebSocket
- **SSH client** -- native renderer connecting to the SSH server

The dark-mode toggle is per-client; everything else is collaborative.

See [collab/README.md](collab/README.md) for setup instructions.

### [gauge-demo](gauge-demo/)

Temperature monitor with a native Rust gauge extension widget.
Demonstrates extension commands (`set_value`, `animate_to`), extension
events (`value_changed`), the optimistic update pattern, and the custom
binary build workflow.

See [gauge-demo/README.md](gauge-demo/README.md) for setup instructions.

### [sparkline-dashboard](sparkline-dashboard/)

Live system monitor with sparkline charts for CPU, memory, and network
metrics. Demonstrates a render-only Rust canvas extension, timer
subscriptions, and multiple extension widget instances.

See [sparkline-dashboard/README.md](sparkline-dashboard/README.md) for
setup instructions.

### [notes](notes/)

Notes app with pure Elixir composite widgets and state helpers -- no
Rust required. Demonstrates Route (navigation), Selection (multi-select),
Undo (editor history), Data (search and sort), and keyboard shortcuts
with a context-aware hint bar.

See [notes/README.md](notes/README.md) for setup instructions.
