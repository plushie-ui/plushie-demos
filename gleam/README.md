# Gleam demos

Example Plushie applications written in Gleam using the
[plushie-gleam](https://github.com/plushie-ui/plushie-gleam) SDK.

## Prerequisites

- [Gleam](https://gleam.run/) (v1.0+)
- [Erlang/OTP](https://www.erlang.org/) (26+)
- [plushie](https://github.com/plushie-ui/plushie) renderer binary
- [plushie-gleam](https://github.com/plushie-ui/plushie-gleam) SDK (path dependency at `../../plushie-gleam`)

## Demos

### [collab](collab/)

A collaborative scratchpad with a name input, shared notes, a counter,
and a dark-mode toggle. Demonstrates 6 different ways to run the exact
same Plushie app:

1. **Client-side WASM** -- runs entirely in the browser, no server
2. **WebSocket** -- shared state, multiple browser tabs see the same data
3. **Native (Gleam spawns renderer)** -- standard desktop mode
4. **Native (renderer spawns Gleam)** -- reverse startup via `--exec`
5. **SSH server** -- shared state over SSH, interoperable with WebSocket
6. **SSH client** -- native renderer connecting to the SSH server

The dark-mode toggle is per-client; everything else is collaborative.
Start the SSH+WebSocket server, open two browser tabs and an SSH
client, and watch changes propagate across all of them.

See [collab/README.md](collab/README.md) for full instructions.

### [gauge-demo](gauge-demo/)

Temperature monitor with a native Rust gauge extension widget.
Demonstrates extension commands (`set_value`, `animate_to`), the
optimistic update pattern, and the custom binary build workflow.

See [gauge-demo/README.md](gauge-demo/README.md) for setup instructions.

### [sparkline-dashboard](sparkline-dashboard/)

Live system monitor with three sparkline charts for CPU, memory, and
network metrics. Demonstrates a render-only Rust canvas extension,
timer subscriptions, and simulated live data.

See [sparkline-dashboard/README.md](sparkline-dashboard/README.md) for
setup instructions.

### [notes](notes/)

Note-taking app with pure Gleam widgets and no Rust extension. Demonstrates
custom message types (`app.application`), multi-view routing, undo/redo,
search filtering, and keyboard shortcuts with a context-aware hint bar.

See [notes/README.md](notes/README.md) for setup instructions.
