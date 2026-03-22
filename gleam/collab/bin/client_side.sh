#!/usr/bin/env bash
# Mode 1: Serve client-side WASM app
# Each browser tab runs independently (no shared state).
cd "$(dirname "$0")/.."
echo "Serving static files on http://0.0.0.0:8080"
echo "Open http://localhost:8080/standalone.html"
gleam run -m demo/static_server
