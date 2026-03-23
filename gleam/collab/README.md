# collab

Collaborative scratchpad showing 6 different ways to run the same
Plushie app -- from native desktop to shared-state WebSocket and SSH.

All modes share a single app definition (`src/demo/collab.gleam`) with a
name input, shared notes, a counter, a dark-mode toggle, and a
connection status line. Try modifying `collab.gleam` -- change the UI,
add widgets, tweak the update logic -- and see your changes apply
across all connected clients.

## Quick start

```bash
# Mode 3: The standard way. Gleam spawns the renderer.
./bin/native_gleam.sh
```

## All modes

| # | Script | What it does |
|---|--------|-------------|
| 1 | `./bin/client_side.sh` | Serve client-side WASM app. Each browser tab is independent. |
| 2 | `./bin/websocket.sh` | WebSocket server. All browser tabs share state. |
| 3 | `./bin/native_gleam.sh` | Native desktop. Gleam spawns the renderer. |
| 4 | `./bin/native_rust.sh` | Native desktop. Renderer spawns Gleam via `--exec`. |
| 5 | `./bin/ssh_server.sh` | SSH + WebSocket server. All clients share state. |
| 6 | `./bin/ssh_client.sh` | Connect a native renderer to the SSH server. |

### Collaborative demo (modes 2 + 5 + 6)

Start the shared-state server, then connect from multiple clients:

```bash
# Terminal 1: start the server (SSH on 2222, HTTP+WS on 8080)
./bin/ssh_server.sh

# Terminal 2: open a browser tab
open http://localhost:8080/websocket.html

# Terminal 3: connect via SSH
./bin/ssh_client.sh

# Terminal 4: open another browser tab
open http://localhost:8080/websocket.html
```

All four clients see the same counter and notes. Click "+" in the
browser and the SSH client's counter updates. Type in the notes
field from SSH and the browser tabs update.

The dark-mode toggle is per-client -- each user picks their own
theme without affecting others.

## Security

This demo is for **local development only**. All services bind to
localhost (127.0.0.1) and are not safe for public networks:

- The SSH daemon has **no authentication** (`no_auth_needed: true`).
  Anyone who can reach the port gets full access.
- The WebSocket server has **no origin checking or authentication**.
  Any page can connect and send events.
- Host keys are **auto-generated in /tmp** and the SSH client skips
  host-key verification (`StrictHostKeyChecking=no`).

Do not expose these ports to the internet or untrusted networks.

## Modifying the app

The app definition lives in `src/demo/collab.gleam`. It's a standard
Plushie Elm-architecture app: `init`, `update`, `view`. The module
name is arbitrary -- it could be called anything.

Edit `collab.gleam`, restart the server, and reconnect. Changes
apply to all modes. Try:

- Adding a slider widget
- Changing the window title
- Adding a new field to the model
- Changing the layout from column to row

## Project structure

```
src/demo/
  collab.gleam              -- the app (model, update, view)
  shared.gleam              -- shared state actor for collaborative modes
  native_gleam.gleam        -- mode 3: Gleam spawns renderer via Port
  stdio.gleam               -- mode 4: stdio transport for --exec
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
```

## Browser modes (1 and 2)

The browser modes require WASM files in `static/`. Download them
with the SDK or copy from a source build:

```bash
# Option 1: download precompiled WASM
cd ../../../plushie-gleam
gleam run -m plushie/download -- --wasm --wasm-dir ../plushie-demos/gleam/collab/static

# Option 2: copy from a source build
cp ~/projects/plushie-renderer/plushie-renderer-wasm/pkg/plushie_renderer_wasm.js static/
cp ~/projects/plushie-renderer/plushie-renderer-wasm/pkg/plushie_renderer_wasm_bg.wasm static/
```

## Dependencies

- [plushie-renderer](https://github.com/plushie-ui/plushie-renderer) -- the Rust renderer (native binary + WASM)
- [plushie-gleam](https://github.com/plushie-ui/plushie-gleam) -- the Gleam SDK
- [mist](https://hexdocs.pm/mist/) -- HTTP/WebSocket server
