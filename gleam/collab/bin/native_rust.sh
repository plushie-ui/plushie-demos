#!/usr/bin/env bash
# Mode 4: Native desktop app started from Rust (plushie spawns Gleam)
cd "$(dirname "$0")/.."
plushie --exec "gleam run -m demo/stdio"
