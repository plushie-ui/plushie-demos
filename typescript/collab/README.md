# collab

Collaborative scratchpad showing 6 different ways to run the same
Plushie app -- from native desktop to shared-state WebSocket and SSH.

All modes share a single app definition (`src/collab.tsx`) with a
name input, shared notes, a counter, a dark-mode toggle, and a
connection status line.

## Setup

Node.js 20+ and pnpm.

```bash
cd typescript/collab
pnpm install
```

### Browser modes (1 and 2)

The browser modes require the WASM renderer in `static/`. The project
config (`plushie.extensions.json`) declares `artifacts: ["bin", "wasm"]`
and `wasm_dir: "static"`, so a single download fetches everything:

```bash
npx plushie download
```

Or from a local Rust build:

```bash
cp ~/projects/plushie-renderer/plushie-renderer-wasm/pkg/plushie_renderer_wasm.js static/
cp ~/projects/plushie-renderer/plushie-renderer-wasm/pkg/plushie_renderer_wasm_bg.wasm static/
```

## Quick start

```bash
# Mode 3: The standard way. Node.js spawns the renderer.
./bin/native.sh
```

## All modes

| # | Script | What it does |
|---|--------|-------------|
| 1 | `./bin/client-side.sh` | Serve client-side WASM app. Each browser tab is independent. |
| 2 | `./bin/websocket.sh` | WebSocket server. All browser tabs share state. |
| 3 | `./bin/native.sh` | Native desktop. Node.js spawns the renderer. |
| 4 | `./bin/stdio.sh` | Native desktop. Renderer spawns Node.js via `--exec`. |
| 5 | `./bin/ssh-server.sh` | SSH + WebSocket server. All clients share state. |
| 6 | `./bin/ssh-client.sh` | Connect a native renderer to the SSH server. |

### Collaborative demo (modes 5 + 6)

Start the shared-state server, then connect from multiple clients:

```bash
# Terminal 1: start the server (SSH on 2222, HTTP+WS on 8080)
./bin/ssh-server.sh

# Terminal 2: open a browser tab
open http://localhost:8080/websocket.html

# Terminal 3: connect via SSH
./bin/ssh-client.sh

# Terminal 4: open another browser tab
open http://localhost:8080/websocket.html
```

All clients see the same counter and notes. Click "+" in the browser
and the SSH client's counter updates. Type in the notes field from
SSH and the browser tabs update.

The dark-mode toggle is per-client -- each user picks their own
theme without affecting others.

### OpenSSH variant

If you have `sshd` running on a remote machine with the project
installed, you can run the app over an existing SSH connection:

```bash
plushie --exec "ssh -T user@remote 'cd /path/to/collab && npx plushie stdio src/collab.tsx'"
```

This works because the renderer spawns the SSH client, which
tunnels stdin/stdout to the remote `plushie stdio` process.

## Test

```bash
pnpm test
```

Unit tests cover the app logic (init, view) and the shared state
manager (connect, disconnect, events, broadcasting, per-client
dark mode).

## Security

This demo is for **local development only**. All services bind to
localhost (127.0.0.1) and are not safe for public networks:

- The SSH daemon has **no authentication**. Anyone who can reach
  the port gets full access.
- The WebSocket server has **no origin checking or authentication**.
  Any page can connect and send events.
- Host keys are **auto-generated in /tmp** and the SSH client skips
  host-key verification (`StrictHostKeyChecking=no`).

Do not expose these ports to the internet.

## Project structure

```
src/
  collab.tsx              -- the app (model, update, view)
  shared.ts               -- shared state manager for collaborative modes
  browser.ts              -- browser entry point (mode 1, bundled by esbuild)
server/
  static.ts               -- mode 1: static file server
  websocket.ts            -- mode 2: WebSocket server + shared state
  ssh.ts                  -- mode 5: SSH daemon + WebSocket server
  static-files.ts         -- shared static file serving
static/
  index.html              -- landing page with mode links
  standalone.html         -- mode 1: client-side WASM
  websocket.html          -- modes 2/5: WebSocket browser client
test/
  collab.test.ts          -- app logic unit tests
  shared.test.ts          -- shared state unit tests
bin/
  client-side.sh          -- mode 1 launcher
  websocket.sh            -- mode 2 launcher
  native.sh               -- mode 3 launcher
  stdio.sh                -- mode 4 launcher
  ssh-server.sh           -- mode 5 launcher
  ssh-client.sh           -- mode 6 launcher
```
