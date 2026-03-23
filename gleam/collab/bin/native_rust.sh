#!/usr/bin/env bash
# Mode 4: Native desktop app started from Rust (plushie spawns Gleam)
# The renderer creates a socket via --listen, then spawns Gleam via --exec.
# Gleam connects back over the socket using plushie/connect.
cd "$(dirname "$0")/.."
plushie --listen --exec "gleam run -m demo/connect"
