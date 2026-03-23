#!/bin/sh
# Mode 1: Serve client-side WASM app. Each browser tab is independent.
exec npx tsx server/static.ts
