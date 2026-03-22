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
