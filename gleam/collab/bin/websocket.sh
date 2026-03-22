#!/usr/bin/env bash
# Mode 2: WebSocket server with shared state
cd "$(dirname "$0")/.."
echo "Shared-state WebSocket server on http://localhost:8080"
gleam run -m demo/websocket_server
