# collab

Collaborative scratchpad showing 5 ways to run the same Plushie app --
native desktop, shared-state WebSocket, and SSH -- all sharing a single
app definition in `lib/collab.ex`.

## Setup

Elixir 1.15+ and Erlang/OTP 26+.

```bash
cd elixir/collab
mix deps.get
mix plushie.download
```

This fetches both the native renderer binary and the WASM browser
renderer (configured in `config/config.exs`). WASM files are placed
in `priv/static/` where the HTTP server serves them.

## Quick start

```bash
# Native desktop -- a window appears
mix plushie.gui Collab

# Or start the shared server and open a browser
mix collab.server
open http://localhost:8080/websocket.html
```

## All modes

| # | Command | What it does |
|---|---------|-------------|
| 2 | `mix collab.server` | SSH + WebSocket server. All clients share state. |
| 3 | `mix plushie.gui Collab` | Native desktop. Elixir spawns the renderer. |
| 4 | `bin/plushie --listen --exec "mix plushie.connect Collab"` | Native desktop. Renderer spawns Elixir. |
| 5 | `bin/plushie --exec "ssh -T -s -p 2222 -o StrictHostKeyChecking=no localhost plushie"` | Native renderer over SSH (needs mode 2 running). |

Mode 1 (client-side WASM) exists only in the gleam version -- Elixir
doesn't compile to JavaScript. Mode 2 serves the same browser renderer
but with Elixir on the server.

## Collaborative demo

The most interesting demo connects multiple clients to shared state.
Start the server, then connect from as many terminals and browser
tabs as you like:

```bash
# Terminal 1: start the server (SSH on 2222, HTTP+WS on 8080)
mix collab.server

# Terminal 2: browser
open http://localhost:8080/websocket.html

# Terminal 3: native desktop over SSH
bin/plushie --exec "ssh -T -s -p 2222 -o StrictHostKeyChecking=no localhost plushie"

# Terminal 4: another browser tab
open http://localhost:8080/websocket.html
```

All clients share the same counter and notes in real time. The
dark-mode toggle is per-client -- each user picks their own theme.

## The app

The entire app is in `lib/collab.ex` -- a standard `Plushie.App`
with init/update/view. The collaborative infrastructure (shared
state, WebSocket handler, SSH adapter) lives in `lib/collab/`.

Try editing `collab.ex` while the server is running: change the
layout, add a widget, tweak the update logic. Restart and reconnect
to see changes across all clients.

## Project structure

```
lib/
  collab.ex                    -- the app (model, update, view)
  collab/
    shared.ex                  -- GenServer shared state
    websocket_server.ex        -- Bandit HTTP + WebSocket handler
    ssh_server.ex              -- SSH daemon startup
    ssh_channel.ex             -- SSH channel adapter (pure Elixir)
    static.ex                  -- static file serving
  mix/tasks/
    collab.server.ex           -- mix collab.server task
priv/static/
  index.html                   -- landing page
  websocket.html               -- browser renderer client
bin/
  plushie                      -- symlink to downloaded binary
```

## Security

This demo is for **local development only**. All services bind to
localhost (127.0.0.1) and are not safe for public networks:

- The SSH daemon has **no authentication** (`no_auth_needed: true`).
  Anyone who can reach the port gets full access.
- The WebSocket server has **no origin checking or authentication**.
  Any page can connect and send events.
- Host keys are **auto-generated in /tmp** and the SSH client skips
  host key verification (`StrictHostKeyChecking=no`).

Do not expose these ports to the internet.

## Troubleshooting

**"plushie binary not found"** -- Run `mix plushie.download` first.

**Browser shows "plushie-wasm not found"** -- Run
`mix plushie.download` (config downloads WASM to `priv/static/`).

**SSH connection refused** -- Start the server first (`mix collab.server`).
