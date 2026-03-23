# Collab

Collaborative scratchpad showing multiple ways to run the same
Plushie app -- native desktop, remote via SSH, and shared-state
WebSocket -- all using a single app definition in `lib/collab.rb`.

## Prerequisites

- Ruby 3.2+
- Plushie SDK (path dependency to `../../../plushie-ruby`)
- Plushie binary: `rake plushie:download`
- For browser mode: WASM renderer: `rake plushie:download[wasm]`

## Setup

    bundle install
    rake plushie:download

For browser support (downloads WASM renderer to public/):

    PLUSHIE_WASM_DIR=public rake plushie:download[wasm]

## All modes

| # | Command | What it does |
|---|---------|-------------|
| 1 | `bundle exec ruby lib/collab.rb` | Native desktop. Ruby spawns the renderer. |
| 2 | `plushie --exec "bundle exec ruby bin/connect"` | Native desktop. Renderer spawns Ruby. |
| 3 | `plushie --exec "ssh -T host 'cd collab && bundle exec ruby bin/connect'"` | Native desktop over SSH. |
| 4 | `bundle exec ruby bin/server` | WebSocket server. Browser clients share state. |

## Collaborative demo

The most interesting mode connects multiple browser tabs to shared state:

    # Terminal 1: start the server
    bundle exec ruby bin/server

    # Browser: open one or more tabs
    open http://localhost:8080/websocket.html

All browser tabs share the same counter and notes in real time.
The dark-mode toggle is per-client -- each user picks their own theme.

## The app

The entire app is in `lib/collab.rb` -- a standard `Plushie::App`
with init/update/view. It runs identically in all modes. The shared
state infrastructure lives in `lib/collab/`.

## Test

    bundle exec rake test

## Project structure

```text
lib/
  collab.rb                  # the app (model, update, view)
  collab/
    shared.rb                # thread-safe shared state broker
    server.rb                # HTTP + WebSocket server
bin/
  server                     # starts the collaborative server
  connect                    # stdio transport (for exec/SSH modes)
public/
  index.html                 # landing page
  websocket.html             # browser renderer client (WASM + WebSocket)
test/
  collab_test.rb             # app unit tests
  shared_test.rb             # shared state broker tests
```

## Security

This demo is for **local development only**. The server binds to
127.0.0.1 and has no authentication or origin checking. Do not
expose to the internet.
