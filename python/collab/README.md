# collab

Collaborative scratchpad showing multiple ways to run the same Plushie
app -- native desktop, shared-state WebSocket, and SSH -- all sharing
a single app definition in `src/collab_demo/collab.py`.

## Setup

Python 3.12+ with pip.

```bash
cd python/collab
python -m venv .venv
source .venv/bin/activate
pip install -e ~/projects/plushie-python"[dev]"
pip install -e ".[dev]"
```

Download the plushie binary and WASM renderer:

```bash
python -m plushie download --bin
python -m plushie download --wasm --wasm-dir static
```

## Quick start

```bash
# Native desktop -- a window appears
python -m plushie run collab_demo.collab:Collab

# Or start the shared server and open a browser
python -m collab_demo.server
open http://localhost:8080/websocket.html
```

## All modes

| # | Command | What it does |
|---|---------|-------------|
| 1 | `python -m plushie run collab_demo.collab:Collab` | Native desktop. Python spawns the renderer. |
| 2 | `python -m collab_demo.server` | SSH + WebSocket server. All clients share state. |
| 3 | `plushie --listen --exec "python -m plushie connect collab_demo.collab:Collab"` | Native desktop. Renderer spawns Python. |
| 4 | `plushie --exec "ssh -T -s -p 2222 -o StrictHostKeyChecking=no localhost plushie"` | Native renderer over SSH (needs mode 2 running). |
| 5 | `open http://localhost:8080/websocket.html` | Browser client (needs mode 2 running). |

## Collaborative demo

The most interesting demo connects multiple clients to shared state.
Start the server, then connect from as many terminals and browser
tabs as you like:

```bash
# Terminal 1: start the server (SSH on 2222, HTTP+WS on 8080)
python -m collab_demo.server

# Terminal 2: browser
open http://localhost:8080/websocket.html

# Terminal 3: native desktop over SSH
plushie --exec "ssh -T -s -p 2222 -o StrictHostKeyChecking=no localhost plushie"

# Terminal 4: another browser tab
open http://localhost:8080/websocket.html
```

All clients share the same counter and notes in real time. The
dark-mode toggle is per-client -- each user picks their own theme.

## The app

The entire app is in `src/collab_demo/collab.py` -- a standard
`plushie.App` subclass with init/update/view. The collaborative
infrastructure (shared state, WebSocket handler, SSH adapter) lives
alongside it in `src/collab_demo/`.

## Project structure

```
src/collab_demo/
  __init__.py
  collab.py              -- the app (model, update, view)
  shared.py              -- thread-safe shared state server
  ws_handler.py          -- WebSocket connection handler
  ssh_handler.py         -- SSH subsystem handler (asyncssh)
  server.py              -- combined server entry point
static/
  index.html             -- landing page
  websocket.html         -- browser renderer client (WASM)
tests/
  test_collab.py         -- app unit tests
  test_shared.py         -- shared state tests
  test_integration.py    -- integration tests
```

## Security

This demo is for **local development only**. All services bind to
localhost (127.0.0.1) and are not safe for public networks:

- The SSH daemon has **no authentication**. Anyone who can reach the
  port gets full access.
- The WebSocket server has **no origin checking or authentication**.
  Any page can connect and send events.
- Host keys are **auto-generated in /tmp** and the SSH client skips
  host key verification (`StrictHostKeyChecking=no`).

Do not expose these ports to the internet.

## Troubleshooting

**"plushie binary not found"** -- Run `python -m plushie download` first.

**Browser shows "plushie-wasm not found"** -- Run
`python -m plushie download --wasm --wasm-dir static`.

**SSH connection refused** -- Start the server first
(`python -m collab_demo.server`).

**Import errors** -- Make sure both `plushie` and `collab-demo` are
installed in the active virtualenv (`pip install -e`).
