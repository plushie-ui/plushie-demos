#!/bin/sh
# Mode 2: WebSocket server. All browser tabs share state.
exec npx tsx server/websocket.ts
