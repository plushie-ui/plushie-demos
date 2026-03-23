# collab

Collaborative scratchpad showing 6 ways to run the same Plushie app --
native desktop, client-side WASM, shared-state WebSocket, and SSH --
all sharing a single app definition in `src/demo/collab.gleam`.

## Setup

Gleam 1.0+, Erlang/OTP 26+.

```bash
cd gleam/collab
gleam deps download
```

For browser modes, also fetch the WASM renderer:

```bash
gleam run -m plushie/download -- --wasm --wasm-dir static
```

## Quick start

```bash
# Native desktop -- a window appears
./bin/native_gleam.sh

# Or start the shared server and open a browser
./bin/ssh_server.sh
open http://localhost:8080/websocket.html
```

## All modes

| # | Script | What it does |
|---|--------|-------------|
| 1 | `./bin/client_side.sh` | Serve client-side WASM app. Each browser tab is independent. |
| 2 | `./bin/websocket.sh` | WebSocket server. All browser tabs share state. |
| 3 | `./bin/native_gleam.sh` | Native desktop. Gleam spawns the renderer. |
| 4 | `./bin/native_rust.sh` | Native desktop. Renderer spawns Gleam via `--listen --exec`. |
| 5 | `./bin/ssh_server.sh` | SSH + WebSocket server. All clients share state. |
| 6 | `./bin/ssh_client.sh` | Connect a native renderer to the SSH server. |

## Collaborative demo

The most interesting demo connects multiple clients to shared state.
Start the server, then connect from as many terminals and browser
tabs as you like:

```bash
# Terminal 1: start the server (SSH on 2222, HTTP+WS on 8080)
./bin/ssh_server.sh

# Terminal 2: browser
open http://localhost:8080/websocket.html

# Terminal 3: native desktop over SSH
./bin/ssh_client.sh

# Terminal 4: another browser tab
open http://localhost:8080/websocket.html
```

All clients share the same counter and notes in real time. The
dark-mode toggle is per-client -- each user picks their own theme.

## The app

The entire app is in `src/demo/collab.gleam` -- a standard Plushie
Elm-architecture app with init/update/view. The collaborative
infrastructure (shared state, WebSocket handler, SSH adapter)
lives in `src/demo/`.

Try editing `collab.gleam` while the server is running: change the
layout, add a widget, tweak the update logic. Restart and reconnect
to see changes across all clients.

## Project structure

```
src/demo/
  collab.gleam              -- the app (model, update, view)
  shared.gleam              -- shared state actor for collaborative modes
  native_gleam.gleam        -- mode 3: Gleam spawns renderer via Port
  connect.gleam             -- mode 4: socket transport for --listen --exec
  stdio.gleam               -- mode 4 legacy: stdio transport for --exec
  static_server.gleam       -- mode 1: mist static file server
  websocket_server.gleam    -- mode 2: mist HTTP + WebSocket server
  ssh_server.gleam          -- mode 5: SSH daemon + WebSocket server
src/
  plushie_demo_ssh_ffi.erl  -- Erlang SSH channel adapter
static/
  index.html                -- landing page with mode links
  standalone.html           -- mode 1: client-side WASM
  websocket.html            -- mode 2: WebSocket WASM
bin/
  native_gleam.sh           -- mode 3 launcher
  native_rust.sh            -- mode 4 launcher
  client_side.sh            -- mode 1 launcher
  websocket.sh              -- mode 2 launcher
  ssh_server.sh             -- mode 5 launcher
  ssh_client.sh             -- mode 6 launcher
  preflight                 -- CI checks (format, build, test)
```

## Browser modes (1 and 2)

The browser modes require WASM files in `static/`. Download them
with the SDK:

```bash
gleam run -m plushie/download -- --wasm --wasm-dir static
```

Or copy from a source build:

```bash
cp ~/projects/plushie-renderer/plushie-renderer-wasm/pkg/plushie_renderer_wasm.js static/
cp ~/projects/plushie-renderer/plushie-renderer-wasm/pkg/plushie_renderer_wasm_bg.wasm static/
```

## Security

This demo is for **local development only**. All services bind to
localhost (127.0.0.1) and are not safe for public networks:

- The SSH daemon has **no authentication** (`no_auth_needed: true`).
  Anyone who can reach the port gets full access.
- The WebSocket server has **no origin checking or authentication**.
  Any page can connect and send events.
- Host keys are **auto-generated in /tmp** and the SSH client skips
  host-key verification (`StrictHostKeyChecking=no`).

Do not expose these ports to the internet.

## Troubleshooting

**"plushie binary not found"** -- Run
`gleam run -m plushie/download` or `gleam run -m plushie/build`.

**Browser shows "plushie-wasm not found"** -- Run
`gleam run -m plushie/download -- --wasm --wasm-dir static`.

**SSH connection refused** -- Start the server first
(`./bin/ssh_server.sh`).

## Dependencies

- [plushie-renderer](https://github.com/plushie-ui/plushie-renderer) -- the Rust renderer (native binary + WASM)
- [plushie-gleam](https://github.com/plushie-ui/plushie-gleam) -- the Gleam SDK
- [mist](https://hexdocs.pm/mist/) -- HTTP/WebSocket server
