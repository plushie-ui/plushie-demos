#!/bin/sh
# Mode 5: SSH + WebSocket server. All clients share state.
exec npx tsx server/ssh.ts
